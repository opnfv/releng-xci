#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

unset XCI_ANSIBLE_PIP_VERSION
./servers-prepare.sh
./nodes-deploy.sh
# Ensure vars used by infra_manager did not erase traditionnal vars
source $XCI_PATH/xci/config/env-vars
bash $XCI_PATH/xci/files/install-ansible.sh
