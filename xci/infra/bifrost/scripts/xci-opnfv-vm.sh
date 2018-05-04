#-------------------------------------------------------------------------------
# Start the provision of opnfv VM
#-------------------------------------------------------------------------------
# This playbook
# -
#-------------------------------------------------------------------------------

set -eu

cd /home/devuser/releng-xci

if [ -x "$(command -v apt)" ]; then
  # While we clarify if adding iptables to the required packages
  apt-get update
  apt-get -y install iptables
fi

if [ -x "$(command -v zypper)" ]; then
  echo nameserver 8.8.8.8 >> /etc/resolv.conf
  zypper mr -e repo-update
  zypper addrepo https://download.opensuse.org/repositories/home:Ledest:devel/openSUSE_Leap_42.3/home:Ledest:devel.repo
  zypper --gpg-auto-import-keys refresh
fi

bash .cache/repos/bifrost/scripts/bifrost-provision.sh
