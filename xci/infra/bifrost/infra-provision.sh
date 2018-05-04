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
User root
TCPKeepAlive yes
StrictHostKeyChecking no
EOF

echo "Info: Starting provisining VM nodes using openstack/bifrost"
echo "-------------------------------------------------------------------------"
cd $BIFROST_ROOT_DIR/playbooks/
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i /home/opnfv/releng-xci/xci/playbooks/dynamic_inventory.py bootstrap-bifrost.yml
cd ${XCI_CACHE}/repos/bifrost
bash ./scripts/bifrost-provision.sh
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
