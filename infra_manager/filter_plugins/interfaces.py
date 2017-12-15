def interface_id_to_net(net_config, join=False, limit=99):
    """Convert nodes list to dict indexed on nodes name

    Args:
        net_config: the network list from PDF
        join: join networks of the same interface

    Returns:
        a list of interfaces id linked to a list of attached networks

    Returns example:
        [ ['admin', 'storage', 'private'],
          ['public']]
        or
        [ 'admin_storage_private'],
          'public']]
    """
    interfaces = {}
    for net in net_config:
        if net_config[net]['interface'] not in interfaces.keys():
            interfaces[net_config[net]['interface']] = []
        interfaces[net_config[net]['interface']].append(net)
    if join:
        for k, v  in interfaces.items():
            interfaces[k] = '_'.join(v)
    if limit < len(interfaces):
        return interfaces.values()[0:limit]
    return interfaces.values()


def get_networks(inventory_hostname, hostvars, network_profiles, nodes_roles):
    """Get the bridges needed for a node within its profile

    Args:
        inventory_hostname: the node name
        hostvars: the ansible hostvars of the node
        network_profiles: the network_profiles associating brige name to
            server group
        nodes_roles: a dict of nodes

    Returns:
        list of bridges on the node
    """
    br = []
    for node_role in nodes_roles[hostvars[inventory_hostname][
            'ansible_hostname']]:
        br.extend(x for x in network_profiles[node_role] if x not in br)
    return br


def target_interfaces(inventory_hostname, hostvars, nodes):
    """Get the macs used on the node

    Args:
        inventory_hostname: the node name
        hostvars: the ansible hostvars of the node
        nodes: a dict of nodes

    Returns:
        list of macs in (lower case) of interfaces plugged on the node
    """
    return [m.lower() for m in nodes[hostvars[inventory_hostname][
        'ansible_hostname']]['interfaces']['mac_address']]


def mac2intf(inventory_hostname, hostvars, nodes):
    """Get the mac associate to the interface name

    Args:
        inventory_hostname: the node name
        hostvars: the ansible hostvars of the node
        nodes: a dict of nodes

    Returns:
        list of macs of interfaces plugged on the node, linked with the
        interfaces name
    """
    intf_list = hostvars[inventory_hostname]['ansible_interfaces']
    target_macs = target_interfaces(inventory_hostname, hostvars, nodes)
    macs = {}
    for intf in intf_list:
        # only recover phsical interfaces
        if (intf.startswith('en') or intf.startswith('eth')) and \
                '.' not in intf:
            mac = hostvars[inventory_hostname]["ansible_{}".format(intf)
                                               ]['macaddress']
            if mac.lower() in target_macs:
                macs[mac] = intf
    return macs


class FilterModule(object):
    '''
    Functions linked to node network interfaces
    '''

    def filters(self):
        return {
            'interface_id_to_net': interface_id_to_net,
            'get_networks': get_networks,
            'target_interfaces': target_interfaces,
            'mac2intf': mac2intf,
        }
