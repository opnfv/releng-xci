#-------------------------------------------------------------------------------
# Start the provision of opnfv VM
#-------------------------------------------------------------------------------
# This playbook
# -
#-------------------------------------------------------------------------------

set -eu

cd /home/devuser/releng-xci

if ! [ -x "$(command -v apt)" ]; then
  # While we clarify if adding iptables to the required packages
  sudo apt-get update
  sudo -y apt-get install iptables
fi

sudo bash .cache/repos/bifrost/scripts/bifrost-provision.sh
