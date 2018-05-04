#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2016 RedHat and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# We need to execute everything as root
if [[ $(whoami) != "root" ]]; then
    echo "Error: This script must be run as root!"
    exit 1
fi

flavors=(aio mini noha ha)

# Start fresh
rm -rf /opt/stack
# HOME is normally set by sudo -H
rm -rf ${HOME}/.config/openstack
rm -rf ${HOME}/.ansible
# Wipe repos
rm -rf ${XCI_CACHE}/repos

# bifrost installs everything on venv so we need to look there if virtualbmc is not installed on the host.
if which vbmc &>/dev/null || { [[ -e ${XCI_VENV}/bifrost/bin/activate ]] && source ${XCI_VENV}/bifrost/bin/activate; }; then
    # Delete all libvirt VMs and hosts from vbmc (look for a port number)
    for vm in $(vbmc list | awk '/[0-9]/{{ print $2 }}'); do
        if which virsh &>/dev/null; then
            virsh destroy $vm &>/dev/null || true
            virsh undefine $vm &>/dev/null || true
        fi
        vbmc delete $vm
    done
    which vbmc &>/dev/null || { [[ -e /opt/stack/bifrost/bin/activate ]] && deactivate; }
fi

# Destroy all XCI VMs on all flavors
for varfile in ${flavors[@]}; do
    source ${XCI_PATH}/xci/config/${varfile}-vars
    for vm in ${NODE_NAMES}; do
        if which virsh &>/dev/null; then
            virsh destroy $vm &>/dev/null || true
            virsh undefine $vm &>/dev/null || true
        fi
    done
done

service ironic-conductor stop || true

echo "removing inventory files created by previous builds"
rm -rf /tmp/baremetal.*

echo "removing ironic database"
if $(which mysql &> /dev/null); then
    mysql_ironic_user=$(sudo grep "connection" /etc/ironic/ironic.conf | cut -d : -f 2 )
    msyql_ironic_password=$(sudo grep "connection" /etc/ironic/ironic.conf | cut -d : -f 3)
    mysql -u${mysql_ironic_user#*//} -p${msyql_ironic_password%%@*} --execute "drop database ironic;"
fi
echo "removing leases"
[[ -e /var/lib/misc/dnsmasq/dnsmasq.leases ]] && > /var/lib/misc/dnsmasq/dnsmasq.leases
echo "removing logs"
rm -rf /var/log/libvirt/baremetal_logs/*

# clean up dib images by default
CLEAN_DIB_IMAGES=${CLEAN_DIB_IMAGES:-true}

if [ $CLEAN_DIB_IMAGES = "true" ]; then
    rm -rf /httpboot /tftpboot
    mkdir /httpboot /tftpboot
    chmod -R 755 /httpboot /tftpboot
fi

# remove VM disk images
rm -rf /var/lib/libvirt/images/*.qcow2

echo "restarting services"
service dnsmasq restart || true
service libvirtd restart
service ironic-api restart || true
service ironic-conductor start || true
service ironic-inspector restart || true

rm -rf ${XCI_VENV}

# vim: set ts=4 sw=4 expandtab:
