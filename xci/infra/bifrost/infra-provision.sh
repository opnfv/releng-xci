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

echo "Info: Starting provisining VM nodes using openstack/bifrost"
echo "-------------------------------------------------------------------------"
# We are using sudo so we need to make sure that env_reset is not present
sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers
cd $BIFROST_ROOT_DIR
sudo -E bash ./scripts/destroy-env.sh
cd $BIFROST_ROOT_DIR/playbooks/
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i "localhost," bootstrap-bifrost.yml
cd ${XCI_CACHE}/repos/bifrost
bash ./scripts/bifrost-provision.sh
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
