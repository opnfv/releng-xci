#!/usr/bin/python
# coding utf-8

# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#
# Based on https://raw.githubusercontent.com/ansible/ansible/devel/contrib/inventory/cobbler.py

import argparse
import glob
import os
import sys
import yaml
import json


class XCIInventory(object):
    def __init__(self):
        super(XCIInventory, self).__init__()
        self.inventory = {}
        self.inventory['all'] = {}
        self.inventory['all']['hosts'] = []
        self.inventory['all']['vars'] = {}
        self.inventory['_meta'] = {}
        self.inventory['_meta']['hostvars'] = {}
        self.installer = os.environ.get('INSTALLER_TYPE', 'osa')
        self.flavor = os.environ.get('XCI_FLAVOR', 'mini')
        self.flavor_files = os.path.dirname(os.path.realpath(__file__)) + "/../installer/" + self.installer + "/files/" + self.flavor

        # Static information for opnfv host for now
        self.add_host('opnfv')
        self.add_hostvar('opnfv', 'ansible_host', '192.168.122.2')
        self.add_hostvar('opnfv', 'ip', '192.168.122.2')
        self.add_to_group('deployment', 'opnfv')
        self.add_to_group('opnfv', 'opnfv')

        self.opnfv_networks = {}
        self.opnfv_networks['opnfv'] = {}
        self.opnfv_networks['opnfv']['admin'] = {}
        self.opnfv_networks['opnfv']['admin']['address'] = '172.29.236.10/22'
        self.opnfv_networks['opnfv']['public'] = {}
        self.opnfv_networks['opnfv']['public']['address'] = '192.168.122.2/24'
        self.opnfv_networks['opnfv']['public']['gateway'] = '192.168.122.1'
        self.opnfv_networks['opnfv']['public']['dns'] = '192.168.122.1'
        self.opnfv_networks['opnfv']['private'] = {}
        self.opnfv_networks['opnfv']['private']['address'] = '172.29.240.10/22'
        self.opnfv_networks['opnfv']['storage'] = {}
        self.opnfv_networks['opnfv']['storage']['address'] = '172.29.244.10/24'

        # Add localhost
        self.add_host('deployment_host')
        self.add_hostvar('deployment_host', 'ansible_ssh_host', '127.0.0.1')
        self.add_hostvar('deployment_host', 'ansible_connection', 'local')

        self.read_pdf_idf()

        self.parse_args()

        if self.args.host:
            self.dump(self.get_host_info(self.args.host))
        else:
            self.dump(self.inventory)

    def parse_args(self):
        parser = argparse.ArgumentParser(description='Produce an Ansible inventory based on PDF/IDF XCI files')
        parser.add_argument('--list', action='store_true', default=True, help='List XCI hosts (default: True)')
        parser.add_argument('--host', action='store', help='Get all the variables about a specific host')
        self.args = parser.parse_args()

    def read_pdf_idf(self):
        pdf_file = os.path.dirname(os.path.realpath(__file__)) + "/../var/ericsson-pdf-pod2.yml"
        idf_file = os.path.dirname(os.path.realpath(__file__)) + "/../var/ericsson-idf-pod2.yml"
        opnfv_file = os.path.dirname(os.path.realpath(__file__)) + "/../var/opnfv_vm.yml"
        nodes = []
        host_networks = {}

        with open(pdf_file) as f:
            try:
                pdf = yaml.safe_load(f)
            except yaml.YAMLError as e:
                print(e)
                sys.exit(1)

        with open(idf_file) as f:
            try:
                idf = yaml.safe_load(f)
            except yaml.YAMLError as e:
                print(e)
                sys.exit(1)

        with open(opnfv_file) as f:
            try:
                opnfv_pdf = yaml.safe_load(f)
            except yaml.YAMLError as e:
                print(e)
                sys.exit(1)

        valid_host = (host for host in idf['xci'][self.installer]['nodes_roles'] \
                      if host in idf['xci']['flavors'][self.flavor] \
                      and host != 'opnfv')

        for host in valid_host:
            nodes.append(host)
            hostname = idf['xci'][self.installer]['hostnames'][host]
            self.add_host(hostname)
            for role in idf['xci'][self.installer]['nodes_roles'][host]:
                self.add_to_group(role, hostname)

            pdf_host_info = filter(lambda x: x['name'] == host, pdf['nodes'])[0]
            native_vlan_if = filter(lambda x: x['vlan'] == 'native', pdf_host_info['interfaces'])
            self.add_hostvar(hostname, 'ansible_host', native_vlan_if[0]['address'])
            self.add_hostvar(hostname, 'ip', native_vlan_if[0]['address'])
            host_networks[hostname] = {}
            # And now record the rest of the information
            for network, ndata in idf['idf']['net_config'].items():
                network_interface_num = idf['idf']['net_config'][network]['interface']
                host_networks[hostname][network] = {}
                host_networks[hostname][network]['address'] = pdf_host_info['interfaces'][int(network_interface_num)]['address'] + "/" + str(ndata['mask'])
                if 'gateway' in ndata.keys():
                    host_networks[hostname][network]['gateway'] = str(ndata['gateway']) + "/" + str(ndata['mask'])
                if 'dns' in ndata.keys():
                    host_networks[hostname][network]['dns'] = str(ndata['dns'])

                # Get also vlan and mac_address from pdf
                host_networks[hostname][network]['mac_address'] = str(pdf_host_info['interfaces'][int(network_interface_num)]['mac_address'])
                host_networks[hostname][network]['vlan'] = str(pdf_host_info['interfaces'][int(network_interface_num)]['vlan'])

            # Get also vlan and mac_address from opnfv_pdf
            opnfv_admin = filter(lambda x: x['config'] == 'admin', opnfv_pdf['opnfv_vm']['interfaces'])[0]
            opnfv_public = filter(lambda x: x['config'] == 'pxe', opnfv_pdf['opnfv_vm']['interfaces'])[0]
            self.opnfv_networks['opnfv']['admin']['mac_address'] = str(opnfv_admin['mac_address'])
            self.opnfv_networks['opnfv']['admin']['vlan'] = str(opnfv_admin['vlan'])
            self.opnfv_networks['opnfv']['public']['mac_address'] = str(opnfv_public['mac_address'])
            self.opnfv_networks['opnfv']['public']['vlan'] = str(opnfv_public['vlan'])


            host_networks.update(self.opnfv_networks)

            self.add_groupvar('all', 'host_info', host_networks)

        # Now add the additional groups
        for parent in idf['xci'][self.installer]['groups'].keys():
            map(lambda x: self.add_group(x, parent), idf['xci'][self.installer]['groups'][parent])

        # Read additional group variables
        self.read_additional_group_vars()

    def read_additional_group_vars(self):
        if not os.path.exists(self.flavor_files + "/inventory/group_vars"):
            return
        group_dir = self.flavor_files + "/inventory/group_vars/*.yml"
        group_file = glob.glob(group_dir)
        for g in group_file:
            with open(g) as f:
                try:
                    group_vars = yaml.safe_load(f)
                except yaml.YAMLError as e:
                    print(e)
                    sys.exit(1)
                for k,v in group_vars.items():
                    self.add_groupvar(os.path.basename(g.replace('.yml', '')), k, v)

    def dump(self, data):
        print (json.dumps(data, sort_keys=True, indent=2))

    def add_host(self, host):
        self.inventory['all']['hosts'].append(host)

    def hosts(self):
        return self.inventory['all']['hosts']

    def add_group(self, group, parent = 'all'):
        if parent not in self.inventory.keys():
            self.inventory[parent] = {}
        if 'children' not in self.inventory[parent]:
            self.inventory[parent]['children'] = []
        self.inventory[parent]['children'].append(group)

    def add_to_group(self, group, host):
        if group not in self.inventory.keys():
            self.inventory[group] = []
        self.inventory[group].append(host)

    def add_hostvar(self, host, param, value):
        if host not in self.hostvars():
            self.inventory['_meta']['hostvars'][host] = {}
        self.inventory['_meta']['hostvars'][host].update({param: value})

    def add_groupvar(self, group, param, value):
        if param not in self.groupvars(group):
            self.inventory[group]['vars'][param] = {}
        self.inventory[group]['vars'].update({param: value})

    def hostvars(self):
        return iter(self.inventory['_meta']['hostvars'].keys())

    def groupvars(self, group):
        return iter(self.inventory[group]['vars'].keys())

    def get_host_info(self, host):
        return self.inventory['_meta']['hostvars'][host]

if __name__ == '__main__':
    XCIInventory()

# vim: set ts=4 sw=4 expandtab:
