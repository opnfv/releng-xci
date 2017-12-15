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

export XCI_ANSIBLE_PIP_VERSION=${XCI_ANSIBLE_PIP_VERSION:-2.4.2.0}
export XCI_ANSIBLE_VERBOSE=${XCI_ANSIBLE_VERBOSE:--vvv}

##
# Ensure local bin folder is in the PATH
##
if [[ -z $(echo ${PATH} | grep "${HOME}/.local/bin")  ]]; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi

##
# Import config from yaml files
##
export XCI_ROOT=$(cat ${XCI_RUN_ROOT}/var/opnfv.yml | yq -r .xci_root)
export POD_NAME=$(cat ${XCI_RUN_ROOT}/var/idf.yml | yq -r .idf.xci.pod_name)
export OPNFV_USER=$(cat ${XCI_RUN_ROOT}/var/opnfv.yml | yq -r .opnfv_user)
