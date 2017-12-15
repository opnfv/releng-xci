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
    return [ node['name'] for node in nodes ]


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
        }
