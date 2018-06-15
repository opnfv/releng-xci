# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#-------------------------------------------------------------------------------
# Start provisioning VM nodes
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci and openstack/bifrost repositories
# - combines opnfv/releng-xci and openstack/bifrost scripts/playbooks
# - destroys VMs, removes ironic db, leases, logs
# - creates and provisions VMs for the chosen flavor
#-------------------------------------------------------------------------------

BIFROST_ROOT_DIR="$(dirname $(realpath ${BASH_SOURCE[0]}))"
export XCI_DISTRO=${XCI_DISTRO:-$(source /etc/os-release &>/dev/null || source /usr/lib/os-release &>/dev/null; echo ${ID,,})}

echo "Info: Create XCI VM resources"
echo "-------------------------------------------------------------------------"

cd ${XCI_PATH}/xci/playbooks/

ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        -i dynamic_inventory.py \
        -e num_nodes=${NUM_NODES} \
        -e vm_domain_type=${VM_DOMAIN_TYPE} \
        -e baremetal_json_file=/tmp/baremetal.json \
        -e xci_distro=${XCI_DISTRO} \
        -e xci_path=${XCI_PATH} \
        xci-create-vms.yaml

# Fetch the OPNFV_VM_IP from the libvirt network
OPNFV_VM_IP=$(sudo virsh net-dumpxml default | grep ip= |  cut -d"'" -f4)

echo "BANANA ${XCI_PATH}"

sudo chmod 600 ${XCI_PATH}/xci/scripts/vm/id_rsa_for_dib
echo "Dropping a minimal .ssh/config file"
cat > $HOME/.ssh/xci-vm-config<<EOF
Host *
StrictHostKeyChecking no
ServerAliveInterval 60
ServerAliveCountMax 5
IdentityFile ${XCI_PATH}/xci/scripts/vm/id_rsa_for_dib

Host xci_vm_opnfv
Hostname ${OPNFV_VM_IP}
User devuser
TCPKeepAlive yes
StrictHostKeyChecking no
EOF

# Remove the IP from known hosts if it exists
ssh-keygen -R ${OPNFV_VM_IP} || true

echo "Info: Starting provisining VM nodes using openstack/bifrost"
echo "-------------------------------------------------------------------------"

# baremetal.json is copied to be consumed by bifrost
scp -r -F $HOME/.ssh/xci-vm-config /tmp/baremetal.json xci_vm_opnfv:/tmp/baremetal.json

# keys are copied or bifrost will fail because there is no key in /etc/.ssh
scp -r -F $HOME/.ssh/xci-vm-config ${HOME}/.ssh/id_rsa xci_vm_opnfv:/home/devuser/.ssh/id_rsa
scp -r -F $HOME/.ssh/xci-vm-config ${HOME}/.ssh/id_rsa.pub xci_vm_opnfv:/home/devuser/.ssh/id_rsa.pub

# copy the public key to the authorized_keys
cat $HOME/.ssh/id_rsa.pub > authorized_keys
ssh -F $HOME/.ssh/xci-vm-config xci_vm_opnfv sudo mkdir /root/.ssh
scp -F $HOME/.ssh/xci-vm-config authorized_keys xci_vm_opnfv:/home/devuser/.ssh/authorized_keys

echo "authorized keys passed"
echo "scp ${HOME}/.ssh/known_hosts devuser@${OPNFV_VM_IP}:/home/devuser/.ssh/known_hosts"
sleep 30

# /root/.ssh/known_hosts must exist or we will get a "mkstemp: No such file or directory" when doing ssh-keygen -R in one of the bifrost roles
scp ${HOME}/.ssh/known_hosts devuser@${OPNFV_VM_IP}:/home/devuser/.ssh/known_hosts

# NOTE(hwoarang) We need a new shell to prevent the wildcard expansion on the current host.
ssh devuser@${OPNFV_VM_IP} "bash -c \"sudo cp /home/devuser/.ssh/* /root/.ssh/\""

ssh root@${OPNFV_VM_IP} mkdir /root/releng-xci

# All the important releng-xci is copied over (ansible remote copy module cannot do recursive)
rsync -az -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        --exclude .cache/repos/openstack-ansible-tests/ \
        --exclude venv/ \
        --exclude "*qcow2*" \
        --exclude xci/logs/ \
        ${XCI_PATH} \
        root@${OPNFV_VM_IP}:/root

# Fix up openSUSE DNS if needed
ssh root@${OPNFV_VM_IP} "mv -f /etc/resolv.conf.netconfig /etc/resolv.conf &>/dev/null || true"

ssh root@${OPNFV_VM_IP} "export BIFROST_USE_PREBUILT_IMAGES=$BIFROST_USE_PREBUILT_IMAGES; bash /root/releng-xci/.cache/repos/bifrost/scripts/bifrost-provision.sh"
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
