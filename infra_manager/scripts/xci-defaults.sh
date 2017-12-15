#!/bin/bash

export XCI_ANSIBLE_PIP_VERSION=${XCI_ANSIBLE_PIP_VERSION:-2.4.2.0}
export XCI_ANSIBLE_VERBOSE=${XCI_ANSIBLE_VERBOSE:--vvv}

# To be removed when compatible with others
export OS_FAMILY=debian

##
# Import config from yaml files
##
export XCI_ROOT=$(cat ${XCI_RUN_ROOT}/var/opnfv.yml | yq -r .xci_root)
export POD_NAME=$(cat ${XCI_RUN_ROOT}/var/idf.yml | yq -r .idf.xci.pod_name)
export OPNFV_USER=$(cat ${XCI_RUN_ROOT}/var/opnfv.yml | yq -r .opnfv_user)

##
# Ensure local bin folder is in the PATH
##
if [[ -z $(echo ${PATH} | grep "${HOME}/.local/bin")  ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
    export PATH="${XCI_PATH}/${POD_NAME}/bin:$PATH"
fi
