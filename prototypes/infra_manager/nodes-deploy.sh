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

labels=$*

XCI_RUN_SCRIPT=${0}
XCI_RUN_ROOT=$(dirname $(readlink -f ${XCI_RUN_SCRIPT}))
export XCI_RUN_ROOT=$XCI_RUN_ROOT
source ${XCI_RUN_ROOT}/scripts/xci-rc.sh

# register our handler
trap submit_bug_report ERR

#-------------------------------------------------------------------------------
# This script should not be run as root
#-------------------------------------------------------------------------------
no_root_needed

#-------------------------------------------------------------------------------
# If no labels are set with args, run all
#-------------------------------------------------------------------------------
if [[ $labels = "" ]]; then
  labels="install deploy postinstall"
fi

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
# Prepare and install Bifrost (using official doc way)
#  - prepare Bifrost source and config
#  - run env-setup
#  - run official install.yml
#-------------------------------------------------------------------------------
if [[ $labels = *"install"* ]]; then
  step_banner "Prepare and configure Bifrost"
  ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
    -i ${XCI_ROOT}/${POD_NAME}/etc/ansible/opnfv_host_inventory \
    ${XCI_RUN_ROOT}/opnfv-opnfv_host-prepare.yml
  ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
    -i ${XCI_ROOT}/${POD_NAME}/etc/ansible/opnfv_host_inventory \
    -t prepare \
    -t sync \
    ${XCI_RUN_ROOT}/opnfv-nodes-deploy.yml
  # get bifrost server ip
  export XCI_BIF_IP=$(cat\
    ${XCI_ROOT}/${POD_NAME}/etc/ansible/host_vars/opnfv_host.yml |\
    yq -r .ansible_host)
  ssh ${OPNFV_USER}@${XCI_BIF_IP} \
    sudo bifrost-ansible \
      ${XCI_ANSIBLE_VERBOSE} \
      -i inventory/target \
      -e staging_drivers_include=true \
      install.yaml
fi
#-------------------------------------------------------------------------------
# Enroll and Deploy nodes (using official doc way)
#  - run official enroll.yml
#  - run official deploy.yml
#-------------------------------------------------------------------------------
if [[ $labels = *"deploy"* ]]; then
  step_banner "Bifrost post install customization"
  ansible-playbook \
    -i ${XCI_ROOT}/${POD_NAME}/etc/ansible/opnfv_host_inventory \
    -t post_install \
    ${XCI_RUN_ROOT}/opnfv-nodes-deploy.yml

  step_banner "Enroll nodes"
  ssh ${OPNFV_USER}@${XCI_BIF_IP} \
    sudo bifrost-ansible \
      ${XCI_ANSIBLE_VERBOSE} \
      -i inventory/bifrost_inventory.py \
      enroll-dynamic.yaml

  # As VBMC or libvirt does not seems to like bifrost multiple deploy
  # we send them sequentialy
  step_banner "Deploy nodes"
  for invt in $(ls ${XCI_ROOT}/${POD_NAME}/etc/bifrost/bifrost_inventory_*  |\
                sed -r 's/^.+\///' | sed -r 's/\.yml//'); do
    ssh ${OPNFV_USER}@${XCI_BIF_IP} "\
      export INVENTORY_NAME=${invt}; \
      sudo -E bifrost-ansible \
        ${XCI_ANSIBLE_VERBOSE} \
        -i inventory/bifrost_inventory.py \
        deploy-dynamic.yaml"
  done
#-------------------------------------------------------------------------------
# Wait for servers
#-------------------------------------------------------------------------------
  step_banner "Wait for servers to be deployed"
  ansible all -m wait_for_connection \
    -a 'timeout=900 delay=30' \
    -i ${XCI_ROOT}/${POD_NAME}/etc/ansible/vim_inventory
fi


if [[ $labels = *"post"* ]]; then
#-------------------------------------------------------------------------------
# Sanitize servers
#-------------------------------------------------------------------------------
  step_banner "Sanitize servers"
  ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
    -i ${XCI_ROOT}/${POD_NAME}/etc/ansible/vim_inventory \
    ${XCI_RUN_ROOT}/opnfv-nodes-prepare.yml

#-------------------------------------------------------------------------------
# Set the network on servers
#-------------------------------------------------------------------------------
  step_banner "Set the network on servers"
  ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
    -i ${XCI_ROOT}/${POD_NAME}/etc/ansible/vim_inventory \
    ${XCI_RUN_ROOT}/opnfv-nodes-network.yml

#-------------------------------------------------------------------------------
# Job done
#-------------------------------------------------------------------------------
  step_banner "Servers deployed"
fi
