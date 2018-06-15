# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#-------------------------------------------------------------------------------
# Start provisioning VM nodes (ONLY FOR DEBUG)
#-------------------------------------------------------------------------------
# This playbook assumes the OPNFV VM is already created, ironic server is started
#  and the /httboot directory already has the deployment_image.qcow2 and the
# ipa image. This playbook reruns the provision of hosts avoiding a lot of tasks
#-------------------------------------------------------------------------------

# DO THE FOLLOWING IN THE OPNFV VM
# * pip install python-openstackclient
# ADD THE FOLLOWING LINES TO openrc
# * export OS_TOKEN=fake-token
# * export OS_URL=http://localhost:6385/
# EXECUTE
# * openstack baremetal node undeploy node1
# * openstack baremetal node undeploy node2

XCI_CACHE=$HOME/releng-xci/.cache
XCI_PATH=$HOME/releng-xci

BIFROST_ROOT_DIR="$(dirname $(realpath ${BASH_SOURCE[0]}))"
export ANSIBLE_ROLES_PATH="$HOME/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles:${XCI_PATH}/xci/playbooks/roles:${XCI_CACHE}/repos/bifrost/playbooks/roles"
export ANSIBLE_LIBRARY="$HOME/.ansible/plugins/modules:/usr/share/ansible/plugins/modules:${XCI_CACHE}/repos/bifrost/playbooks/library"

source ${XCI_CACHE}/repos/bifrost/scripts/bifrost-env.sh

ansible-playbook ${XCI_ANSIBLE_PARAMS} \
    --user=devuser -vvv \
    -i ${XCI_PATH}/xci/playbooks/dynamic_inventory.py \
    -i ${XCI_CACHE}/repos/bifrost/playbooks/inventory/bifrost_inventory.py \
    -e use_cirros=false \
    -e testing_user=root \
    -e test_vm_num_nodes=${NUM_NODES} \
    -e test_vm_cpu='host-model' \
    -e inventory_dhcp=false \
    -e inventory_dhcp_static_ip=false \
    -e enable_inspector=true \
    -e inspect_nodes=true \
    -e download_ipa=false \
    -e create_ipa_image=true \
    -e write_interfaces_file=true \
    -e ipv4_gateway=192.168.122.1 \
    -e wait_timeout=3600 \
    -e enable_keystone=false \
    -e ironicinspector_source_install=true \
    -e ironicinspector_git_branch=${BIFROST_IRONIC_INSPECTOR_VERSION:-master} \
    -e ironicinspectorclient_source_install=true \
    -e ironicinspectorclient_git_branch=${BIFROST_IRONIC_INSPECTOR_CLIENT_VERSION:-master} \
    -e ironicclient_source_install=true \
    -e ironicclient_git_branch=${BIFROST_IRONIC_CLIENT_VERSION:-master} \
    -e ironic_git_branch=${BIFROST_IRONIC_VERSION:-master} \
    -e use_prebuilt_images=${BIFROST_USE_PREBUILT_IMAGES:-false} \
    -e xci_distro=${XCI_DISTRO} \
    -e ironic_url="http://192.168.122.2:6385/" \
    ${BIFROST_ROOT_DIR}/playbooks/opnfv-virtual-debug.yml

echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
