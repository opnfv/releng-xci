#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2017 Huawei
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -o errexit
set -o nounset
set -o pipefail

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
ansible-playbook ${XCI_ANSIBLE_PARAMS} -e XCI_PATH="${XCI_PATH}" \
        -i dynamic_inventory.py configure-localhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured localhost for kubespray"

#-------------------------------------------------------------------------------
# Configure installer
#-------------------------------------------------------------------------------
# TODO: summarize what this playbook does
#-------------------------------------------------------------------------------

echo "Info: Configuring kubespray installer"
echo "-----------------------------------------------------------------------"
cd $K8_XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        -i ${XCI_PLAYBOOKS}/dynamic_inventory.py configure-installer.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured kubespray installer"

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
ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        -i ${XCI_PLAYBOOKS}/dynamic_inventory.py configure-opnfvhost.yml
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
    ansible-playbook ${XCI_ANSIBLE_PARAMS} \
            -i ${XCI_PLAYBOOKS}/dynamic_inventory.py configure-targethosts.yml
    echo "-----------------------------------------------------------------------"
    echo "Info: Configured target hosts for kubespray"
fi


echo "Info: Using kubespray to deploy the kubernetes cluster"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "set -o pipefail; export XCI_FLAVOR=$XCI_FLAVOR; export INSTALLER_TYPE=$INSTALLER_TYPE; \
        export IDF=/root/releng-xci/xci/var/idf.yml; export PDF=/root/releng-xci/xci/var/pdf.yml; \
        cd releng-xci/.cache/repos/kubespray/; ansible-playbook \
        -i inventory/opnfv/dynamic_inventory.py cluster.yml -b | tee setup-kubernetes.log"
scp root@$OPNFV_HOST_IP:~/releng-xci/.cache/repos/kubespray/setup-kubernetes.log \
        $LOG_PATH/setup-kubernetes.log


cd $K8_XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_PARAMS} \
    -i ${XCI_PLAYBOOKS}/dynamic_inventory.py configure-kubenet.yml
echo
echo "-----------------------------------------------------------------------"
echo "Info: Kubernetes installation is successfully completed!"
echo "-----------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Execute post-installation tasks
#-------------------------------------------------------------------------------
# Playbook post.yml is used in order to execute any post-deployment tasks that
# are required for the scenario under test.
#-------------------------------------------------------------------------------
# copy admin.conf
ssh root@$OPNFV_HOST_IP "mkdir -p ~/.kube/; \
    cp -f ~/admin.conf ~/.kube/config"
echo "-----------------------------------------------------------------------"
echo "Info: Running post-deployment scenario role"
echo "-----------------------------------------------------------------------"
cd $K8_XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i ${XCI_PLAYBOOKS}/dynamic_inventory.py \
    post-deployment.yml
echo "-----------------------------------------------------------------------"
echo "Info: Post-deployment scenario role execution done"
echo "-----------------------------------------------------------------------"
echo
echo "Login opnfv host ssh root@$OPNFV_HOST_IP
according to the user-guide to create a service
https://kubernetes.io/docs/user-guide/walkthrough/k8s201/"
echo
echo "-----------------------------------------------------------------------"
echo "Info: Kubernetes login details"
echo "-----------------------------------------------------------------------"
echo
# Get the dashboard URL
if ssh-keygen -f "/home/opnfv/.ssh/known_hosts" -F $OPNFV_HOST_IP;
then
ssh-keygen -f "/home/opnfv/.ssh/known_hosts" -R  $OPNFV_HOST_IP;
echo "known_hosts entry from opnfv host from previous deployment found and deleted"
fi
DASHBOARD_SERVICE=$(ssh -q -o StrictHostKeyChecking=no root@$OPNFV_HOST_IP "kubectl get service -n kube-system |grep kubernetes-dashboard")
DASHBOARD_PORT=$(echo ${DASHBOARD_SERVICE} | awk '{print $5}' |awk -F "[:/]" '{print $2}')
KUBER_SERVER_URL=$(ssh root@$OPNFV_HOST_IP "grep -r server ~/.kube/config")
echo "Info: Kubernetes Dashboard URL:"
echo $KUBER_SERVER_URL | awk '{print $2}'| sed -n "s#:[0-9]*\$#:$DASHBOARD_PORT#p"

# Get the dashboard user and password
MASTER_IP=$(echo ${KUBER_SERVER_URL} | awk '{print $2}' |awk -F "[:/]" '{print $4}')
if ssh-keygen -f "/home/opnfv/.ssh/known_hosts" -F $MASTER_IP;
then
ssh-keygen -f "/home/opnfv/.ssh/known_hosts" -R  $MASTER_IP;
echo "Info: known_hosts entry for master host from previous deployment found and deleted"
fi
USER_CSV=$(ssh -q -o StrictHostKeyChecking=no root@$MASTER_IP " cat /etc/kubernetes/users/known_users.csv")
USERNAME=$(echo $USER_CSV |awk -F ',' '{print $2}')
PASSWORD=$(echo $USER_CSV |awk -F ',' '{print $1}')
echo "Info: Dashboard username: ${USERNAME}"
echo "Info: Dashboard password: ${PASSWORD}"

# vim: set ts=4 sw=4 expandtab:
