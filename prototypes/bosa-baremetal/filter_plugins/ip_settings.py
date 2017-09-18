from netaddr import IPAddress, IPNetwork


# This need to be rewritten to be IPv6 compliant

def ip_add(ip, add):
    """Increment an dotted string ip with a value

    Args:
        ip: IP as a dotted string
        add: the increment value

    Returns:
        IP as a dotted string
    """
    return str(IPAddress(int(IPAddress(ip))+add))


def ip_last_of(net, mask):
    """Increment an dotted string ip with a value

    Args:
        net: Network as a dotted string
        mask: network mask as int

    Returns:
        IP as a dotted string
    """
    return ip_add(int(IPNetwork("{}/{}".format(net, mask)).broadcast), -1)


def get_nodes_names(nodes):
    """Get a sorted list of nodes names

    Args:
        nodes: nodes list from PDF

    Returns:
        A sorted list of hosts names
    """
    return sorted(node['name'] for node in nodes)


def node_ips(nodes, netw, shift):
    """Get a dictionnary containing the main ip of a node, and the index of
    this node in the list

    Args:
        nodes: nodes list from PDF
        network: the network of the main ip
        shift: the increment to apply to the network for all ips

    Returns:
        { <node_name>: { 'ip': <nodeip>, 'index': <index of the node>}}
    """
    nodes_ips = {}
    for index, srv_name in enumerate(get_nodes_names(nodes)):
        nodes_ips[srv_name] = {'ip': ip_add(netw, shift+index+1),
                               'index': index+1}
    return nodes_ips


class FilterModule(object):
    '''
    Functions linked to node network interfaces
    '''

    def filters(self):
        return {
            'ip_add': ip_add,
            'ip_last_of': ip_last_of,
            'node_ips': node_ips,
        }
