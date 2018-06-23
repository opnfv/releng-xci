#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2017 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

OSA_XCI_PLAYBOOKS="$(dirname $(realpath ${BASH_SOURCE[0]}))/playbooks"
export ANSIBLE_ROLES_PATH=$HOME/.ansible/roles:/etc/ansible/roles:${XCI_PATH}/xci/playbooks/roles

if [[ ${OPENSTACK_OSA_VERSION} =~ (stable/|master) ]]; then
    echo ""
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "WARNING: We have detected that you are trying to OpenStack-Ansible from stable or master branch."
    echo "This will likely not work because, unless you know what you are doing, you are going"
    echo "to be trying something that has not been verified by XCI or upstream fully."
    echo "This is _NOT_ supported in any way but we can try to make it work for you."
    echo "Either way you are on your own so please do not report bugs as they will be considered invalid."
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo ""
    sleep 15
    trap - ERR
    ${XCI_PATH}/xci/scripts/update-osa-version-files.sh ${OPENSTACK_OSA_VERSION}
fi

#-------------------------------------------------------------------------------
# Configure localhost
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci repository
# - creates log directory
# - copies flavor files such as playbook, inventory, and var file
#-------------------------------------------------------------------------------

echo "Info: Configuring localhost for openstack-ansible"
echo "-----------------------------------------------------------------------"
cd $XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i "localhost," configure-localhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured localhost host for openstack-ansible"

#-------------------------------------------------------------------------------
# Configure openstack-ansible deployment host, opnfv
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci and openstack/openstack-ansible repositories
# - configures network
# - generates/prepares ssh keys
# - bootstraps ansible
# - copies flavor files to be used by openstack-ansible
#-------------------------------------------------------------------------------
echo "Info: Configuring opnfv deployment host for openstack-ansible"
echo "-----------------------------------------------------------------------"
cd $OSA_XCI_PLAYBOOKS
ansible-galaxy install -r ${XCI_PATH}/xci/files/requirements.yml -p $HOME/.ansible/roles
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i ${XCI_PLAYBOOKS}/dynamic_inventory.py \
    configure-opnfvhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured opnfv deployment host for openstack-ansible"

#-------------------------------------------------------------------------------
# Configure target hosts for openstack-ansible
#-------------------------------------------------------------------------------
# This playbook is only run for the all flavors except aio since aio is configured
# by an upstream script.
# This playbook
# - adds public keys to target hosts
# - configures network
# - configures nfs
#-------------------------------------------------------------------------------
if [[ $XCI_FLAVOR != "aio" ]]; then
    echo "Info: Configuring target hosts for openstack-ansible"
    echo "-----------------------------------------------------------------------"
    cd $OSA_XCI_PLAYBOOKS
    ansible-playbook ${XCI_ANSIBLE_PARAMS} -i ${XCI_PLAYBOOKS}/dynamic_inventory.py \
        configure-targethosts.yml
    echo "-----------------------------------------------------------------------"
    echo "Info: Configured target hosts"
fi

#-------------------------------------------------------------------------------
# Set up target hosts for openstack-ansible
#-------------------------------------------------------------------------------
# This is openstack-ansible playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Setting up target hosts for openstack-ansible"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "set -o pipefail; openstack-ansible \
     releng-xci/.cache/repos/openstack-ansible/playbooks/setup-hosts.yml | tee setup-hosts.log "
scp root@$OPNFV_HOST_IP:~/setup-hosts.log $LOG_PATH/setup-hosts.log
echo "-----------------------------------------------------------------------"
echo "Info: Set up target hosts for openstack-ansible successfuly"

# TODO: Check this with the upstream and issue a fix in the documentation if the
# problem is valid.
#-------------------------------------------------------------------------------
# Gather facts for all the hosts and containers
#-------------------------------------------------------------------------------
# This is needed in order to gather the facts for containers due to a change in
# upstream that changed the hosts fact are gathered which causes failures during
# running setup-infrastructure.yml playbook due to lack of the facts for lxc
# containers.
#
# OSA gate also executes this command. See the link
# http://logs.openstack.org/64/494664/1/check/gate-openstack-ansible-openstack-ansible-aio-ubuntu-xenial/2a0700e/console.html
#-------------------------------------------------------------------------------
echo "Info: Gathering facts"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "set -o pipefail; cd releng-xci/.cache/repos/openstack-ansible/playbooks; \
        ansible -m setup -a gather_subset=network,hardware,virtual all"
echo "-----------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Set up infrastructure
#-------------------------------------------------------------------------------
# This is openstack-ansible playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Setting up infrastructure"
echo "-----------------------------------------------------------------------"
echo "xci: running ansible playbook setup-infrastructure.yml"
ssh root@$OPNFV_HOST_IP "set -o pipefail; openstack-ansible \
     releng-xci/.cache/repos/openstack-ansible/playbooks/setup-infrastructure.yml | tee setup-infrastructure.log"
scp root@$OPNFV_HOST_IP:~/setup-infrastructure.log $LOG_PATH/setup-infrastructure.log
echo "-----------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Verify database cluster
#-------------------------------------------------------------------------------
echo "Info: Verifying database cluster"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "set -o pipefail; ansible --ssh-extra-args='-o StrictHostKeyChecking=no' \
    -i releng-xci/.cache/repos/openstack-ansible/playbooks/inventory/ galera_container -m shell \
	-a \"mysql -h localhost -e \\\"show status like '%wsrep_cluster_%';\\\"\" | tee galera.log"
scp root@$OPNFV_HOST_IP:~/galera.log $LOG_PATH/galera.log
echo "-----------------------------------------------------------------------"
# check the log to see if we have any error
if grep -q 'FAILED\|UNREACHABLE' $LOG_PATH/galera.log; then
    echo "Error: Database cluster verification failed!"
    exit 1
fi
echo "Info: Database cluster verification successful!"

#-------------------------------------------------------------------------------
# Install OpenStack
#-------------------------------------------------------------------------------
# This is openstack-ansible playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Installing OpenStack on target hosts"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "set -o pipefail; openstack-ansible \
     releng-xci/.cache/repos/openstack-ansible/playbooks/setup-openstack.yml | tee opnfv-setup-openstack.log"
scp root@$OPNFV_HOST_IP:~/opnfv-setup-openstack.log $LOG_PATH/opnfv-setup-openstack.log
echo "-----------------------------------------------------------------------"
echo
echo "Info: OpenStack installation is successfully completed!"

#-------------------------------------------------------------------------------
# - Getting OpenStack login information
#-------------------------------------------------------------------------------
echo "Info: Openstack login details"
echo "-----------------------------------------------------------------------"
OS_USER_CONFIG=$XCI_FLAVOR_ANSIBLE_FILE_PATH/openstack_user_config.yml
python -c \
"import yaml
if '$XCI_FLAVOR' is 'aio':
   print 'Horizon UI is available at https://$OPNFV_HOST_IP'
else:
   host_info = open('$OS_USER_CONFIG', 'r')
   net_config = yaml.safe_load(host_info)
   print 'Info: Horizon UI is available at https://{}' \
         .format(net_config['global_overrides']['external_lb_vip_address'])"
USERNAME=$(ssh -q root@$OPNFV_HOST_IP awk "/OS_USERNAME=./" openrc)
PASSWORD=$(ssh -q root@$OPNFV_HOST_IP awk "/OS_PASSWORD=./" openrc)
echo "Info: Admin username -  ${USERNAME##*=}"
echo "Info: Admin password - ${PASSWORD##*=}"
echo "Info: It is recommended to change the default password."

#-------------------------------------------------------------------------------
# Execute post-installation tasks
#-------------------------------------------------------------------------------
# Playbook post.yml is used in order to execute any post-deployment tasks that
# are required for the scenario under test.
#-------------------------------------------------------------------------------
echo "-----------------------------------------------------------------------"
echo "Info: Running post-deployment scenario role"
echo "-----------------------------------------------------------------------"
cd $OSA_XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i ${XCI_PLAYBOOKS}/dynamic_inventory.py \
    scenario-post-deploy.yml
echo "-----------------------------------------------------------------------"
echo
echo "Info: Post-deployment scenario role execution done"
# vim: set ts=4 sw=4 expandtab:
