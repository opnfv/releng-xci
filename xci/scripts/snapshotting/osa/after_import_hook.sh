#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 Ericsson AB and Others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

declare -r controller_vms=`sudo virsh list --name | grep 'controller*' | sort`
declare -r compute_vms=`sudo virsh list --name | grep 'compute*' | sort`
declare -r lxc_attach="lxc-attach"
declare -r lxc_ls="lxc-ls"

##############################################################################
# Stop and Start the neutron specific services in a certain order
# to make Openstack deployment to be functional
##############################################################################
function restart_neutron_services() {
  local inventory_file_path=$1
  local neutron_container_filter="${lxc_ls} -1 --filter neutron_server_container | head -n 1"
  for node in $controller_vms;do
    local node_ip=$(grep -o "$node ansible_ssh_host.*" ${inventory_file_path} | cut -f2- -d=)
    local node_ssh="ssh root@$node_ip"
    local neutron_server_container=$($node_ssh "$neutron_container_filter")
    # TODO: restart other required neutron services too. it varies based on deployment scenario.
    if [[ -n $($node_ssh "bash -c '${lxc_attach} -n $neutron_server_container -- ps ax | grep -v grep | grep neutron-server'") ]]; then
      $node_ssh "bash -c '${lxc_attach} -n $neutron_server_container -- service neutron-server stop'"
      $node_ssh "bash -c '${lxc_attach} -n $neutron_server_container -- service neutron-server start'"
    fi
    if [[ -n $($node_ssh "ps ax | grep -v grep | grep neutron-dhcp-agent") ]]; then
      $node_ssh "service neutron-dhcp-agent stop"
      $node_ssh "service neutron-dhcp-agent start"
    fi
  done
}

##############################################################################
# Stop and Start the neutron specific services in a certain order
# to make Openstack deployment to be functional
##############################################################################
function restart_nova_compute() {
  local inventory_file_path=$1
  for node in $compute_vms;do
    local node_ip=$(grep -o "$node ansible_ssh_host.*" ${inventory_file_path} | cut -f2- -d=)
    local node_ssh="ssh root@$node_ip"
    if [[ -n $($node_ssh "ps ax | grep -v grep | grep nova-compute") ]]; then
      $node_ssh "service nova-compute stop"
      $node_ssh "service nova-compute start"
    fi
  done
}

# restart the required services to make the deployment to be functional
restart_nova_compute $1
restart_neutron_services $1
