#-------------------------------------------------------------------------------
# Start the provision of opnfv VM
#-------------------------------------------------------------------------------
# This playbook
# - Installs the essential packages for the different distros to run bifrost
# - Triggers the bifrost provisioning
#-------------------------------------------------------------------------------

set -eu

cd /root/releng-xci

if [ -x "$(command -v apt)" ]; then
  # While we clarify if adding iptables to the required packages
  apt-get update
  apt-get -y install iptables
fi

if [ -x "$(command -v zypper)" ]; then
  echo nameserver 8.8.8.8 >> /etc/resolv.conf
  # repo-update is disabled in the image
  zypper mr -e repo-update
  # gcc 4.9 is required to install pysendfile in bifrost-keystone
  zypper addrepo https://download.opensuse.org/repositories/home:Ledest:devel/openSUSE_Leap_42.3/home:Ledest:devel.repo
  zypper --gpg-auto-import-keys refresh
fi

bash .cache/repos/bifrost/scripts/bifrost-provision.sh
