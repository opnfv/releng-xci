##############################################################################
# Copyright (c) 2018 Orange and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

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
    target_unit = target_unit.lower()
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
