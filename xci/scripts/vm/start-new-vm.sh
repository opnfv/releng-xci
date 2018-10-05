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

# If we are not on real Jenkins CI, then just set this variable so we can pretend
# we are since various playbooks use this variable to determine if they are being
# executed on a CI or not.
export JENKINS_HOME="${JENKINS_HOME:-${HOME}}"

# Set this option to destroy the VM on failures. This is helpful when we
# don't want to preserve the VM for debugging purposes.
export XCI_KEEP_CLEAN_VM_ON_FAILURES=${XCI_KEEP_CLEAN_VM_ON_FAILURES:-true}

export DEFAULT_XCI_TEST=${DEFAULT_XCI_TEST:-false}
# JIT Build of OS image to load on the clean VM
export XCI_BUILD_CLEAN_VM_OS=${XCI_BUILD_CLEAN_VM_OS:-true}
# Use cached (possibly outdated) images instead of always using the latest
# ones.
export XCI_UPDATE_CLEAN_VM_OS=${XCI_UPDATE_CLEAN_VM_OS:-false}

# IP of OPNFV VM so we remove it from known_hosts
OPNFV_VM_IP=192.168.122.2

grep -q -i ^Y$ /sys/module/kvm_intel/parameters/nested || { echo "Nested virtualization is not enabled but it's needed for XCI to work"; exit 1; }

destroy_vm_on_failures() {
	local exit_err=${xci_error:-130}
	if ! ${XCI_KEEP_CLEAN_VM_ON_FAILURES}; then
		sudo virsh destroy ${VM_NAME}_xci_vm || true
		sudo virsh undefine ${VM_NAME}_xci_vm || true
	fi
	exit $exit_err
}

usage() {
	echo """
	$0 <distro>

	distro must be one of 'ubuntu', 'opensuse', 'centos'
	"""
}

update_clean_vm_files() {
	local opnfv_url="http://artifacts.opnfv.org/releng/xci/images"
	local vm_cache=${XCI_CACHE_DIR}/clean_vm/images
	local sha_local shafile=${vm_cache}/${OS}.qcow2.sha256.txt
	local sha_remote="${opnfv_url}/${OS}.qcow2.sha256.txt"
	local image_remote="${opnfv_url}/${OS}.qcow2"

	get_new_vm_files() {
		echo "Downloading new ${OS} images from ${opnfv_url}"
		rm -rf ${vm_cache}/${OS}*
		curl -O -s --retry 10 ${image_remote}
		curl -O -s --retry 10 ${sha_remote}
	}

	# There are 3 reasons why we want to fetch files from the GS storage
	# 1) We don't have a shafile locally (clean cache?)
	# 2) We have one but it's not the latest one
	# 3) We have one but the qcow2 is corrupted
	cd ${vm_cache}
	if [[ -e ${shafile} ]]; then
		echo "Found local ${OS} files in cache..."
		sha_local=$(awk '{print $1}' $shafile)
		if $XCI_UPDATE_CLEAN_VM_OS; then
			echo "Updating local copies of ${OS}..."
			! curl --retry 10 -s ${sha_remote} | grep -q ${sha_local} && \
			get_new_vm_files
		fi
		echo "Verifying integrity of ${OS} files..."
		! sha256sum --status -c $shafile && get_new_vm_files
	else
		get_new_vm_files
	fi
	echo "Final integrity check of ${OS} files..."
	sha256sum --status -c $shafile
	cd - &> /dev/null
}

[[ $# -ne 1 ]] && usage && exit 1

declare -r CPU=${XCI_CPU_TYPE:-host-model}
declare -r NCPUS=${XCI_NCPUS:-24}
declare -r MEMORY=${XCI_MEMORY_SIZE:-65536}
declare -r DISK=${XCI_DISK_SIZE:-500}
declare -r VM_NAME=${1}_xci_vm
declare -r OS=${1}
declare -r NETWORK="jenkins-test"
declare -r BASE_PATH=$(dirname $(readlink -f $0) | sed "s@/xci/.*@@")
declare -r XCI_CACHE_DIR=${HOME}/.cache/opnfv_xci_deploy

echo "Preparing new virtual machine '${VM_NAME}'..."

echo "Destroying previous '${VM_NAME}' instances..."
sudo virsh destroy ${VM_NAME} || true
sudo virsh undefine ${VM_NAME} || true

source /etc/os-release
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

COMMON_DISTRO_PKGS=(vim strace gdb htop dnsmasq docker iptables ebtables virt-manager qemu-kvm)

case ${ID,,} in
	*suse*)
		pkg_mgr_cmd="sudo zypper -q -n install ${COMMON_DISTRO_PKGS[@]} qemu-tools libvirt-daemon libvirt-client libvirt-daemon-driver-qemu"
		;;
	centos)
		pkg_mgr_cmd="sudo yum install -C -q -y epel-release"
		pkg_mgr_cmd+=" && sudo yum install -C -q -y in ${COMMON_DISTRO_PKGS[@]} qemu-kvm-tools qemu-img libvirt-daemon-kvm"
		;;
	ubuntu)
		pkg_mgr_cmd="sudo apt-get install --no-upgrade -y -q=3 ${COMMON_DISTRO_PKGS[@]} libvirt-bin qemu-utils docker.io"
		;;
esac

echo "Checking for running package manager instance..."
while true; do
	_pkg_mgr_proc=$(pgrep -f "${pkg_mgr_cmd%*install*}" | cat)
	if [[ -n ${_pkg_mgr_proc} ]]; then
		echo "Wainting for process ${_pkg_mgr_proc} to finish..."
		sleep 60
	else
		break
	fi
done

echo "Installing host (${ID,,}) dependencies..."
set +e
eval ${pkg_mgr_cmd}
set -e

echo "Ensuring libvirt and docker services are running..."
sudo systemctl -q start libvirtd
sudo systemctl -q start docker

echo "Preparing XCI cache..."
mkdir -p ${XCI_CACHE_DIR}/ ${XCI_CACHE_DIR}/clean_vm/images/
# Record our information
uid=$(id -u)
gid=$(id -g)
sudo chmod 777 -R $XCI_CACHE_DIR/clean_vm/images/
sudo chown $uid:$gid -R $XCI_CACHE_DIR/clean_vm/images/

if ${XCI_BUILD_CLEAN_VM_OS}; then
	echo "Building new ${OS} image..."
	_retries=20
	while [[ $_retries -gt 0 ]]; do
		if pgrep -a docker | grep -q docker-dib-xci &> /dev/null; then
			echo "There is another dib process running... ($_retries retries left)"
			sleep 60
			(( _retries = _retries - 1 ))
		else
			${BASE_PATH}/xci/scripts/vm/build-dib-os.sh ${OS}
		break
		fi
	done
else
	echo "Retrieving ${OS} image files..."
	update_clean_vm_files
fi

declare -r XCI_DEPLOYMENT_IMAGE="deployment_image.qcow2"

# Doesn't matter if we just built an image or got one from artifacts. In both
# cases there should be a copy in the cache so copy it over.
sudo rm -f ${BASE_PATH}/${OS}.qcow2
# Fix perms again...
sudo chmod 777 -R $XCI_CACHE_DIR/clean_vm/images/
sudo chown $uid:$gid -R $XCI_CACHE_DIR/clean_vm/images/
cp ${XCI_CACHE_DIR}/clean_vm/images/${OS}.qcow2* ${BASE_PATH}/
cp ${XCI_CACHE_DIR}/clean_vm/images/${OS}.qcow2.sha256.txt ${BASE_PATH}/${XCI_DEPLOYMENT_IMAGE}.sha256.txt
cp ${XCI_CACHE_DIR}/clean_vm/images/${OS}.qcow2 ${BASE_PATH}/${XCI_DEPLOYMENT_IMAGE}

cd ${BASE_PATH}
declare -r OS_IMAGE_FILE=${OS}.qcow2

[[ ! -e ${OS_IMAGE_FILE} ]] && echo "${OS_IMAGE_FILE} not found! This should never happen!" && exit 1

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

echo "Determining backend storage device..."
if sudo vgscan | grep -q xci-vm-vg; then
	echo "Using LVM backend..."
	lv_dev="/dev/xci-vm-vg/xci-vm-${OS}"
	echo "Creating new xci-vm-${OS} LV if necessary..."
	sudo lvscan | grep -q xci-vm-${OS} || {
		sudo lvcreate -W y -l 33%FREE -n xci-vm-${OS} xci-vm-vg
		sudo mkfs.ext4 -m 0 ${lv_dev}
	}
	echo "Flusing the ${OS_IMAGE_FILE} image to ${lv_dev}..."
	sudo qemu-img convert -O raw ${OS_IMAGE_FILE} ${lv_dev}
	disk_config="${lv_dev},cache=unsafe,io=threads,bus=virtio"
else
	echo "Using file backend..."
	echo "Resizing disk image '${OS}' to ${DISK}G..."
	qemu-img resize ${OS_IMAGE_FILE} ${DISK}G
	disk_config="${OS_IMAGE_FILE},cache=unsafe,io=threads,bus=virtio"
fi

echo "Installing virtual machine '${VM_NAME}'..."
sudo virt-install -n ${VM_NAME} --memory ${MEMORY} --vcpus ${NCPUS} --cpu ${CPU} \
	--import --disk=${disk_config} --network network=${NETWORK},model=virtio \
	--graphics none --hvm --noautoconsole

trap destroy_vm_on_failures EXIT

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
for item in $_ip ${VM_NAME} ${OPNFV_VM_IP} ${VM_NAME}_opnfv; do
    ssh-keygen -R $item || true
done

# Initial ssh command until we setup everything
vm_ssh="ssh -o StrictHostKeyChecking=no -i ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib -l devuser"

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

echo "Adding ${VM_NAME} entry to /etc/hosts"
sudo sed -i "/.*${VM_NAME}.*/d" /etc/hosts
sudo bash -c "echo '${_ip} ${VM_NAME}' >> /etc/hosts"

# remove ssh xci-vm-config that uses none-distro specific filename
/bin/rm -f $HOME/.ssh/xci-vm-config

echo "Dropping a minimal .ssh/config file"
cat > $HOME/.ssh/${OS}-xci-vm-config<<EOF
Host *
StrictHostKeyChecking no
ServerAliveInterval 60
ServerAliveCountMax 5
IdentityFile ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib

Host ${OS}_xci_vm
User devuser

Host ${OS}_xci_vm_opnfv
Hostname 192.168.122.2
User root
TCPKeepAlive yes
StrictHostKeyChecking no
ProxyCommand ssh -l devuser -i ${BASE_PATH}/xci/scripts/vm/id_rsa_for_dib ${OS}_xci_vm -W %h:%p
EOF

# Final ssh command which will also test the configuration file
declare -r vm_ssh="ssh -F $HOME/.ssh/${OS}-xci-vm-config"

echo "Preparing test environment..."
# *_xci_vm hostname is invalid. Letst just use distro name
$vm_ssh ${VM_NAME} "sudo hostname ${VM_NAME/_xci*}"
# Start with good dns
$vm_ssh ${VM_NAME} 'sudo bash -c "echo nameserver 192.168.140.1 > /etc/resolv.conf"'
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
    echo "Copying releng-xci host folder to guest vm..."
    rsync -a \
        --exclude "${VM_NAME}*" \
        --include "${XCI_DEPLOYMENT_IMAGE}*" \
        --exclude "*qcow2*" \
        --exclude "build.log" \
        -e "$vm_ssh" ${BASE_PATH}/ ${VM_NAME}:~/releng-xci/
}

do_copy
rm ${BASE_PATH}/vm_hosts.txt

# Copy keypair
$vm_ssh ${VM_NAME} "cp --preserve=all ~/releng-xci/xci/scripts/vm/id_rsa_for_dib /home/devuser/.ssh/id_rsa"
$vm_ssh ${VM_NAME} "cp --preserve=all ~/releng-xci/xci/scripts/vm/id_rsa_for_dib.pub /home/devuser/.ssh/id_rsa.pub"
$vm_ssh ${VM_NAME} "sudo mv /home/devuser/releng-xci/vm_hosts.txt /etc/hosts"
# Disable 3-level nested virtualization since it makes things terribly slow
$vm_ssh ${VM_NAME} "sudo bash -c 'echo \"options kvm_intel nested=0\" > /etc/modprobe.d/qemu-system-x86.conf'"
$vm_ssh ${VM_NAME} "sudo modprobe -r kvm_intel && sudo modprobe -a kvm_intel"
$vm_ssh ${VM_NAME} "sudo bash -c 'mkdir -p /root/.ssh && cat /home/devuser/.ssh/id_rsa.pub > /root/.ssh/authorized_keys'"
$vm_ssh ${VM_NAME} "sudo bash -c 'mkdir -p /var/lib/libvirt/images'"
rsync -a -e "$vm_ssh" --include "${BASE_PATH}/${XCI_DEPLOYMENT_IMAGE}*" --exclude '*' root@${VM_NAME}:/var/lib/libvirt/images/

set +e

_has_test=true
echo "Verifying test script exists..."
$vm_ssh ${VM_NAME} "bash -c 'stat ~/releng-xci/run_jenkins_test.sh'"
if [[ $? != 0 ]]; then
	echo "Failed to find a 'run_jenkins_test.sh' script..."
	if [[ ${DEFAULT_XCI_TEST} == true ]]; then
		echo "Creating a default test case to run xci-deploy.sh"
		cat > ${BASE_PATH}/run_jenkins_test.sh <<EOF
#!/bin/bash
set -o pipefail
export XCI_FLAVOR=mini
export BIFROST_CREATE_IMAGE_VIA_DIB=false
cd ~/releng-xci/xci
./xci-deploy.sh | ts
EOF
		# Copy again
		do_copy
	else
		_has_test=false
	fi
fi

if ${_has_test}; then
	echo "Running test..."
	$vm_ssh ${VM_NAME} "bash ~/releng-xci/run_jenkins_test.sh"
	xci_error=$?
else
	echo "No jenkins test was found. The virtual machine will remain idle!"
	xci_error=0
fi

exit $xci_error
