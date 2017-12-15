##############################################################################
# Copyright (c) 2018 Orange and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################


def target_interfaces(inventory_hostname, hostvars, nodes):
    """Get the macs used on the node

    Args:
        inventory_hostname: the node name
        hostvars: the ansible hostvars of the node
        nodes: a dict of nodes

    Returns:
        list of macs in (lower case) of interfaces plugged on the node
    """
    return [i['mac_address'].lower() for i in nodes[hostvars[
        inventory_hostname]['ansible_hostname']]['interfaces']]

def mac2intf(inventory_hostname, hostvars, nodes):
    """Get the node's macs associate to its interface name

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
            'target_interfaces': target_interfaces,
            'mac2intf': mac2intf,
        }
