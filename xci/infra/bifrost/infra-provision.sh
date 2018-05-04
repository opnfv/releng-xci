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

function test_ssh_connectivity() {

until nc -zv ${OPNFV_VM_IP} 22;
do
  echo "VM not ready, retrying..."
  sleep 3
done

}

BIFROST_ROOT_DIR="$(dirname $(realpath ${BASH_SOURCE[0]}))"
# Fetch the OPNFV_VM from the libvirt network
OPNFV_VM_IP=$(sudo virsh net-dumpxml default | grep ip= |  cut -d"'" -f4)
export XCI_DISTRO=${XCI_DISTRO:-$(source /etc/os-release &>/dev/null || source /usr/lib/os-release &>/dev/null; echo ${ID,,})}

cd ${XCI_PATH}/prototypes/playbooks/

ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        -i "localhost," \
        -e num_nodes=${NUM_NODES} \
        -e vm_domain_type=${VM_DOMAIN_TYPE} \
        -e baremetal_json_file=/tmp/baremetal.json \
        -e xci_distro=${XCI_DISTRO} \
        xci-create-vms.yaml

# Don't continue until opnfv VM is ready
test_ssh_connectivity

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


echo "Info: Starting provisining VM nodes using openstack/bifrost"
echo "-------------------------------------------------------------------------"
cd $BIFROST_ROOT_DIR/playbooks/
ansible-playbook ${XCI_ANSIBLE_PARAMS} bootstrap-bifrost.yml

# Remove the IP from known hosts
ssh-keygen -R ${OPNFV_VM_IP}

# baremetal.json is copied to be consumed by bifrost
scp -r -F $HOME/.ssh/xci-vm-config /tmp/baremetal.json xci_vm_opnfv:/tmp/baremetal.json

# keys are copied or bifrost will fail because there is no key in /etc/.ssh
scp -r -F $HOME/.ssh/xci-vm-config ${HOME}/.ssh/id_rsa xci_vm_opnfv:/home/devuser/.ssh/id_rsa
scp -r -F $HOME/.ssh/xci-vm-config ${HOME}/.ssh/id_rsa.pub xci_vm_opnfv:/home/devuser/.ssh/id_rsa.pub

# copy the public key to the authorized_keys
cat $HOME/.ssh/id_rsa.pub > authorized_keys
ssh -F $HOME/.ssh/xci-vm-config xci_vm_opnfv sudo mkdir /root/.ssh
scp -F $HOME/.ssh/xci-vm-config authorized_keys xci_vm_opnfv:/home/devuser/.ssh/authorized_keys
# /root/.ssh/known_hosts must exist or we will get a "mkstemp: No such file or directory" when doing ssh-keygen -R in one of the bifrost roles
scp ${HOME}/.ssh/known_hosts devuser@${OPNFV_VM_IP}:/home/devuser/.ssh/known_hosts

ssh devuser@${OPNFV_VM_IP} sudo cp /home/devuser/.ssh/* /root/.ssh/

ssh root@${OPNFV_VM_IP} mkdir /root/releng-xci

# All the important releng-xci is copied over (ansible remote copy module cannot do recursive)
rsync -ravz -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        --exclude .cache/repos/openstack-ansible-tests/ \
        --exclude venv/ \
        --exclude "*qcow2*" \
        --exclude xci/logs/ \
        ${XCI_PATH} \
        root@${OPNFV_VM_IP}:/root

# xci-opnfv-vm.sh is executed
# we need to be root or:
# [OPENSUSE] /home/devuser/releng-xci/.cache/repos/bifrost/scripts/xci-opnfv-vm.sh: line 19: /etc/resolv.conf: Permission denied
# [UBUNTU] Could not install packages due to an EnvironmentError: [Errno 13] Permission denied: '/usr/local/bin/pbr'
ssh root@${OPNFV_VM_IP} bash /root/releng-xci/.cache/repos/bifrost/scripts/xci-opnfv-vm.sh
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
