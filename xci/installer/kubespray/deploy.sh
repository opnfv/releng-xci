#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2017 Huawei
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

K8_XCI_PLAYBOOKS="$(dirname $(realpath ${BASH_SOURCE[0]}))/playbooks"
export ANSIBLE_ROLES_PATH=$HOME/.ansible/roles:/etc/ansible/roles:${XCI_PATH}/xci/playbooks/roles


#-------------------------------------------------------------------------------
# Configure localhost
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci repository
# - clones kubernetes-incubator/kubespray repository
# - creates log directory
#-------------------------------------------------------------------------------

echo "Info: Configuring localhost for kubespray"
echo "-----------------------------------------------------------------------"
cd $XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" \
        -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory/inventory.cfg \
        configure-localhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured localhost for kubespray"

#-------------------------------------------------------------------------------
# Configure deployment host, opnfv
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - synchronize opnfv/releng-xci and kubernetes-incubator/kubespray repositories
# - generates/prepares ssh keys
# - copies flavor files to be used by kubespray
# - install packages required by kubespray
#-------------------------------------------------------------------------------
echo "Info: Configuring opnfv deployment host for kubespray"
echo "-----------------------------------------------------------------------"
cd $K8_XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" \
        -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory/inventory.cfg \
        configure-opnfvhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured opnfv deployment host for kubespray"

#-------------------------------------------------------------------------------
# Configure target hosts for kubespray
#-------------------------------------------------------------------------------
# This playbook is only run for the all flavors except aio since aio is configured by the configure-opnfvhost.yml
# This playbook
# - adds public keys to target hosts
# - install packages required by kubespray
# - configures haproxy service
#-------------------------------------------------------------------------------
if [ $XCI_FLAVOR != "aio" ]; then
    echo "Info: Configuring target hosts for kubespray"
    echo "-----------------------------------------------------------------------"
    cd $K8_XCI_PLAYBOOKS
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" \
            -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory/inventory.cfg \
            configure-targethosts.yml
    echo "-----------------------------------------------------------------------"
    echo "Info: Configured target hosts for kubespray"
fi

echo "Info: Using kubespray to deploy the kubernetes cluster"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "cd releng-xci/.cache/repos/kubespray;\
         ansible-playbook ${XCI_ANSIBLE_VERBOSITY} \
         -i opnfv_inventory/inventory.cfg cluster.yml -b | tee setup-kubernetes.log"
scp root@$OPNFV_HOST_IP:~/releng-xci/.cache/repos/kubespray/setup-kubernetes.log \
         $LOG_PATH/setup-kubernetes.log
# check the log to see if we have any error
if grep -q 'failed=1\|unreachable=1' $LOG_PATH/setup-kubernetes.log; then
    echo "Error: Kubernetes cluster setup failed!"
    exit 1
fi
echo "Info: Kubernetes installation is successfully completed!"
