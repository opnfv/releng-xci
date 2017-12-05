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
   export <path> --no-snapshot        Use --no-snapshot to no take a snapshot before exporting.
                                      The export will then be done on the last snapshot available.
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
# Generates a thread id file in /tmp directory for the spawned thread to
# notify waiting main thread by writing 0 or 1 into it (see _thread() function).
# Arguments:
#   Thread Id
##############################################################################
function gen_thread_file(){
  file_name=/tmp/$1
  mkdir -p $(dirname $file_name)
}

##############################################################################
# Executes the given function in a separate thread (i.e. running it in the
# background by using &).
# Arguments:
#   function to execute
#   remaining arguments are specific to the function it executes
##############################################################################
function thread(){
  id=$(uuidgen)
  local _func=$1
  shift 1
  local _args=$@
  gen_thread_file $id
  rm -rf $file_name
  (_thread $file_name $_func $_args &)
}

##############################################################################
# Task being executed in the background. once it completes successfully,
# write 0 into thread id file, otherwise write 1 into it.
# Arguments:
#   Thread Id file path
#   function to execute
#   remaining arguments are specific to the function it executes
##############################################################################
function _thread(){
  local file_name=$1
  local _func=$2
  shift 2
  local args=$@
  if $_func $args;then
    echo 0 > $file_name
  else
    echo 1 > $file_name
  fi
}

##############################################################################
# makes the caller to wait for backgroud tasks to complete for given
# thread ids.
# Arguments:
#   List of local thread id
##############################################################################
function wait_for_threads(){
  local ids=$@
  USE_X=`case "$-" in *x*) echo "-x" ;; esac`
  set +x
  for id in $ids;do
    echo "waiting for thread with id: $id to finish"
    while true;do
      gen_thread_file $id
      if [ -e $file_name ];then
        if [[ "$(cat $file_name)" != 0 ]];then
          echo "Thread with id $id FAILED"
          exit 1
        else
          rm -rf $file_name
          break
        fi
      fi
      sleep 5
    done
    echo "Thread with id $id finished"
 done
 if [[ "$USE_X" == '-x' ]];then
   set -x
 fi
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
  thread_pool=()
  for node in $xci_vms;do
    thread revert_snapshot $node $SNAPSHOT_NAME
    thread_pool+=($id)
  done
  sleep 1
  wait_for_threads "${thread_pool[@]}"
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
# Creates snapshot for all the XCI VMs. The snapshot tasks are optimized by
# running each vm snapshot task in background/parallel and returns snapshot is
# complete for all the VMs.
# Arguments:
#   None
##############################################################################
function make_snapshot(){
  thread_pool=()
  for node in $xci_vms;do
    thread _make_snapshot $node ${SNAPSHOT_NAME}
    thread_pool+=($id)
  done
  sleep 1
  wait_for_threads ${thread_pool[@]}
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
# Run the specific command in the background for all the XCI VMs
# Arguments:
#    Command to execute
##############################################################################
function run_in_threads_on_all_nodes(){
  thread_pool=()
  for node in $xci_vms;do
    thread $@ $node
    thread_pool+=($id)
  done
  sleep 1
  wait_for_threads ${thread_pool[@]}

}

##############################################################################
# Pause all the running XCI VMs
# Arguments:
#   None
##############################################################################
function virsh_pause(){
  run_in_threads_on_all_nodes sudo virsh suspend
}

##############################################################################
# Resume all the XCI VMs
# Arguments:
#   None
##############################################################################
function virsh_resume(){
  run_in_threads_on_all_nodes sudo virsh resume
}

##############################################################################
# Suspends all the XCI VMs
# Arguments:
#   None
##############################################################################
function virsh_suspend(){
  run_in_threads_on_all_nodes sudo virsh suspend
}

##############################################################################
# Exports the snapshot of all the XCI VMs to a tar.gz file. The file is stored
# at $EXPORT_PATH/xci_export_$DATE.tar.gz location.
# While running export function, user shouldn't perform any action on the VMs
# Arguments:
#   None
##############################################################################
function export_domains(){
  virsh_pause
  rm -rf $EXPORT_PATH
  mkdir -p $EXPORT_PATH
  disks=""
  for node in $xci_vms;do
    node_path=$EXPORT_PATH/$node
    mkdir -p $node_path
    snapshots=$(sudo virsh snapshot-list $node |grep -vE "\-\-\-\-|Name|^$"|awk '{print $1}')
    for snapshot in $snapshots;do
      sudo virsh snapshot-dumpxml $node $snapshot --security-info > $node_path/snapshot_xml_${snapshot}
    done
    sudo virsh snapshot-current $node --name > $node_path/current
    echo "$snapshots" > $node_path/snapshots
    sudo virsh dumpxml $node > $node_path/xml
    # we will only copy the first disk for now this is a hack! and not vailid for normal deployments
    # backing files etc would be ignored
    disk_path=$(sudo virsh dumpxml $node|grep source |grep file|cut -d "'" -f2)
    echo $disk_path > $node_path/disk_path
    disks="$disks $disk_path"
  done
  sudo echo $xci_vms > $EXPORT_PATH/nodes
  pushd $EXPORT_PATH
  sudo tar --absolute-names -czvf $EXPORT_PATH/xci_export_$DATE.tar.gz $disks $xci_vms nodes
  popd
  virsh_resume
}

##############################################################################
# Imports the snapshots from tar.gz file and start running the VMs
# with the given snapshot.
# Arguments:
#   None
##############################################################################
function import_domains(){
  read
  untar_dir=~/import_untar/
  tarball_fullpath=$(realpath $IMPORT_TARBALL)
  rm -rf $untar_dir
  mkdir -p $untar_dir
  pushd $untar_dir
  tar -xzvf $tarball_fullpath nodes
  node_names=$(cat $untar_dir/nodes)
  # hack for now!
  for node in $node_names;do
    if [ -e ~/libvirt_images/${node}.img ];then
      echo "Old file ~/libvirt_images/${node}.img still exists please cleanup first!"
      exit 1
    fi
  done
  tar --keep-old-files --absolute-names -xzvf $tarball_fullpath
  popd
  node_names=$(cat $untar_dir/nodes)
  for node in $node_names;do
    node_dir=$untar_dir/$node
    # we rewirte mac always!
    EXCLUDES="mac address"
    cat $node_dir/xml |grep -vE "$EXCLUDES" > /tmp/xml
    sudo virsh define /tmp/xml
    for snapshot in $(cat $node_dir/snapshots);do
      sudo virsh snapshot-create $node $node_dir/snapshot_xml_$snapshot
    done
  done
  # ALL nodes will be reverted to the current snapshot of the last VM
  # this is a hack! but should be ok in 99% of the cases
  SNAPSHOT_NAME=$(cat $node_dir/current)
  revert_to_snapshot
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
      if [ ! -d $EXPORT_PATH ];then
        echo "export <path> make sure exists"
        exit 1
      fi
      shift 2
      SNAPSHOT_NAME=export_$DATE
      if [[ "$1" == --no-snapshot ]];then
        TAKE_SNAPSHOT=false
      else
        TAKE_SNAPSHOT=true
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
