#!/bin/bash

# TODO: destroy previous k8s environment
echo "Info: Configuring opnfvhost for kubespray"
echo "-----------------------------------------------------------------------"
if [ $XCI_FLAVOR == "ha" ]; then
    echo "this script still not support k8s ha"
    exit 1
fi

cd $XCI_PATH/kubespray
export ANSIBLE_ROLES_PATH=$XCI_PATH/playbooks/roles
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i ../playbooks/inventory configure-localhost.yml
    cd $OPNFV_RELENG_PATH/xci/kubespray
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i ../playbooks/inventory configure-opnfvhost.yml

if [ $XCI_FLAVOR != "aio" ]; then
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i ../playbooks/inventory configure-targethosts.yml
fi

echo "-----------------------------------------------------------------------"
# for k8s 1.8, swap needs to be disabled for kubelet to run
ssh root@$OPNFV_HOST_IP "/sbin/swapoff -a"
ssh root@$OPNFV_HOST_IP "cd ${KUBESPRAY_PATH};\
         ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i opnfv_inventory/inventory/inventory.cfg cluster.yml -b"
