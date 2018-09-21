# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#-------------------------------------------------------------------------------
# Start provisioning VM nodes
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci and openstack/bifrost repositories
# - combines opnfv/releng-xci and openstack/bifrost scripts/playbooks
# - destroys VMs, removes ironic db, leases, logs
# - creates and provisions VMs for the chosen flavor
#-------------------------------------------------------------------------------

BIFROST_ROOT_DIR="$(dirname $(realpath ${BASH_SOURCE[0]}))"
export ANSIBLE_ROLES_PATH="$HOME/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles:${XCI_PATH}/xci/playbooks/roles:${XCI_CACHE}/repos/bifrost/playbooks/roles"
export ANSIBLE_LIBRARY="$HOME/.ansible/plugins/modules:/usr/share/ansible/plugins/modules:${XCI_CACHE}/repos/bifrost/playbooks/library"

echo "Info: Create XCI VM resources"
echo "-------------------------------------------------------------------------"

ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        -i ${XCI_PATH}/xci/playbooks/dynamic_inventory.py \
        -e num_nodes=${NUM_NODES} \
        -e vm_domain_type=${VM_DOMAIN_TYPE} \
        -e baremetal_json_file=/tmp/baremetal.json \
        -e xci_distro=${XCI_DISTRO} \
	-e pdf=${PDF} \
	-e idf=${IDF} \
        ${BIFROST_ROOT_DIR}/playbooks/xci-create-virtual.yml


ansible-playbook ${XCI_ANSIBLE_PARAMS} \
        --private-key=${XCI_PATH}/xci/scripts/vm/id_rsa_for_dib \
        --user=devuser \
        -i ${XCI_PATH}/xci/playbooks/dynamic_inventory.py \
        ${BIFROST_ROOT_DIR}/playbooks/xci-prepare-virtual.yml

source ${XCI_CACHE}/repos/bifrost/scripts/bifrost-env.sh

# This is hardcoded to delegate to localhost but we really need to delegate to opnfv instead.
sed -i "/delegate_to:/d" ${XCI_CACHE}/repos/bifrost/playbooks/roles/bifrost-deploy-nodes-dynamic/tasks/main.yml

ansible-playbook ${XCI_ANSIBLE_PARAMS} \
    --user=devuser \
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
    -e download_ipa=true \
    -e create_ipa_image=false \
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
    ${BIFROST_ROOT_DIR}/playbooks/opnfv-virtual.yml

echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"
