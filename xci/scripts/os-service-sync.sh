#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 Ericsson AB and Others
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -e

export XCI_PATH="$(git rev-parse --show-toplevel)"


declare -r controller_vms=`sudo virsh list --name | grep 'controller*' | sort`
declare -r compute_vms=`sudo virsh list --name | grep 'compute*' | sort`
declare -r lxc_attach="lxc-attach"
declare -r lxc_ls="lxc-ls"

restart_neutron_services() {
neutron_container_filter="${lxc_ls} -1 --filter neutron_server_container | head -n 1"
for node in $controller_vms;do
  node_ip=$(for mac in `sudo virsh domiflist $node |grep -o -E "([0-9a-f]{2}:){5}([0-9a-f]{2})"` ; do sudo arp -e |grep $mac  |grep -o -P "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" ; done)
  neutron_server_container=$node_ssh "$neutron_container_filter"
  node_ssh="ssh root@$node_ip"
  $node_ssh "bash -c 'lxc-attach -n $neutron_server_container -- service neutron-server stop'"
  sleep 5
  $node_ssh "bash -c 'lxc-attach -n $neutron_server_container -- service neutron-server start'"
  sleep 5
  $node_ssh "service neutron-dhcp-agent stop"
  sleep 5
  $node_ssh "service neutron-dhcp-agent start"
done
}

restart_nova_compute() {
for node in $compute_vms;do
  node_ip=$(for mac in `sudo virsh domiflist $node |grep -o -E "([0-9a-f]{2}:){5}([0-9a-f]{2})"` ; do sudo arp -e |grep $mac  |grep -o -P "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" ; done)
  node_ssh="ssh root@$node_ip"
  $node_ssh "service nova-compute stop"
  sleep 5
  $node_ssh "service nova-compute start"
done
}

restart_nova_compute
restart_neutron_services