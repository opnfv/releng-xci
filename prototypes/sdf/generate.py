#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import print_function
import os
import sys
from jinja2 import Environment, FileSystemLoader
from pprint import pprint as pp
import utils

"""
This script generates a sdf.yaml config file
"""


def clean_exit(msg):
    print("usage: ./{} <scenario name> <target folder>".format(sys.argv[0]))
    print(msg)
    sys.exit(0)


##
# Set config
##
config = utils.load_yaml("config.yaml")

# Explote scenario name
if len(sys.argv) > 1:
    scenario_name = sys.argv[1]
    target_folder = '.'
else:
    clean_exit('Check parameters')
if len(sys.argv) > 2:
    target_folder = sys.argv[2]
    if not os.path.isdir(target_folder):
        clean_exit("Please provide an existing target name")

if scenario_name.count('-') == 3:
    (cloud_controller, network_controller,
        features, availability) = scenario_name.split('-')
    features = [] if features == 'nofeature' else features.split('_')
    config['sc'] = {
        'availability': availability,
        'network_controller': network_controller,
        'cloud_controller': cloud_controller,
        'features': features
        }
    pp(config['sc'])
else:
    clean_exit("Please provide a conform scenario name")

# Capture our current directory
TPL_DIR = os.path.dirname(os.path.abspath(__file__))+'/templates'


##
# Template functions
##

# set a function that can be called in the template
# check if any in a is in b
def any_in(a, b):
    return any(i in b for i in a)


# check if all in a is in b
def all_in(a, b):
    b.append('nofeature')
    return set(a) < set(b)


##
# Generate the idf
##

# Create the jinja2 environment.
if os.path.isfile("{}/scenarios/{}.yaml".format(TPL_DIR, scenario_name)):
    tpl = "scenarios/{}.yaml".format(scenario_name)
    print('Scenario {} is not generic'.format(scenario_name))
else:
    tpl = "scenarios/{}".format(config['generic_scenario'])
    print('Scenario {} is generic'.format(scenario_name))
env = Environment(loader=FileSystemLoader(TPL_DIR),
                  trim_blocks=True)
template = env.get_template(tpl)
env.globals.update(any_in=any_in)
env.globals.update(all_in=all_in)

# Render the template
output = template.render(**config)

##
# Save the sdf
##
with open('{}/sdf.yaml'.format(target_folder), 'w') as f:
    print(output, file=f)
