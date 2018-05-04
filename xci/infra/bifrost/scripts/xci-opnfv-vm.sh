# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#
#-------------------------------------------------------------------------------
# Start the provision of opnfv VM
#-------------------------------------------------------------------------------
# This playbook
# - Installs the essential packages for the different distros to run bifrost
# - Triggers the bifrost provisioning
#-------------------------------------------------------------------------------

set -eu

source /etc/os-release || source /usr/lib/os-release

cd /root/releng-xci

case ${ID,,} in
  ubuntu|debian)
    # While we clarify if adding iptables to the required packages
    apt-get update
    apt-get -y install iptables
    ;;
  *suse*)
    echo nameserver 8.8.8.8 >> /etc/resolv.conf
    # repo-update is disabled in the image
    zypper mr -e repo-update
    # gcc 4.9 is required to install pysendfile in bifrost-keystone
    zypper addrepo https://download.opensuse.org/repositories/home:Ledest:devel/openSUSE_Leap_42.3/home:Ledest:devel.repo
    zypper --gpg-auto-import-keys refresh
    ;;
esac

bash .cache/repos/bifrost/scripts/bifrost-provision.sh
