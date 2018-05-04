#-------------------------------------------------------------------------------
# Start the provision of opnfv VM
#-------------------------------------------------------------------------------
# This playbook
# -
#-------------------------------------------------------------------------------

set -eu

cd /home/devuser/releng-xci

# While we clarify if adding iptables to the required packages
sudo apt-get update
sudo -y apt-get install iptables

sudo bash .cache/repos/bifrost/scripts/bifrost-provision.sh
