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

export DEFAULT_XCI_TEST=${DEFAULT_XCI_TEST:-false}

#grep -q -i ^Y$ /sys/module/kvm_intel/parameters/nested || { echo "Nested virtualization is not enabled but it's needed for XCI to work"; exit 1; }

usage() {
	echo """
	$0 <distro>

	distro must be one of 'ubuntu', 'opensuse', 'centos'
	"""
}

[[ $# -ne 1 ]] && usage && exit 1

declare -r CPU=host
declare -r NCPUS=24
declare -r MEMORY=49152
declare -r DISK=500
declare -r VM_NAME=${1}_xci_vm
declare -r OS=${1}
declare -r NETWORK="jenkins-test"
declare -r BASE_PATH=$(dirname $(readlink -f $0) | sed "s@/xci/.*@@")

echo "Preparing new virtual machine '${VM_NAME}'..."

source /etc/os-release
echo "Installing host (${ID,,}) dependencies..."
# check we can run sudo
if ! sudo -n "true"; then
	echo ""
	echo "passwordless sudo is needed for '$(id -nu)' user."
	echo "Please fix your /etc/sudoers file. You likely want an"
	echo "entry like the following one..."
	echo ""
	echo "$(id -nu) ALL=(ALL) NOPASSWD: ALL"
	exit 1
fi
case ${ID,,} in
	*suse) sudo zypper -q -n in virt-manager qemu-kvm qemu-tools libvirt-daemon docker libvirt-client libvirt-daemon-driver-qemu iptables ebtables dnsmasq
			  ;;
	centos) sudo yum install -q -y epel-release
			sudo yum install -q -y in virt-manager qemu-kvm qemu-kvm-tools qemu-img libvirt-daemon-kvm docker iptables ebtables dnsmasq
			;;
	ubuntu) sudo apt-get install -y -q=3 virt-manager qemu-kvm libvirt-bin qemu-utils docker.io docker iptables ebtables dnsmasq
			;;
esac

echo "Ensuring libvirt and docker services are running..."
sudo systemctl -q start libvirtd
sudo systemctl -q start docker

echo "Building new ${OS} image..."

_retries=20
while [[ $_retries -gt 0 ]]; do
	if pgrep -a docker | grep -q docker-dib-xci &> /dev/null; then
		echo "There is another dib process running... ($_retries retries left)"
		sleep 60
		(( _retries = _retries - 1 ))
	else
		docker_cmd="sudo docker"
		# See if we can run docker as regular user.
		docker ps &> /dev/null && docker_cmd="docker"
		docker_name="docker_xci_builder_${OS}"
		# Destroy previous containers
		if eval $docker_cmd ps -a | grep -q ${docker_name} &>/dev/null; then
			echo "Destroying previous container..."
			eval $docker_cmd rm -f ${docker_name}
		fi
		# Prepare new working directory
		dib_workdir="$(pwd)/docker_dib_xci_workdir"
		[[ ! -d $dib_workdir ]] && mkdir $dib_workdir
		chmod 777 -R $dib_workdir
		# Get rid of stale files
		rm -rf $dib_workdir/*.qcow2 $dib_workdir/*.sha256.txt $dib_workdir/*.d
		echo "Getting the latest docker image..."
		eval $docker_cmd pull hwoarang/docker-dib-xci:latest
		echo "Initiating dib build..."
		eval $docker_cmd run --name ${docker_name} \
			--rm --privileged=true -e ONE_DISTRO=${OS} \
			-t -v $dib_workdir:$dib_workdir -w $dib_workdir \
			hwoarang/docker-dib-xci '/usr/bin/do-build.sh'
		sudo chown $SUDO_UID:$SUDO_GID $dib_workdir/${OS}.qcow2
		declare -r OS_IMAGE_FILE=$dib_workdir/${OS}.qcow2

		break
	fi
done

[[ ! -e ${OS_IMAGE_FILE} ]] && echo "${OS_IMAGE_FILE} not found! This should never happen!" && exit 1

echo "Resizing disk image '${OS}' to ${DISK}G..."
qemu-img resize ${OS_IMAGE_FILE} ${DISK}G

echo "Creating new network '${NETWORK}' if it does not exist already..."
if ! sudo virsh net-list --name --all | grep -q ${NETWORK}; then
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
fi

sudo virsh net-list --autostart | grep -q ${NETWORK} || sudo virsh net-autostart ${NETWORK}
sudo virsh net-list --inactive | grep -q ${NETWORK} && sudo virsh net-start ${NETWORK}

echo "Destroying previous instances if necessary..."
sudo virsh destroy ${VM_NAME} || true
sudo virsh undefine ${VM_NAME} || true

echo "Installing virtual machine '${VM_NAME}'..."
sudo virt-install -n ${VM_NAME} --memory ${MEMORY} --vcpus ${NCPUS} --cpu ${CPU} \
	--import --disk=${OS_IMAGE_FILE},cache=unsafe --network network=${NETWORK} \
	--graphics none --hvm --noautoconsole

_retries=30
while [[ $_retries -ne 0 ]]; do
	_ip=$(sudo virsh domifaddr ${VM_NAME} | grep -o --colour=never 192.168.140.[[:digit:]]* | cat )
	if [[ -z ${_ip} ]]; then
		echo "Waiting for '${VM_NAME}' virtual machine to boot ($_retries retries left)..."
		sleep 5
		(( _retries = _retries - 1 ))
	else
		break
	fi
done
[[ -n $_ip ]] && echo "'${VM_NAME}' virtual machine is online at $_ip"
[[ -z $_ip ]] && echo "'${VM_NAME}' virtual machine did not boot on time" && exit 1

# Fix up perms if needed to make ssh happy
chmod 600 ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib*
# Remove it from known_hosts
ssh-keygen -R $_ip || true
ssh-keygen -R ${VM_NAME} || true

declare -r vm_ssh="ssh -o StrictHostKeyChecking=no -i ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib -l devuser"

_retries=30
_ssh_exit=0

echo "Verifying operational status..."
while [[ $_retries -ne 0 ]]; do
	if eval $vm_ssh $_ip "sudo cat /etc/os-release"; then
		_ssh_exit=$?
		break;
	else
		_ssh_exit=$?
		sleep 5
		(( _retries = _retries - 1 ))
	fi
done
[[ $_ssh_exit != 0 ]] && echo "Failed to SSH to the virtual machine '${VM_NAME}'! This should never happen!" && exit 1

echo "Congratulations! Your shiny new '${VM_NAME}' virtual machine is fully operational! Enjoy!"

echo "Adding ${VM_NAME}_xci_vm entry to /etc/hosts"
sudo sed -i "/.*${VM_NAME}.*/d" /etc/hosts
sudo bash -c "echo '${_ip} ${VM_NAME}' >> /etc/hosts"

echo "Dropping a minimal .ssh/config file"
cat > $HOME/.ssh/config<<EOF
Host *
StrictHostKeyChecking no
IdentityFile ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib

Host *_xci_vm
User devuser

Host *_xci_vm_opnfv
User root
TCPKeepAlive yes
StrictHostKeyChecking no
ProxyCommand ssh -l devuser \$(echo %h | sed 's/_opnfv//') 'nc 192.168.122.2 %p'
EOF

echo "Preparing test environment..."
# *_xci_vm hostname is invalid. Letst just use distro name
$vm_ssh $_ip "sudo hostname ${VM_NAME/_xci*}"
# Start with good dns
$vm_ssh $_ip 'sudo bash -c "echo nameserver 8.8.8.8 > /etc/resolv.conf"'
$vm_ssh $_ip 'sudo bash -c "echo nameserver 8.8.4.4 >> /etc/resolv.conf"'
cat > ${BASE_PATH}/vm_hosts.txt <<EOF
127.0.0.1 localhost ${VM_NAME/_xci*}
::1 localhost ipv6-localhost ipv6-loopback
fe00::0 ipv6-localnet
fe00::1 ipv6-allnodes
fe00::2 ipv6-allrouters
ff00::3 ipv6-allhosts
$_ip ${VM_NAME/_xci*}
EOF

# Need to copy releng-xci to the vm so we can execute stuff
do_copy() {
	rsync -a \
		--exclude "${VM_NAME}*" \
		--exclude "${OS}*" \
		--exclude "$dib_workdir*" \
		--exclude "build.log" \
		-e "$vm_ssh" ${BASE_PATH}/* $_ip:~/releng-xci/
}

do_copy
rm ${BASE_PATH}/vm_hosts.txt

# Copy keypair
$vm_ssh $_ip "cp --preserve=all ~/releng-xci/xci/scripts/vm/id_rsa_for_dib /home/devuser/.ssh/id_rsa"
$vm_ssh $_ip "cp --preserve=all ~/releng-xci/xci/scripts/vm/id_rsa_for_dib.pub /home/devuser/.ssh/id_rsa.pub"
$vm_ssh $_ip "sudo mv /home/devuser/releng-xci/vm_hosts.txt /etc/hosts"

set +e

_has_test=true
echo "Verifying test script exists..."
$vm_ssh $_ip "bash -c 'stat ~/releng-xci/run_jenkins_test.sh'"
if [[ $? != 0 ]]; then
	echo "Failed to find a 'run_jenkins_test.sh' script..."
	if ${DEFAULT_XCI_TEST}; then
		echo "Creating a default test case to run xci-deploy.sh"
		cat > ${BASE_PATH}/run_jenkins_test.sh <<EOF
#!/bin/bash
cd releng-xci/xci
./xci-deploy.sh
EOF
		# Copy again
		do_copy
	else
		_has_test=false
	fi
fi

if ${_has_test}; then
	echo "Running test..."
	$vm_ssh $_ip "bash ~/releng-xci/run_jenkins_test.sh"
	xci_error=$?
else
	echo "No jenkins test was found. The virtual machine will remain idle!"
	xci_error=0
fi

exit $xci_error
