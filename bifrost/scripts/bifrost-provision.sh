#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2016 Ericsson AB and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -eu
set -o pipefail

export PYTHONUNBUFFERED=1
SCRIPT_HOME="$(cd "$(dirname "$0")" && pwd)"
BIFROST_HOME=$SCRIPT_HOME/..
ANSIBLE_INSTALL_ROOT=${ANSIBLE_INSTALL_ROOT:-/opt/stack}
ENABLE_VENV="false"
USE_DHCP="false"
USE_VENV="true"
BUILD_IMAGE=true
PROVISION_WAIT_TIMEOUT=${PROVISION_WAIT_TIMEOUT:-3600}
# This is normally exported by XCI env but we should initialize it here
# in case we run this script on its own for debug purposes
XCI_ANSIBLE_VERBOSITY=${XCI_ANSIBLE_VERBOSITY:-}
# Ironic SHAs
BIFROST_IRONIC_INSPECTOR_VERSION=${BIFROST_IRONIC_INSPECTOR_VERSION:-master}
BIFROST_IRONIC_INSPECTOR_CLIENT_VERSION=${BIFROST_IRONIC_INSPECTOR_CLIENT_VERSION:-master}
BIFROST_IRONIC_CLIENT_VERSION=${BIFROST_IRONIC_CLIENT_VERSION:-master}
BIFROST_IRONIC_VERSION=${BIFROST_IRONIC_VERSION:-master}

# set UPPER_CONSTRAINTS_FILE since it is needed in order to limit libvirt-python to 4.0.0
export UPPER_CONSTRAINTS_FILE=https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt

# Ensure the right inventory files is used based on branch
CURRENT_BIFROST_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ $CURRENT_BIFROST_BRANCH = "master" ]; then
    BAREMETAL_DATA_FILE=${BAREMETAL_DATA_FILE:-'/tmp/baremetal.json'}
    INVENTORY_FILE_FORMAT="baremetal_json_file"
else
    BAREMETAL_DATA_FILE=${BAREMETAL_DATA_FILE:-'/tmp/baremetal.csv'}
    INVENTORY_FILE_FORMAT="baremetal_csv_file"
fi
export BIFROST_INVENTORY_SOURCE=$BAREMETAL_DATA_FILE

# Default settings for VMs
export TEST_VM_NUM_NODES=${TEST_VM_NUM_NODES:-3}
export TEST_VM_NODE_NAMES=${TEST_VM_NODE_NAMES:-"opnfv controller00 compute00"}
export VM_DOMAIN_TYPE=${VM_DOMAIN_TYPE:-kvm}
export VM_CPU=${VM_CPU:-4}
export VM_DISK=${VM_DISK:-100}
export VM_MEMORY_SIZE=${VM_MEMORY_SIZE:-8192}
export VM_DISK_CACHE=${VM_DISK_CACHE:-unsafe}

# Settings for bifrost
TEST_PLAYBOOK="opnfv-virtual.yaml"
USE_INSPECTOR=true
USE_CIRROS=false
TESTING_USER=root
DOWNLOAD_IPA=true
CREATE_IPA_IMAGE=false
INSPECT_NODES=true
INVENTORY_DHCP=false
INVENTORY_DHCP_STATIC_IP=false
WRITE_INTERFACES_FILE=true

# Settings for console access
export DIB_DEV_USER_PWDLESS_SUDO=yes
export DIB_DEV_USER_PASSWORD=devuser

# Settings for distro: xenial/ubuntu-minimal, 7/centos7, 42.2/suse
export DIB_OS_RELEASE=${DIB_OS_RELEASE:-xenial}
export DIB_OS_ELEMENT=${DIB_OS_ELEMENT:-ubuntu-minimal}

# DIB OS packages
export DIB_OS_PACKAGES=${DIB_OS_PACKAGES:-"vlan,vim,less,bridge-utils,language-pack-en,iputils-ping,rsyslog,curl"}

# Additional dib elements
export EXTRA_DIB_ELEMENTS=${EXTRA_DIB_ELEMENTS:-"openssh-server"}

# dib configuration
case ${XCI_DISTRO,,} in
    # These should ideally match the CI jobs
    ubuntu)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-xenial}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-ubuntu-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vlan,vim,less,bridge-utils,language-pack-en,iputils-ping,rsyslog,curl,iptables}"
        ;;
    centos)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-7}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-centos-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        ;;
    opensuse)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-42.3}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-opensuse-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        ;;
esac

# Copy the OS images if found
if [[ -e ${XCI_PATH}/deployment_image.qcow2 ]]; then
	sudo mkdir -p /httpboot
	sudo mv ${XCI_PATH}/deployment_image.qcow2* /httpboot/
fi

if [ ${USE_VENV} = "true" ]; then
    export VENV=/opt/stack/bifrost
    $SCRIPT_HOME/env-setup.sh &>/dev/null
    # Note(cinerama): activate is not compatible with "set -u";
    # disable it just for this line.
    set +u
    source ${VENV}/bin/activate
    set -u
    ANSIBLE=${VENV}/bin/ansible-playbook
    ENABLE_VENV="true"
else
    $SCRIPT_HOME/env-setup.sh &>/dev/null
    ANSIBLE=${HOME}/.local/bin/ansible-playbook
fi

# Change working directory
cd $BIFROST_HOME/playbooks

# NOTE(hwoarang): Disable selinux as we are hitting issues with it from time to
# time. Remove this when Centos7 is a proper gate on bifrost so we know that
# selinux works as expected.
if [[ -e /etc/centos-release ]]; then
    echo "*************************************"
    echo "WARNING: Disabling selinux on CentOS7"
    echo "*************************************"
    sudo setenforce 0
fi

# Create the VMS
${ANSIBLE} ${XCI_ANSIBLE_VERBOSITY} \
       -i inventory/localhost \
       test-bifrost-create-vm.yaml \
       -e test_vm_num_nodes=${TEST_VM_NUM_NODES} \
       -e test_vm_cpu='host-model' \
       -e test_vm_memory_size=${VM_MEMORY_SIZE} \
       -e enable_venv=${ENABLE_VENV} \
       -e test_vm_domain_type=${VM_DOMAIN_TYPE} \
       -e ${INVENTORY_FILE_FORMAT}=${BAREMETAL_DATA_FILE}

# Execute the installation and VM startup test
${ANSIBLE} ${XCI_ANSIBLE_VERBOSITY} \
    -i inventory/bifrost_inventory.py \
    ${TEST_PLAYBOOK} \
    -e use_cirros=${USE_CIRROS} \
    -e testing_user=${TESTING_USER} \
    -e test_vm_num_nodes=${TEST_VM_NUM_NODES} \
    -e test_vm_cpu='host-model' \
    -e inventory_dhcp=${INVENTORY_DHCP} \
    -e inventory_dhcp_static_ip=${INVENTORY_DHCP_STATIC_IP} \
    -e enable_venv=${ENABLE_VENV} \
    -e enable_inspector=${USE_INSPECTOR} \
    -e inspect_nodes=${INSPECT_NODES} \
    -e download_ipa=${DOWNLOAD_IPA} \
    -e create_ipa_image=${CREATE_IPA_IMAGE} \
    -e write_interfaces_file=${WRITE_INTERFACES_FILE} \
    -e ipv4_gateway=192.168.122.1 \
    -e wait_timeout=${PROVISION_WAIT_TIMEOUT} \
    -e enable_keystone=false \
    -e ironicinspector_source_install=true \
    -e ironicinspector_git_branch=${BIFROST_IRONIC_INSPECTOR_VERSION} \
    -e ironicinspectorclient_source_install=true \
    -e ironicinspectorclient_git_branch=${BIFROST_IRONIC_INSPECTOR_CLIENT_VERSION} \
    -e ironicclient_source_install=true \
    -e ironicclient_git_branch=${BIFROST_IRONIC_CLIENT_VERSION} \
    -e ironic_git_branch=${BIFROST_IRONIC_VERSION} \
    -e use_prebuilt_images=${BIFROST_USE_PREBUILT_IMAGES} \
    -e xci_distro=${XCI_DISTRO}
EXITCODE=$?

if [ $EXITCODE != 0 ]; then
    echo "************************************"
    echo "Provisioning failed. See logs folder"
    echo "************************************"
fi

exit $EXITCODE
