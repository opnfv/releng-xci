##############################################################################
# Copyright (c) 2018 Orange and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


def nodes_as_dict(nodes):
    """Convert nodes list to dict indexed on nodes name

    Args:
        nodes: the nodes list

    Returns:
        dictionnary of nodes
    """
    return {n['name']: n for n in nodes}


def nodes_index(nodes, zero_key='opnfv_host'):
    index = {}
    for i, n in enumerate(sorted([n['name'] for n in nodes])):
        index[n] = 0 if n == zero_key else i+1
    return index


def nodes_filter(nodes, nodes_roles, deploy_def):
    """Filter a list of node to fit the deploy_size needs

    Args:
        nodes: nodes list from pdf file + xci_hosts
        nodes_roles: roles mapping from idf file
        deploy_def: roles distribution (deploy_definitions[deploy_size])

    Returns:
        a shortened list of nodes
    """
    filtered_list = []
    nodes_d = nodes_as_dict(nodes)
    roles_map = role2nodes(nodes_roles)
    for role, qty in deploy_def.items():
        if qty > roles_map[role]:
            print('not enought node for role {}'.format(role))
            raise ValueError('not enought node for role {}'.format(role))
        for i in range(0, qty):
            node_name = roles_map[role].pop(0)
            filtered_list.append(nodes_d[node_name])
    return filtered_list


def role2nodes(nodes_roles):
    """Get a dictionnary containing nodes associate to a role

    Args:
        nodes_roles: nodes_roles list from IDF

    Returns:
        {'controller': [], 'compute': [], 'storage': [], 'network': []...}
    """
    roles = {}
    for node in sorted(nodes_roles):
        for role in nodes_roles[node]:
            if role not in roles.keys():
                roles[role] = []
            roles[role].append(node)
    return roles


def nodes_name(nodes):
    """Return a list of nodes name

    Args:
        nodes: nodes list from PDF

    Returns:
        [ 'node1', 'node2', ... ]
    """
    return sorted(node['name'] for node in nodes)


def nodes_net_config(nodes, net_config):
    """Get a dictionnary containing the ip of each network of all nodes

    Args:
        nodes: nodes list from PDF
        net_config: the net_config from IDF

    Returns:
        { <node_name>: { 'net1': {'ip': 'xxx', 'mac': 'xxx'},
                         'net2': {'ip': 'xxx', 'mac': 'xxx'}, ...}
    """
    nodes_net_config = {}
    for node in nodes:
        nodes_net_config[node['name']] = {}
        nic_map = {
            intf['name']: {
                'ip': intf['address'] if 'address' in intf.keys() else '',
                'mac': intf['mac_address']
            }
            for intf in node['interfaces']
        }
        for net_name, net_cfg in net_config.items():
            if 'nic{}'.format(net_cfg['interface']+1) in nic_map.keys():
                nodes_net_config[node['name']][net_name] = \
                    nic_map['nic{}'.format(int(net_cfg['interface'])+1)]
    return nodes_net_config

class FilterModule(object):
    '''
    Functions linked to node network interfaces
    '''

    def filters(self):
        return {
            'role2nodes': role2nodes,
            'nodes_as_dict': nodes_as_dict,
            'nodes_filter': nodes_filter,
            'nodes_index': nodes_index,
            'nodes_name': nodes_name,
            'nodes_net_config': nodes_net_config,
        }
