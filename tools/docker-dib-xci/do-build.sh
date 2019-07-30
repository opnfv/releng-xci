#!/bin/bash

set -e

ONE_DISTRO=${ONE_DISTRO:-}

declare -A flavors=( ["ubuntu-minimal"]="xenial" ["opensuse-minimal"]="42.3" ["centos-minimal"]="7" )
declare -r elements="vm simple-init devuser growroot openssh-server"
declare -r packages="vim,gdb,strace,htop,moreutils,curl,iptables,bridge-utils"
declare -r one_distro=${1}
declare -r BASE_PATH=$(dirname $(readlink -f $0) | sed "s@/xci/.*@@")

if [[ -n ${ONE_DISTRO} ]]; then
	case ${ONE_DISTRO} in
		centos|ubuntu|opensuse) : ;;
		*) echo "unsupported distribution"; exit 1 ;;
	esac
fi

# devuser logins
echo "Configuring devuser..."
export DIB_DEV_USER_USERNAME=devuser
export DIB_DEV_USER_PWDLESS_SUDO=1
export DIB_DEV_USER_AUTHORIZED_KEYS=${HOME}/id_rsa_for_dib.pub
export DIB_DEV_USER_PASSWORD=linux
export DIB_DEV_USER_SHELL="/bin/bash"

# Get public key
curl -s https://git.opnfv.org/releng-xci/plain/xci/scripts/vm/id_rsa_for_dib.pub > ${HOME}/id_rsa_for_dib.pub

echo "Installing diskimage-builder"

sudo -H pip install -q diskimage-builder==2.14.1

do_build() {
	local image=${1}-minimal
	local image_name=${1}
	local os_packages=${packages}
	local os_elements=${elements}
	echo "Building ${image}-${flavors[$image]}..."
	export DIB_RELEASE=${flavors[$image]}
	# Some defaults
	export DIB_YUM_MINIMAL_CREATE_INTERFACES=1 # centos dhcp setup
	if [[ ${image_name} == ubuntu ]]; then
		os_packages="${packages},iputils-ping,vlan"
	elif [[ ${image_name} == centos ]]; then
		os_packages="${packages},iputils"
		os_elements="${elements} epel"
	elif [[ ${image_name} == opensuse ]]; then
		os_packages="${packages},iputils"
	fi
	disk-image-create -t qcow2 -u --no-tmpfs -p ${os_packages} \
		--image-size 10G -o ${image_name}.qcow2 ${os_elements} $image
	sha256sum ${image_name}.qcow2 > ${image_name}.qcow2.sha256.txt
	echo "Done!"
}

if [[ -n ${ONE_DISTRO} ]]; then
	do_build ${ONE_DISTRO}
else
	for image in "${!flavors[@]}"; do
		image_name=${image/-minimal}
		do_build $image_name
	done
fi

