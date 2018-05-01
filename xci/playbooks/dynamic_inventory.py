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

import argparse
import os
import sys
import yaml
import json

pdf_file = os.path.dirname(os.path.realpath(__file__)) + "/../var/pdf.yml"
idf_file = os.path.dirname(os.path.realpath(__file__)) + "/../var/idf.yml"


class XCIInventory(dict):
    def __init__(self, *args, **kw):
        super(XCIInventory, self).__init__(*args, **kw)
        self.inventory = {}
        self.inventory['all'] = {}
        self.inventory['all']['hosts'] = []
        self.inventory['_meta'] = {}
        self.inventory['_meta']['hostvars'] = {}
        self.installer = os.environ.get('INSTALLER_TYPE', 'osa')
        self.flavor = os.environ.get('XCI_FLAVOR', 'mini')

        # Static information for opnfv host for now
        self.add_host('opnfv')
        self.add_hostvar('opnfv', 'ansible_ssh_host', '192.168.122.2')
        self.add_group('deployment', 'opnfv')
        self.add_group('opnfv', 'opnfv')

        self.read_idf()
        self.read_pdf()

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

    def read_pdf(self):
        with open(pdf_file) as f:
            try:
                pdf = yaml.safe_load(f)
            except yaml.YAMLError as e:
                print(e)
                sys.exit(1)

        valid_hosts = (host for host in pdf['nodes'] if host['name'] in self.hosts())
        for host in valid_hosts:
            # find IP
            native_vlan_if = filter(lambda x: x['vlan'] == 'native', host['interfaces'])
            self.add_hostvar(host['name'], 'ansible_ssh_host', native_vlan_if[0]['address'])

    def read_idf(self):
        with open(idf_file) as f:
            try:
                idf = yaml.safe_load(f)
            except yaml.YAMLError as e:
                print(e)
                sys.exit(1)

        valid_host = (host for host in idf['xci'][self.installer]['nodes_roles'] if host in idf['xci']['flavors'][self.flavor])

        for host in valid_host:
            self.add_host(host)
            for role in idf['xci'][self.installer]['nodes_roles'][host]:
                self.add_group(role, host)

    def dump(self, data):
        print (json.dumps(data, sort_keys=True, indent=2))

    def add_host(self, host):
        self.inventory['all']['hosts'].append(host)

    def hosts(self):
        return self.inventory['all']['hosts']

    def add_group(self, group, host):
        if group not in self.inventory.keys():
            self.inventory[group] = []
        self.inventory[group].append(host)

    def add_hostvar(self, host, param, value):
        if host not in self.hostvars():
            self.inventory['_meta']['hostvars'][host] = {}
        self.inventory['_meta']['hostvars'][host].update({param: value})

    def hostvars(self):
        return iter(self.inventory['_meta']['hostvars'].keys())

    def get_host_info(self, host):
        return self.inventory['_meta']['hostvars'][host]

if __name__ == '__main__':
    XCIInventory()

# vim: set ts=4 sw=4 expandtab:
