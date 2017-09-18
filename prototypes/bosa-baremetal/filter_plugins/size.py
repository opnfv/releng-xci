import re


def sizeConv(s, target_unit='Mo'):
    """convert size into the targeted unit

    Args:
        s: size, as a string
        target_unit: the unit to convert to (default: Mo)

    Returns:
        the converted size as a string
    """
    s = str(s)
    p = re.compile('(\d+)+\s*([^\s]*)')
    (size, unit) = p.findall(s)[0]
    size = int(size)
    unit = unit.lower()
    if unit in ['g', 'go']:
        size *= 1024
    elif unit in ['t', 'to']:
        size *= 1024 * 1024

    if target_unit in ['g', 'go']:
        div = 1024
    elif target_unit in ['t', 'to']:
        div = 1024 * 1024
    else:
        div = 1
    return size // div


def sizeSum(sizes, target_unit='Mo'):
    """Sum sizes, and convert to targeted unit

    Args:
        sizes: a list of sizes, as a string
        target_unit: the unit to convert to (default: Mo)

    Returns:
        the sum of sizes as a string
    """
    r = 0
    for s in sizes:
        r += sizeConv(s, target_unit)
    return r


class FilterModule(object):
    '''
    custom jinja2 filters for working with size
    '''

    def filters(self):
        return {
            'sizeConv': sizeConv,
            'sizeSum': sizeSum
        }
