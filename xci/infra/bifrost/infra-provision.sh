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

cd /home/opnfv/releng-xci/prototypes/playbooks/

ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        -i "localhost," \
        -e num_nodes=${NUM_NODES} \
        -e vm_domain_type=${VM_DOMAIN_TYPE} \
        -e baremetal_json_file=/tmp/baremetal.json \
        -e xci_distro=${XCI_DISTRO} \
        xci-create-vms.yaml

echo "SLEEPING..."
sleep 10

sudo chmod 600 /home/opnfv/releng-xci/xci/scripts/vm/id_rsa_for_dib
echo "Dropping a minimal .ssh/config file"
cat > $HOME/.ssh/xci-vm-config<<EOF
Host *
StrictHostKeyChecking no
ServerAliveInterval 60
ServerAliveCountMax 5
IdentityFile /home/opnfv/releng-xci/xci/scripts/vm/id_rsa_for_dib

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
        --exclude "*qcow2*" \
        /home/opnfv/releng-xci/ \
        devuser@192.168.122.2:/home/devuser/releng-xci

# baremetal.json is copied to be consumed by bifrost
scp -r -F $HOME/.ssh/xci-vm-config /tmp/baremetal.json xci_vm_opnfv:/tmp/baremetal.json

# keys are copied or bifrost will fail because there is no key in /etc/.ssh
scp -r -F $HOME/.ssh/xci-vm-config ~/releng-xci/xci/scripts/vm/id_rsa_for_dib xci_vm_opnfv:/home/devuser/.ssh/id_rsa
scp -r -F $HOME/.ssh/xci-vm-config ~/releng-xci/xci/scripts/vm/id_rsa_for_dib.pub xci_vm_opnfv:/home/devuser/.ssh/id_rsa.pub

# /root/.ssh/known_hosts must exist or we will get a "mkstemp: No such file or directory" when doing ssh-keygen -R in one of the bifrost roles
scp -F $HOME/.ssh/xci-vm-config /home/opnfv/.ssh/known_hosts xci_vm_opnfv:/home/devuser/.ssh/known_hosts
ssh -F $HOME/.ssh/xci-vm-config sudo mkdir /root/.ssh
ssh -F $HOME/.ssh/xci-vm-config sudo cp /home/devuser/.ssh/known_hosts /root/.ssh/known_hosts

# xci-opnfv-vm.sh is executed
ssh -F $HOME/.ssh/xci-vm-config xci_vm_opnfv bash /home/devuser/releng-xci/.cache/repos/bifrost/scripts/xci-opnfv-vm.sh
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
