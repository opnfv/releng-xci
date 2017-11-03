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

# Start fresh
rm -rf /opt/stack
# HOME is normally set by sudo -H
rm -rf ${HOME}/.config/openstack

# bifrost installs everything on venv so we need to look there if virtualbmc is not installed on the host.
if which vbmc &>/dev/null || { [[ -e /opt/stack/bifrost/bin/activate ]] && source /opt/stack/bifrost/bin/activate; }; then
	# Delete all libvirt VMs and hosts from vbmc (look for a port number)
	for vm in $(vbmc list | awk '/[0-9]/{{ print $2 }}'); do
		virsh destroy $vm || true
		virsh undefine $vm || true
		vbmc delete $vm
	done
	which vbmc &>/dev/null || { [[ -e /opt/stack/bifrost/bin/activate ]] && deactivate; }
fi

# Destroy all XCI VMs if the previous operation failed
if $(which virsh &> /dev/null); then
    [[ -n ${XCI_FLAVOR} ]] && \
        for vm in ${TEST_VM_NODE_NAMES}; do
            virsh destroy $vm || true
            virsh undefine $vm || true
        done
fi

echo "stopping ironic services"
if service --status-all | grep -Fq 'ironic-'; then
    service ironic-api stop || true
    service ironic-inspector stop || true
    service ironic-conductor stop || true
fi

echo "removing inventory files created by previous builds"
rm -rf /tmp/baremetal.*

if $(which mysql &> /dev/null); then
    echo "removing ironic database"
    mysql_ironic_user=$(sudo grep "connection" /etc/ironic/ironic.conf | cut -d : -f 2 )
    msyql_ironic_password=$(sudo grep "connection" /etc/ironic/ironic.conf | cut -d : -f 3)
    mysql -u${mysql_ironic_user#*//} -p${msyql_ironic_password%%@*} --execute "drop database if exists ironic;"

    echo "removing inspector database"
    mysql_ironic_user=$(sudo grep "connection" /etc/ironic-inspector/inspector.conf | cut -d : -f 2 )
    msyql_ironic_password=$(sudo grep "connection" /etc/ironic-inspector/inspector.conf | cut -d : -f 3)
    mysql -u${mysql_ironic_user#*//} -p${msyql_ironic_password%%@*} --execute "drop database if exists inspector;"
fi
echo "removing leases"
[[ -e /var/lib/misc/dnsmasq/dnsmasq.leases ]] && > /var/lib/misc/dnsmasq/dnsmasq.leases
echo "removing logs"
rm -rf /var/log/libvirt/baremetal_logs/*

# clean up dib images only if requested explicitly
CLEAN_DIB_IMAGES=${CLEAN_DIB_IMAGES:-false}

if [ $CLEAN_DIB_IMAGES = "true" ]; then
    rm -rf /httpboot /tftpboot
    mkdir /httpboot /tftpboot
    chmod -R 755 /httpboot /tftpboot
fi

# remove VM disk images
rm -rf /var/lib/libvirt/images/*.qcow2

echo "restarting services"
if service --status-all | grep -Fq 'dnsmasq'; then
    service dnsmasq restart || true
fi
if service --status-all | grep -Fq 'libvirtd'; then
    service libvirtd restart
fi
