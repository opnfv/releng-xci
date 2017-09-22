#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2017 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

lsb_release -i | grep -q -i ubuntu || { echo "This script only works on Ubuntu distros"; exit 1; }

grep -q -i ^Y$ /sys/module/kvm_intel/parameters/nested || { echo "Nested virtualization is not enabled but it's needed for XCI to work"; exit 1; }

usage() {
	echo """
	$0 <distro>

	distro must be one of 'ubuntu', 'opensuse', 'centos'
	"""
}

[[ $# -ne 1 ]] && usage && exit 1

declare -r CPU=host
declare -r NCPUS=8
declare -r MEMORY=32768
declare -r DISK=500
declare -r NAME=${1}
declare -r NETWORK="jenkins-test"
declare -r BASE_PATH=$(dirname $(readlink -f $0) | sed "s@/xci.*@@")

echo "Preparing new virtual machine '${NAME}'..."

# NOTE(hwoarang) This should be removed when we move the dib images to a central place
echo "Building '${NAME}' image (tail build.log for progress and failures)..."
$BASE_PATH/xci/scripts/vm/build-dib-os.sh ${NAME} > build.log 2>&1

[[ ! -e ${1}.qcow2 ]] && echo "${1}.qcow2 not found! This should never happen!" && exit 1

sudo apt-get install -y -q=3 virt-manager qemu-kvm libvirt-bin qemu-utils
sudo systemctl -q start libvirtd

echo "Resizing disk image '${NAME}' to ${DISK}G..."
qemu-img resize ${NAME}.qcow2 ${DISK}G

echo "Creating new network '${NETWORK}' if it does not exist already..."
if ! sudo virsh net-list --name | grep -q ${NETWORK}; then
	cat > /tmp/${NETWORK}.xml <<EOF
<network>
  <name>${NETWORK}</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='jenkins_br0' std='off' delay='0'/>
  <ip address='192.168.140.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.140.2' end='192.168.140.254'/>
    </dhcp>
  </ip>
</network>
EOF
	sudo virsh net-define /tmp/${NETWORK}.xml
	sudo virsh net-autostart ${NETWORK}
	sudo virsh net-start ${NETWORK}
fi

echo "Destroying previous instances if necessary..."
sudo virsh destroy ${NAME} || true
sudo virsh undefine ${NAME} || true

echo "Installing virtual machine '${NAME}'..."
sudo virt-install -n ${NAME} --memory ${MEMORY} --vcpus ${NCPUS} --cpu ${CPU} \
	--import --disk=${NAME}.qcow2 --network network=${NETWORK} \
	--graphics none --hvm --noautoconsole

_retries=30
while [[ $_retries -ne 0 ]]; do
	_ip=$(sudo virsh domifaddr ${NAME} | grep -o --colour=never 192.168.140.[[:digit:]]* | cat )
	if [[ -z ${_ip} ]]; then
		echo "Waiting for '${NAME}' virtual machine to boot ($_retries retries left)..."
		sleep 5
		(( _retries = _retries - 1 ))
	else
		break
	fi
done
[[ -n $_ip ]] && echo "'${NAME}' virtual machine is online at $_ip"
[[ -z $_ip ]] && echo "'${NAME}' virtual machine did not boot on time" && exit 1

# Fix up perms if needed to make ssh happy
chmod 600 ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib*
# Remove it from known_hosts
ssh-keygen -R $_ip

declare -r vm_ssh="ssh -o StrictHostKeyChecking=no -i ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib -l devuser"

_retries=30
_ssh_exit=0

echo "Verifying operational status..."
while [[ $_retries -ne 0 ]]; do
	if eval $vm_ssh $_ip "sudo cat /etc/os-release" 2>/dev/null; then
		_ssh_exit=$?
		break;
	else
		_ssh_exit=$?
		sleep 5
		(( _retries = _retries - 1 ))
	fi
done
[[ $_ssh_exit != 0 ]] && echo "Failed to SSH to the virtual machine '${NAME}'! This should never happen!" && exit 1

echo "Congratulations! Your shiny new '${NAME}' virtual machine is fully operational! Enjoy!"

echo "Preparing test environment..."
# Start with good dns
$vm_ssh $_ip 'sudo bash -c "echo nameserver 8.8.8.8 > /etc/resolv.conf"'
$vm_ssh $_ip 'sudo bash -c "echo nameserver 8.8.4.4 >> /etc/resolv.conf"'
rsync -a --exclude "xci/scripts*" \
	--exclude "${NAME}*" \
	--exclude "build.log" \
	-e "$vm_ssh" ${BASE_PATH} $_ip:~/

echo "Generating keypair for devuser..."
$vm_ssh $_ip "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"

set +e

echo "Verifying test script exists..."
$vm_ssh $_ip "bash -c 'stat ~/$(basename ${BASE_PATH})/run_jenkins_test.sh'"
if [[ $? != 0 ]]; then
	echo "Failed to get information from 'run_jenkins_test.sh' script!"
	echo "Did you remember to create one before running this script?"
	echo "Remember the script is being run from the devuser's home directory"
	exit 1
fi

echo "Running test..."
$vm_ssh $_ip "bash ~/$(basename ${BASE_PATH})/run_jenkins_test.sh"
xci_error=$?

sudo virsh destroy ${NAME}
sudo virsh undefine ${NAME}

exit $xci_error
