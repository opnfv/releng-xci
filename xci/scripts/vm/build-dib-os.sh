#!/bin/bash
##############################################################################
# Copyright (c) 2017 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

# This only works on ubuntu hosts
lsb_release -i | grep -q -i ubuntu || { echo "This script only works on Ubuntu distros"; exit 1; }

declare -A flavors=( ["ubuntu-minimal"]="xenial" ["opensuse-minimal"]="42.3" ["centos-minimal"]="7" )
elements="vm simple-init devuser growroot openssh-server"
declare -r one_distro=${1}
if [[ -n ${one_distro} ]]; then
	case ${one_distro} in
		centos|ubuntu|opensuse) : ;;
		*) echo "unsupported distribution"; exit 1 ;;
	esac
fi

# devuser logins
echo "Configuring devuser..."
export DIB_DEV_USER_USERNAME=devuser
export DIB_DEV_USER_PWDLESS_SUDO=1
export DIB_DEV_USER_AUTHORIZED_KEYS=$HOME/.ssh/id_rsa_for_dib.pub
export DIB_DEV_USER_PASSWORD=linux

echo "Installing base dependencies..."
sudo apt-get install -y -q=3 yum yum-utils rpm zypper kpartx python-pip debootstrap gnupg2

echo "Installing diskimage-builder"

sudo -H pip install -q -U diskimage-builder

echo "Removing old files..."
sudo rm -rf *.qcow2 *.sha256.txt

do_build() {
	local image=${1}-minimal
	local image_name=${1}
	echo "Building ${image}-${flavors[$image]}..."
	export DIB_RELEASE=${flavors[$image]}
	# Some defaults
	export DIB_YUM_MINIMAL_CREATE_INTERFACES=1 # centos dhcp setup
	disk-image-create --no-tmpfs -o ${image_name}.qcow2 ${elements} $image
	sha256sum ${image_name}.qcow2 > ${image_name}.sha256.txt
	echo "Done!"
}

if [[ -n ${one_distro} ]]; then
	do_build ${one_distro}
else
	for image in "${!flavors[@]}"; do
		image_name=${image/-minimal}
		do_build $image_name
	done
fi

exit 0
