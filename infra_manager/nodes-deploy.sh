#!/bin/bash
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
# Prepare and install Bifrost (using official doc way)
#  - prepare Bifrost source and config
#  - run env-setup
#  - run official install.yml
#-------------------------------------------------------------------------------
# step_banner "Prepare and configure Bifrost"
ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
  -i ${XCI_ROOT}/${POD_NAME}/etc/opnfv_hosts_inventory.yml \
  ${XCI_RUN_ROOT}/opnfv-opnfv_host-prepare.yml
ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
  -i ${XCI_ROOT}/${POD_NAME}/etc/opnfv_hosts_inventory.yml \
  -t prepare \
  -t sync \
  ${XCI_RUN_ROOT}/opnfv-nodes-deploy.yml
# get bifrost server ip
export XCI_BIF_IP=$(cat ${XCI_ROOT}/${POD_NAME}/etc/opnfv_hosts_inventory.yml |\
                    yq -r .all.hosts.opnfv_host.ansible_host)
ssh ${OPNFV_USER}@${XCI_BIF_IP} \
  sudo bifrost-ansible \
    ${XCI_ANSIBLE_VERBOSE} \
    -i inventory/target \
    -e staging_drivers_include=true \
    install.yaml

#-------------------------------------------------------------------------------
# Enroll and Deploy nodes (using official doc way)
#  - run official enroll.yml
#  - run official deploy.yml
#-------------------------------------------------------------------------------
step_banner "Enroll and deploy nodes"
ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
  -i ${XCI_ROOT}/${POD_NAME}/etc/opnfv_hosts_inventory.yml \
  -t post_install \
  ${XCI_RUN_ROOT}/opnfv-nodes-deploy.yml
ssh ${OPNFV_USER}@${XCI_BIF_IP} \
  sudo bifrost-ansible \
    ${XCI_ANSIBLE_VERBOSE} \
    -i inventory/bifrost_inventory.py \
    enroll-dynamic.yaml
ssh ${OPNFV_USER}@${XCI_BIF_IP} \
  sudo bifrost-ansible \
    ${XCI_ANSIBLE_VERBOSE} \
    -i inventory/bifrost_inventory.py \
    deploy-dynamic.yaml

#-------------------------------------------------------------------------------
# Wait for servers
#-------------------------------------------------------------------------------
step_banner "Wait for servers to be deployed"
ansible all -m wait_for_connection \
  -i ${XCI_ROOT}/${POD_NAME}/etc/vim_inventory.yml

#-------------------------------------------------------------------------------
# Wait for servers
#-------------------------------------------------------------------------------
step_banner "Sanitize servers"
ansible-playbook ${XCI_ANSIBLE_VERBOSE} \
  -i ${XCI_ROOT}/${POD_NAME}/etc/vim_inventory.yml \
  ${XCI_RUN_ROOT}/opnfv-nodes-prepare.yml

#-------------------------------------------------------------------------------
# Job done
#-------------------------------------------------------------------------------
step_banner "Servers deployed"
