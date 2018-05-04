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

cd ${XCI_PATH}/prototypes/playbooks/

ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        -i "localhost," \
        -e num_nodes=${NUM_NODES} \
        -e vm_domain_type=${VM_DOMAIN_TYPE} \
        -e baremetal_json_file=/tmp/baremetal.json \
        -e xci_distro=${XCI_DISTRO} \
        xci-create-vms.yaml

echo "SLEEPING..."
sleep 10

sudo chmod 600 ${XCI_PATH}/xci/scripts/vm/id_rsa_for_dib
echo "Dropping a minimal .ssh/config file"
cat > $HOME/.ssh/xci-vm-config<<EOF
Host *
StrictHostKeyChecking no
ServerAliveInterval 60
ServerAliveCountMax 5
IdentityFile ${XCI_PATH}/xci/scripts/vm/id_rsa_for_dib

Host xci_vm_opnfv
Hostname 192.168.122.2
User devuser
TCPKeepAlive yes
StrictHostKeyChecking no
EOF

echo "Info: Starting provisining VM nodes using openstack/bifrost"
echo "-------------------------------------------------------------------------"
cd $BIFROST_ROOT_DIR/playbooks/
ansible-playbook ${XCI_ANSIBLE_PARAMS} bootstrap-bifrost.yml
ssh -F $HOME/.ssh/xci-vm-config xci_vm_opnfv mkdir /home/devuser/releng-xci

# All the important releng-xci is copied over (ansible remote copy module cannot do recursive)
rsync -ravz -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -F $HOME/.ssh/xci-vm-config" \
        --exclude .cache/repos/openstack-ansible-tests/ \
        --exclude venv/ \
        --exclude xci/logs/ \
        --exclude "*qcow2*" \
        ${XCI_PATH} \
        devuser@192.168.122.2:/home/devuser

# baremetal.json is copied to be consumed by bifrost
scp -r -F $HOME/.ssh/xci-vm-config /tmp/baremetal.json xci_vm_opnfv:/tmp/baremetal.json

# keys are copied or bifrost will fail because there is no key in /etc/.ssh
scp -r -F $HOME/.ssh/xci-vm-config ${HOME}/.ssh/id_rsa xci_vm_opnfv:/home/devuser/.ssh/id_rsa
scp -r -F $HOME/.ssh/xci-vm-config ${HOME}/.ssh/id_rsa.pub xci_vm_opnfv:/home/devuser/.ssh/id_rsa.pub

# /root/.ssh/known_hosts must exist or we will get a "mkstemp: No such file or directory" when doing ssh-keygen -R in one of the bifrost roles
scp -F $HOME/.ssh/xci-vm-config ${HOME}/.ssh/known_hosts xci_vm_opnfv:/home/devuser/.ssh/known_hosts
ssh -F $HOME/.ssh/xci-vm-config xci_vm_opnfv sudo mkdir /root/.ssh
ssh -F $HOME/.ssh/xci-vm-config xci_vm_opnfv sudo cp /home/devuser/.ssh/known_hosts /root/.ssh/known_hosts

# copy the public key to the authorized_keys
cat $HOME/.ssh/id_rsa.pub > authorized_keys
scp -F $HOME/.ssh/xci-vm-config authorized_keys xci_vm_opnfv:/home/devuser/.ssh/authorized_keys

# As they key is already there, we don't need xci_vm_opnfv anymore
ssh devuser@192.168.122.2 sudo cp /home/devuser/.ssh/authorized_keys /root/.ssh/authorized_keys

# xci-opnfv-vm.sh is executed
ssh devuser@192.168.122.2 bash /home/devuser/releng-xci/.cache/repos/bifrost/scripts/xci-opnfv-vm.sh
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
