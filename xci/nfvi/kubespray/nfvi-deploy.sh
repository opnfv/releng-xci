#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2017 Huawei
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

echo "Info: Configuring opnfvhost for kubespray"
echo "-----------------------------------------------------------------------"

cd ${XCI_PATH}/xci/nfvi/${XCI_NFVI}/playbooks
export ANSIBLE_ROLES_PATH=$XCI_PATH/xci/playbooks/roles
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory/inventory.cfg configure-localhost.yml
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory/inventory.cfg configure-opnfvhost.yml
if [ $XCI_FLAVOR != "aio" ]; then
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -e XCI_PATH="${XCI_PATH}" -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory/inventory.cfg configure-targethosts.yml
fi

echo "-----------------------------------------------------------------------"
# for k8s 1.8, swap needs to be disabled for kubelet to run
ssh root@$OPNFV_HOST_IP "/sbin/swapoff -a"
ssh root@$OPNFV_HOST_IP "cd releng-xci/.cache/repos/kubespray;\
         ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i opnfv_inventory/inventory.cfg cluster.yml -b"
