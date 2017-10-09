#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# find where we are
declare -r BASE_PATH=$(dirname $(readlink -f $0) | sed "s@/xci/.*@@")

source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    # These should ideally match the CI jobs
    debian|ubuntu)
        XCI_VM=${XCI_VM:-ubuntu} ;;
    redhat|centos|fedora)
        XCI_VM=${XCI_VM:-centos} ;;
    *suse)
        XCI_VM=${XCI_VM:-opensuse} ;;
	*) echo "Distribution '$ID' is unsupported by XCI!"; exit 1 ;;
esac

# These options are good for a Developer Sandbox but you may want
# to tweak them appropriately.
# Do not build clean VM images from scratch
export XCI_BUILD_CLEAN_VM_OS=${XCI_BUILD_CLEAN_VM_OS:-false}
# Do not check for updated images by default
export XCI_UPDATE_CLEAN_VM_OS=${XCI_UPDATE_CLEAN_VM_OS:-false}
# Default test case
export DEFAULT_XCI_TEST=${DEFAULT_XCI_TEST:-true}
# Run default test case
export DEFAULT_XCI_TEST_RUN=${DEFAULT_XCI_TEST_RUN:-true}
# Keep VM around on failures
export XCI_KEEP_CLEAN_VM_ON_FAILURES=${XCI_KEEP_CLEAN_VM_ON_FAILURES:-true}
# This VM is rather small to hold most of the flavors but it should be good
# enough to hold the AIO installation.
export XCI_VM_NCPUS=${XCI_VM_NCPUS:-8}
export XCI_VM_MEMORY_SIZE=${XCI_VM_MEMORY_SIZE:-12288}
export XCI_VM_DISK_SIZE=${XCI_VM_DISK_SIZE:-120}

echo "================================================================================="
echo
echo "The XCI will be deployed in the '${XCI_VM}_xci_vm' virtual machine."
echo
echo "You can access this host once it's created using the following command:"
echo
echo "ssh -i ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib -F ${HOME}/.ssh/xci-vm-config ${XCI_VM}_xci_vm"
echo
echo "================================================================================="
sleep 5

# Start the deployment
$BASE_PATH/xci/scripts/vm/start-new-vm.sh ${XCI_VM}
