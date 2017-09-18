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


class FilterModule(object):
    '''
    Functions linked to node network interfaces
    '''

    def filters(self):
        return {
            'role2nodes': role2nodes,
        }
