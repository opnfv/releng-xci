#!/bin/bash

set -eu

curl https://raw.githubusercontent.com/openstack/bifrost/master/scripts/install-deps.sh | bash

source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    *suse)
		OS_FAMILY="Suse"
		sudo zypper -n ref
		;;

	ubuntu|debian)
	    OS_FAMILY="Debian"
		export DEBIAN_FRONTEND=noninteractive
		sudo apt-get update
		;;

    rhel|fedora|centos)
		OS_FAMILY="RedHat"
		sudo yum update --assumeno
		;;

    *) echo "ERROR: Supported package manager not found.  Supported: apt, dnf, yum, zypper"; exit 1;;
esac

PIP=$(which pip)
${PIP} install --user --upgrade ansible==$XCI_ANSIBLE_PIP_VERSION
