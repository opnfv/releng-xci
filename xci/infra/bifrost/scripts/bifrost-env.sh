#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2016 Ericsson AB and others.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# dib configuration
case ${XCI_DISTRO,,} in
    # These should ideally match the CI jobs
    ubuntu)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-xenial}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-ubuntu-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vlan,vim,less,bridge-utils,language-pack-en,iputils-ping,rsyslog,curl,iptables}"
        ;;
    centos)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-7}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-centos-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        ;;
    opensuse)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-42.3}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-opensuse-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        ;;
esac

export BIFROST_INVENTORY_SOURCE=/tmp/baremetal.json

grep -o vendor.* opnfv_vm_pdf.yml | grep -q libvirt && export BAREMETAL=true || export BAREMETAL=false

pip install -q --upgrade -r "${XCI_CACHE}/repos/bifrost/requirements.txt"
