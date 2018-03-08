#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 Intel Corporation
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

KOLLA_XCI_PLAYBOOKS="$(dirname $(realpath ${BASH_SOURCE[0]}))/playbooks"
export ANSIBLE_ROLES_PATH=$HOME/.ansible/roles:/etc/ansible/roles:${XCI_PATH}/xci/playbooks/roles

if [[ ${OPENSTACK_KOLLA_VERSION} =~ (stable/|master) ]]; then
    echo ""
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "WARNING: We have detected that you are trying to Kolla from stable or master branch."
    echo "This will likely not work because, unless you know what you are doing, you are going"
    echo "to be trying something that has not been verified by XCI or upstream fully."
    echo "This is _NOT_ supported in any way but we can try to make it work for you."
    echo "Either way you are on your own so please do not report bugs as they will be considered invalid."
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo ""
    sleep 15
    trap - ERR
fi

#-------------------------------------------------------------------------------
# Configure localhost
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci repository
# - creates log directory
# - generates/prepares ssh keys
#-------------------------------------------------------------------------------

echo "Info: Configuring localhost for kolla"
echo "-----------------------------------------------------------------------"
cd $XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" -i inventory configure-localhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured localhost host for kolla"

#-------------------------------------------------------------------------------
# Configure kolla deployment host, opnfv
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - configures network
#-------------------------------------------------------------------------------
echo "Info: Configuring opnfv deployment host for kolla"
echo "-----------------------------------------------------------------------"
cd $KOLLA_XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory \
    configure-opnfvhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured opnfv deployment host for kolla"

#-------------------------------------------------------------------------------
# Configure target hosts for kolla
#-------------------------------------------------------------------------------
# This playbook is only run for the all flavors except aio since aio is configured
# by an upstream script.

# This playbook
# - adds public keys to target hosts
# - configures network
# - configures nfs
#-------------------------------------------------------------------------------
if [[ $XCI_FLAVOR != "aio" ]]; then
    echo "Info: Configuring target hosts for kolla"
    echo "-----------------------------------------------------------------------"
    cd $KOLLA_XCI_PLAYBOOKS
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory \
        configure-targethosts.yml
    echo "-----------------------------------------------------------------------"
    echo "Info: Configured target hosts"
fi

#-------------------------------------------------------------------------------
# Install OpenStack
#-------------------------------------------------------------------------------
# This is kolla playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Installing OpenStack on target hosts"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "set -o pipefail; kolla-ansible ${XCI_ANSIBLE_VERBOSITY} \
     deploy -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory | tee opnfv-setup-openstack.log"
scp root@$OPNFV_HOST_IP:~/opnfv-setup-openstack.log $LOG_PATH/opnfv-setup-openstack.log
echo "-----------------------------------------------------------------------"
# check the log to see if we have any error
if grep -q 'failed=1\|unreachable=1' $LOG_PATH/opnfv-setup-openstack.log; then
   echo "Error: OpenStack installation failed!"
   exit 1
fi
echo "Info: OpenStack installation is successfully completed!"

#-------------------------------------------------------------------------------
# - Getting OpenStack login information
#-------------------------------------------------------------------------------
echo "Info: Openstack login details"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "set -o pipefail; kolla-ansible post-deploy"
USERNAME=$(ssh -q root@$OPNFV_HOST_IP awk "/OS_USERNAME=./" ${OPENSTACK_KOLLA_ETC_PATH}/admin-openrc.sh)
PASSWORD=$(ssh -q root@$OPNFV_HOST_IP awk "/OS_PASSWORD=./" ${OPENSTACK_KOLLA_ETC_PATH}/admin-openrc.sh)
echo "Info: Admin username -  ${USERNAME##*=}"
echo "Info: Admin password - ${PASSWORD##*=}"
echo "Info: It is recommended to change the default password."
