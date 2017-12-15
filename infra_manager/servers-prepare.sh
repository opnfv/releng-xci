#!/bin/bash

# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 Orange and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o nounset
set -o pipefail

XCI_RUN_SCRIPT=${0}
XCI_RUN_ROOT=$(dirname $(readlink -f ${XCI_RUN_SCRIPT}))
source ${XCI_RUN_ROOT}/scripts/xci-rc.sh

# register our handler
trap submit_bug_report ERR

#-------------------------------------------------------------------------------
# This script should not be run as root
#-------------------------------------------------------------------------------
no_root_needed

#-------------------------------------------------------------------------------
# Install deps
#-------------------------------------------------------------------------------
step_banner "Install parsing deps"
source ${XCI_RUN_ROOT}/scripts/install-deps.sh
source ${XCI_RUN_ROOT}/scripts/xci-defaults.sh

#-------------------------------------------------------------------------------
# Install ansible
#-------------------------------------------------------------------------------
step_banner "Install ansible (${XCI_ANSIBLE_PIP_VERSION})"
source ${XCI_RUN_ROOT}/scripts/install-ansible.sh
step_banner "Install deps for ansible plugins"
sudo pip install netaddr
# remove pyopenssl has it failed on CENGEN ubuntu - to be checked
yes|sudo pip uninstall pyopenssl||true

#-------------------------------------------------------------------------------
# Local Preparation
#-------------------------------------------------------------------------------
step_banner "Prepare local ssh key"
create_local_ssh_key

#-------------------------------------------------------------------------------
# Prepare jumphost
#  - configure local ansible
#  - set local project folders
#-------------------------------------------------------------------------------
step_banner "Prepare jumphost"
ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
  -i ${XCI_RUN_ROOT}/inventory-jumphost.yml \
  ${XCI_RUN_ROOT}/opnfv-jumphost-prepare.yml

#-------------------------------------------------------------------------------
# Prepare servers
#  - set local VMs according to pdf/idf/xci_hosts files
#-------------------------------------------------------------------------------
step_banner "Prepare servers"
$HOME/.local/bin/ansible-galaxy install jriguera.configdrive
ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
  -i ${XCI_RUN_ROOT}/inventory-jumphost.yml \
  ${XCI_RUN_ROOT}/opnfv-servers-create.yml

#-------------------------------------------------------------------------------
# Job done
#-------------------------------------------------------------------------------
step_banner "Servers prepared"
