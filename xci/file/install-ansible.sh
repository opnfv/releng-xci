#!/bin/bash

set -eu

source /etc/os-release || source /usr/lib/os-release
case ${ID,,} in
    *suse)
		OS_FAMILY="Suse"
		sudo zypper -n ref
		sudo -H -E zypper install -y curl
		;;

	ubuntu|debian)
	    OS_FAMILY="Debian"
		export DEBIAN_FRONTEND=noninteractive
		sudo apt-get update
		sudo apt-get install -y curl
		;;

    rhel|fedora|centos)
		OS_FAMILY="RedHat"
		sudo yum update --assumeno
		sudo yum install -y curl
		;;

    *) echo "ERROR: Supported package manager not found.  Supported: apt, dnf, yum, zypper"; exit 1;;
esac

# FIXME (hwoarang): This is also being executed by bifrost so perhaps we can rework things so we don't execute
# it twice
curl https://raw.githubusercontent.com/openstack/bifrost/$OPENSTACK_BIFROST_VERSION/scripts/install-deps.sh | bash

PIP=$(which pip)
${PIP} install --user --upgrade ansible==$XCI_ANSIBLE_PIP_VERSION
