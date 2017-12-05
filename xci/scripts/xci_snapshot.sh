#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 Ericsson AB and Others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

declare -r xci_vms=`sudo virsh list --name | grep 'opnfv\|controller*\|compute*\|master*\|node*\|kube-node\|kube-master'`

# This script provides an utility for the XCI deployment which allows an user
# to take snapshot of existing VM instances and revert/delete/export/import
# options around the VM snapshots. Please have a look print_help() method for the
# different CLI options provided by this script.

##############################################################################
# Helper method which prints how to execute this script with different options
##############################################################################
function print_help(){
   echo "$0 <task>"
   echo "
   export <path>
   import <tarball-path>
   delete-all
   abort <snapshot-name-to-revert-to> The running process which takes snapshots at the moment and revert to snapshot
   list
   destroy-all
   take <snapshot name>
   revert <snapshot name>
   delete <snapshot name>
   import <tarball>
   suspend
   resume
   "
}

##############################################################################
# revert the VM to specific snapshot and makes it in suspended state
# Arguments:
#   name of the VM
#   snapshot name to which VM to get reverted
##############################################################################
function revert_snapshot(){
  sudo virsh snapshot-revert --domain $1 $2
  sudo virsh suspend $node
}

##############################################################################
# revert the XCI VMs to specific snapshot and the whole process is parallelized
# at each VM level. It returns once all VMs are reverted and running state.
# Arguments:
#   None
##############################################################################
function revert_to_snapshot(){
  for node in $xci_vms;do
    revert_snapshot $node $SNAPSHOT_NAME
  done
  sleep 5
  for node in $xci_vms;do
    if [[ $(sudo virsh list) != *$node* ]];then
      sudo virsh start $node
    elif sudo virsh list |grep pause |grep $node -q;then
      sudo virsh resume $node
    fi
  done
}

##############################################################################
# Gets the snapshot name for the given VM
# Arguments:
#   VM name
# Returns:
#   List of available snapshots
##############################################################################
function get_snapshots(){
  node=$1
  local _snapshots=$(sudo virsh snapshot-list $node 2>&1 |grep -vE "Name|-\-\-\-"|awk '{print $1}' |grep -v '^$') ||true
  echo "$_snapshots"
}

##############################################################################
# Deletes snapshots for all the XCI VMs
# Arguments:
#   None
##############################################################################
function delete_snapshots(){
  for node in $xci_vms;do
    _snapshots=$(get_snapshots $node)
    for _snap in ${_snapshots};do
      if ! echo ${_snap} |grep -q "error:";then
        sudo virsh snapshot-delete $node ${_snap}
      fi
    done
  done
}

##############################################################################
# Deletes specific snapshot of the XCI VMs
# Arguments:
#   VM name
##############################################################################
function delete_snapshot(){
  for node in $xci_vms;do
    _snapshots=$(get_snapshots $node)
    if echo $_snapshots |grep -q "^${SNAPSHOT_NAME}$";then
      sudo virsh snapshot-delete $node ${SNAPSHOT_NAME}
    fi
  done
}

##############################################################################
# Creates snapshot for the VM
# Arguments:
#   VM Name
#   Snapshot Name
##############################################################################
function _make_snapshot(){
  sudo virsh snapshot-create-as $1 $2 None
}

##############################################################################
# Creates snapshot for all the XCI VMs.
# Arguments:
#   None
##############################################################################
function make_snapshot(){
  for node in $xci_vms;do
    _make_snapshot $node ${SNAPSHOT_NAME}
  done
}

##############################################################################
# Displays the snapshots available for all the XCI VMs
# Arguments:
#   None
##############################################################################
function list_snaphots(){
  set +x
  for node in $xci_vms;do
    echo "Node: $node"
    echo "Snapshots:"
    sudo virsh snapshot-list $node 2>&1 |grep -vE "Name|-\-\-\-"|awk '{print $1}' |grep -v '^$' ||true
  done

}

##############################################################################
# Destroys the currently running XCI VMs and revert to specified snapshot
# Arguments:
#   None
##############################################################################
function abort_snapshot(){
  virsh_destroy
  # no revert to the old snapshot
  revert_to_snapshot
}

##############################################################################
# Destroys the currently running XCI VMs
# Arguments:
#   None
##############################################################################
function virsh_destroy(){
  for node in $xci_vms;do
    sudo virsh destroy $node || true
    if which vbmc &>/dev/null;then
      HOME=/root sudo -E vbmc stop $node &> /dev/null || true
    fi
  done
}

##############################################################################
# Run the specific command for all the XCI VMs
# Arguments:
#    Command to execute
##############################################################################
function run_for_all_nodes(){
  for node in $xci_vms;do
    $@ $node
  done
}

##############################################################################
# Pause all the running XCI VMs
# Arguments:
#   None
##############################################################################
function virsh_pause(){
  run_for_all_nodes sudo virsh suspend
}

##############################################################################
# Resume all the XCI VMs
# Arguments:
#   None
##############################################################################
function virsh_resume(){
  run_for_all_nodes sudo virsh resume
}

##############################################################################
# Suspends all the XCI VMs
# Arguments:
#   None
##############################################################################
function virsh_suspend(){
  run_for_all_nodes sudo virsh suspend
}

##############################################################################
# Exports the VM images of all the XCI VMs to a tar.gz file. The file is stored
# at $EXPORT_PATH/xci_export_$DATE.tar.gz location.
# While running export function, user shouldn't perform any action on the VMs
# Arguments:
#   None
##############################################################################
function export_domains(){
  echo "Info: Start exporting XCI VMs"
  echo "-----------------------------------------------------------------------"
  rm -rf $EXPORT_PATH
  mkdir -p $EXPORT_PATH
  for node in $xci_vms;do
    sudo virsh dumpxml ${node} > $EXPORT_PATH/${node}.xml
    sudo cp /var/lib/libvirt/images/${node}.qcow2 $EXPORT_PATH/$node.qcow2
  done
  sudo echo $xci_vms > $EXPORT_PATH/nodes
  pushd $EXPORT_PATH
  sudo tar --absolute-names --exclude=xci_export_$DATE.tar.gz -czvf xci_export_$DATE.tar.gz .
  popd
  export_time=$SECONDS
  echo "Info: Export of XCI VMs is successful"
  echo "Info: Export took $(($export_time / 60)) minutes and $(($export_time % 60)) seconds"
  echo "-----------------------------------------------------------------------"

}

##############################################################################
# Imports the VM images from tar.gz file and start running the VMs
# with the given image.
# Arguments:
#   None
##############################################################################
function import_domains(){
  echo "Info: Start importing XCI VMs"
  echo "-----------------------------------------------------------------------"
  untar_dir=~/tmp/xci_import_untar/
  tarball_fullpath=$(realpath $IMPORT_TARBALL)
  rm -rf $untar_dir
  mkdir -p $untar_dir
  pushd $untar_dir
  tar -xzvf $tarball_fullpath
  node_names=$(cat $untar_dir/nodes)
  for node in $node_names;do
    if [ -e /var/lib/libvirt/images/${node}.qcow2 ];then
      echo "Old file /var/lib/libvirt/images/${node}.qcow2 still exists please cleanup first!"
      exit 1
    fi
  done
  for node in $node_names;do
    sudo cp ${node}.qcow2 /var/lib/libvirt/images/
    sudo virsh define ${node}.xml
    sudo virsh start ${node}
  done
  popd
  rm -rf $untar_dir
  import_time=$SECONDS
  echo "Info: Importing XCI VMs is successful"
  echo "Info: Import took $(($import_time / 60)) minutes and $(($import_time % 60)) seconds"
  echo "-----------------------------------------------------------------------"
}

##############################################################################
# Parses the user input and sets appropriate environment variables to proceed
# with executing selected utility function by the user
# Arguments:
#   User Inputs given while executing this script
##############################################################################
function parse_arguments(){
  TASK=$1
  case $TASK in
    take)
      TAKE_SNAPSHOT=true
      SNAPSHOT_NAME=$2
      shift 2
      check_name
      ;;
    revert)
      REVERT_TO_SNAPSHOT=true
      SNAPSHOT_NAME=$2
      shift 2
      check_name
      ;;
    delete-all)
      DELETE_ALL_SNAPSHOTS=true
      shift 1
      ;;
    abort)
      SNAPSHOT_NAME=$2
      shift 2
      check_name
      ABORT_SNAPSHOT=true
      ;;
    list)
      LIST_SNAPSHOTS=true
      shift 1
      ;;
    destroy-all)
      VIRSH_DESTORY=true
      shift 1
      ;;
    suspend)
      VIRSH_SUSPEND=true
      shift 1
      ;;
    resume)
      VIRSH_RESUME=true
      shift 1
      ;;
    export)
      EXPORT=true
      EXPORT_PATH=$2
      shift 2
      if [ ! -d $EXPORT_PATH ];then
        echo "Please provide export path: export <path>"
        exit 1
      fi
      ;;
    import)
      IMPORT=true
      IMPORT_TARBALL=$2
      shift 2
      if [ ! -e $IMPORT_TARBALL ];then
        echo "Please provide a tarbal"
      fi
      ;;
    delete)
      DELETE_SNAPSHOT=true
      SNAPSHOT_NAME=$2
      shift 2
      check_name
      ;;
    *)
      print_help
      exit 1
      ;;
  esac
}

##############################################################################
# Validates the given snapshot name is not empty
# Arguments:
#   None
##############################################################################
function check_name(){
  if [[ "$SNAPSHOT_NAME"x == x ]];then
    echo "Please give a name for the snapshot"
    exit 1
  fi
}

DATE=$(date '+%Y-%m-%d_%H_%M_%S')
parse_arguments $@
if [[ "$TAKE_SNAPSHOT" == true ]];then
  make_snapshot
elif [[ "$REVERT_TO_SNAPSHOT" == true ]];then
  revert_to_snapshot
elif [[ "$DELETE_ALL_SNAPSHOTS" == true ]];then
  delete_snapshots
elif  [[ "$ABORT_SNAPSHOT" == true ]];then
  abort_snapshot
elif  [[ "$LIST_SNAPSHOTS" == true ]];then
  list_snaphots
elif [[ "$VIRSH_DESTORY" == true ]];then
  virsh_destroy
elif [[ "$EXPORT" == true ]];then
  export_domains
elif [[ "$IMPORT" == true ]];then
  import_domains
elif [[ "$DELETE_SNAPSHOT" == true ]];then
  delete_snapshot
elif [[ "$VIRSH_SUSPEND" == true ]];then
  virsh_suspend
elif [[ "$VIRSH_RESUME" == true ]];then
  virsh_resume
else
  echo "Wrong Input. I am unsure what to do!"
  exit 1
fi
