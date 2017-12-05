#!/bin/bash
set -e
# info
# https://www.redhat.com/archives/libvirt-users/2013-February/msg00004.html

NODE_CONFIG=`sudo virsh list --name | grep 'opnfv\|controller*\|compute*'`

function gen_thread_file(){
  file_name=/tmp/$1
  mkdir -p $(dirname $file_name)
}

function thread(){
  id=$(uuidgen)
  local _func=$1
  shift 1
  local _args=$@
  gen_thread_file $id
  rm -rf $file_name
  (_thread $file_name $_func $_args &)
}

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

function revert_snapshot(){
  sudo virsh snapshot-revert --domain $1 $2
  sudo virsh suspend $node
}

function get_node_names(){
  if [[ "$node_names"x != x ]];then
    return
  fi
  # create your own way of finding your vms grep through virsh for example
  if [[ "$node_names"x == x ]];then
    if [[ -n $NODE_CONFIG ]];then
      node_names=$NODE_CONFIG
    else
      echo "Could not evaluate node names please use nodes <list of nodes names> to specify the nodes which should takes into account"
      exit 1
    fi
  fi
}

function revert_to_snapshot(){
  get_node_names
  thread_pool=()
  for node in $node_names;do
    thread revert_snapshot $node $SNAPSHOT_NAME
    thread_pool+=($id)
  done
  sleep 1
  wait_for_threads "${thread_pool[@]}"
  for node in $node_names;do
    if [[ $(sudo virsh list) != *$node* ]];then
      sudo virsh start $node
    elif sudo virsh list |grep pause |grep $node -q;then
      sudo virsh resume $node
    fi
  done
}



function get_snapshots(){
  node=$1
  _snapshots=$(sudo virsh snapshot-list $node 2>&1 |grep -vE "Name|-\-\-\-"|awk '{print $1}' |grep -v '^$') ||true
}
function delete_snapshots(){
  get_node_names
  for node in $node_names;do
    get_snapshots $node
    for _snap in ${_snapshots};do
      if ! echo ${_snap} |grep -q "error:";then
        sudo virsh snapshot-delete $node ${_snap}
      fi
    done
  done
}

function delete_snapshot(){
  get_node_names
  for node in $node_names;do
    get_snapshots $node
    if echo $_snapshots |grep -q "^${SNAPSHOT_NAME}$";then
      sudo virsh snapshot-delete $node ${SNAPSHOT_NAME}
    fi
  done
}

function _make_snapshot(){
  sudo virsh snapshot-create-as $1 $2 None
}

function make_snapshot(){
  get_node_names
  thread_pool=()
  for node in $node_names;do
    thread _make_snapshot $node ${SNAPSHOT_NAME}
    thread_pool+=($id)
  done
  sleep 1
  wait_for_threads ${thread_pool[@]}
}

function list_snaphots(){
  get_node_names
  set +x
  for node in $node_names;do
    echo "Node: $node"
    echo "Snapshots:"
    sudo virsh snapshot-list $node 2>&1 |grep -vE "Name|-\-\-\-"|awk '{print $1}' |grep -v '^$' ||true
  done

}
function abort_snapshot(){
  virsh_destroy
  # no revert to the old snapshot
  revert_to_snapshot
}

function virsh_destroy(){
  get_node_names
  for node in $node_names;do
    sudo virsh destroy $node || true
    if which vbmc &>/dev/null;then
      HOME=/root sudo -E vbmc stop $node &> /dev/null || true
    fi
  done
}

function run_in_threads_on_all_nodes(){
  get_node_names
  thread_pool=()
  for node in $node_names;do
    thread $@ $node
    thread_pool+=($id)
  done
  sleep 1
  wait_for_threads ${thread_pool[@]}

}
function virsh_pause(){
  run_in_threads_on_all_nodes sudo virsh suspend
}

function virsh_resume(){
  run_in_threads_on_all_nodes sudo virsh resume
}

function virsh_suspend(){
  run_in_threads_on_all_nodes sudo virsh suspend
}


function export_domains(){
  virsh_pause
  get_node_names
  rm -rf $EXPORT_PATH
  mkdir -p $EXPORT_PATH
  disks=""
  for node in $node_names;do
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
  sudo echo $node_names > $EXPORT_PATH/nodes
  pushd $EXPORT_PATH
  sudo tar --absolute-names -czvf $EXPORT_PATH/export_$DATE.tar.gz $disks $node_names nodes
  popd
  virsh_resume
}

function import_domains(){
  echo "IMPORT DOMAINS IS STILL UNTESTED!!!!! CTRL-c to abort any other key to continue"
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

function save_nodes(){
  echo "Node config is saved to $NODE_CONFIG"
  mkdir -p $(dirname $NODE_CONFIG)
  echo "$NODE_NAMES" > $NODE_CONFIG
}


function parse_arguments(){
  TASK=$1
  case $TASK in
    take)
      set -x
      TAKE_SNAPSHOT=true
      SNAPSHOT_NAME=$2
      shift 2
      check_name
      ;;
    revert)
      set -x
      REVERT_TO_SNAPSHOT=true
      SNAPSHOT_NAME=$2
      shift 2
      check_name
      ;;
    delete-all)
      set -x
      DELETE_ALL_SNAPSHOTS=true
      shift 1
      ;;
    abort)
      set -x
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
      set -x
      VIRSH_DESTORY=true
      shift 1
      ;;
    suspend)
      set -x
      VIRSH_SUSPEND=true
      shift 1
      ;;
    resume)
      set -x
      VIRSH_RESUME=true
      shift 1
      ;;
    export)
      set -x
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
      set -x
      IMPORT=true
      IMPORT_TARBALL=$2
      shift 2
      if [ ! -e $IMPORT_TARBALL ];then
        echo "Please provide a tarbal"
      fi
      ;;
    delete)
      set -x
      DELETE_SNAPSHOT=true
      SNAPSHOT_NAME=$2
      shift 2
      check_name
      ;;
    nodes-save)
      shift 1
      NODE_NAMES=$@
      SAVE_NODES=true
      ;;
    *)
      print_help
      exit 1
      ;;
  esac
}

function print_help(){
   echo "$0 <task>"
   echo "
   export <path> --no-snapshot        Use --no-snapshot to no take a snapshot before exporting.
                                      The export will then be done on the last snapshot available.
   import <tarball>
   delete-all
   abort <snapshot-name-to-revert-to> The running process which takes snapshots at the moment and revert to snapshot
   list
   destroy-all
   take <snapshot name>
   revert <snapshot name>
   delete <snapshot name>
   nodes-save <nodes list>
   import <tarball>
   suspend
   resume
"
}

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
elif [[ "$SAVE_NODES" == true ]];then
  save_nodes
elif [[ "$VIRSH_SUSPEND" == true ]];then
  virsh_suspend
elif [[ "$VIRSH_RESUME" == true ]];then
  virsh_resume
else
  echo "I am unsure what to do!"
  exit 1
fi
