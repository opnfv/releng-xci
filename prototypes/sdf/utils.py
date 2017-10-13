#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Utilities functions
"""

import random
import re
from yaml import load, dump, YAMLError
try:
    from yaml import CLoader as Loader, CDumper as Dumper
except ImportError:
    from yaml import Loader, Dumper

# Prepare a storage for ids
id_store = dict()

def check_yaml(content):
    try:
        load(content)
        return True
    except YAMLError as exc:
        print("Error in YAML validation")
        print(exc)
        return False


def load_yaml_file(filepath):
    """Load YAML file"""
    with open(filepath, 'r') as stream:
        try:
            return load(stream)
        except yaml.YAMLError as exc:
            print(exc)


def load_yaml(source):
    """Load YAML file"""
    if type(source) is list:
        ret = list()
        for filepath in source:
            ret.append(load_yaml_file(filepath))
    else:
        ret = load_yaml_file(source)
    return ret


def dump_yaml(item):
    return dump(item)


def as_dict(obj):
    for k, v in obj.__dict__.items():
        print(k)


def net_incr(netw, increment=1):
    pattern = re.compile('^(.*?)([0-9]+)$')
    m = pattern.match(netw)
    return '{}{}'.format(m.group(1), int(m.group(2)) + increment)


def port_split(ip_port):
    pattern = re.compile('^(.*):([0-9]+)$')
    m = pattern.match(ip_port)
    return [m.group(1), m.group(2)]


def get_id(key, length=16):
    global id_store
    if key not in passwords_store.keys():
        char_list = '0123456789'
        idlist = []
        for i in range(length):
            idlist.append(char_list[random.randrange(len(char_list))])
        random.shuffle(idlist)
        id_store[key] = "".join(idlist)
    return id_store[key]

# Prepare a storage for passwords
passwords_store = dict()


def get_password(key, length=16, special=False):
    """Return a new random password or a already created one"""
    global passwords_store
    if key not in passwords_store.keys():
        alphabet = "abcdefghijklmnopqrstuvwxyz"
        upperalphabet = alphabet.upper()
        char_list = alphabet + upperalphabet + '0123456789'
        pwlist = []
        if special:
            char_list += "+-,;./:?!*"
        for i in range(length):
            pwlist.append(char_list[random.randrange(len(char_list))])
        random.shuffle(pwlist)
        passwords_store[key] = "".join(pwlist)
    return passwords_store[key]
