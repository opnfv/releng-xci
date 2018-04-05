# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# NOTE(hwoarang): Most parts of this this file were taken from the
# bifrost repository (scripts/install-deps.sh). This script contains all
# the necessary distro specific code to install ansible and it's dependencies.

function install_ansible() {
    set -eu

    # Use the upper-constraints file from the pinned requirements repository.
    local uc="https://raw.githubusercontent.com/openstack/requirements/${OPENSTACK_REQUIREMENTS_VERSION}/upper-constraints.txt"
    local install_map

    declare -A PKG_MAP

    # workaround: for latest bindep to work, it needs to use en_US local
    export LANG=c

    CHECK_CMD_PKGS=(
        gcc
        libffi
        libopenssl
        lsb-release
        make
        net-tools
        python-devel
        python
        venv
        wget
    )

    source /etc/os-release || source /usr/lib/os-release
    case ${ID,,} in
      *suse)
        OS_FAMILY="Suse"
        INSTALLER_CMD="sudo -H -E zypper -q install -y --no-recommends"
        CHECK_CMD="zypper search --match-exact --installed"
        PKG_MAP=(
            [gcc]=gcc
            [libffi]=libffi-devel
            [libopenssl]=libopenssl-devel
            [lsb-release]=lsb-release
            [make]=make
            [net-tools]=net-tools
            [pip]=python-pip
            [python]=python
            [python-devel]=python-devel
            [venv]=python-virtualenv
            [wget]=wget
        )
        EXTRA_PKG_DEPS=( python-xml )
        sudo zypper -n ref
        # NOTE (cinerama): we can't install python without removing this package
        # if it exists
        if $(${CHECK_CMD} patterns-openSUSE-minimal_base-conflicts &> /dev/null); then
            sudo -H zypper remove -y patterns-openSUSE-minimal_base-conflicts
        fi
        ;;

        ubuntu|debian)
        OS_FAMILY="Debian"
        export DEBIAN_FRONTEND=noninteractive
        INSTALLER_CMD="sudo -H -E apt-get -y -q=3 install"
        CHECK_CMD="dpkg -l"
        PKG_MAP=(
            [gcc]=gcc
            [libffi]=libffi-dev
            [libopenssl]=libssl-dev
            [lsb-release]=lsb-release
            [make]=make
            [net-tools]=net-tools
            [pip]=python-pip
            [python]=python-minimal
            [python-devel]=libpython-dev
            [venv]=python-virtualenv
            [wget]=wget
        )
        EXTRA_PKG_DEPS=( apt-utils )
        sudo apt-get update
        ;;

        rhel|fedora|centos)
        OS_FAMILY="RedHat"
        PKG_MANAGER=$(which dnf || which yum)
        INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -q -y install"
        CHECK_CMD="rpm -q"
        PKG_MAP=(
            [gcc]=gcc
            [libffi]=libffi-devel
            [libopenssl]=openssl-devel
            [lsb-release]=redhat-lsb
            [make]=make
            [net-tools]=net-tools
            [pip]=python2-pip
            [python]=python
            [python-devel]=python-devel
            [venv]=python-virtualenv
            [wget]=wget
        )
        sudo $PKG_MANAGER updateinfo
        EXTRA_PKG_DEPS=( deltarpm )
        ;;

        *) echo "ERROR: Supported package manager not found.  Supported: apt, dnf, yum, zypper"; exit 1;;
    esac

    # Build instllation map
    for pkgmap in ${CHECK_CMD_PKGS[@]}; do
        install_map+=(${PKG_MAP[$pkgmap]} )
    done

    install_map+=(${EXTRA_PKG_DEPS[@]} )

    ${INSTALLER_CMD} ${install_map[@]}

    # Note(cinerama): If pip is linked to pip3, the rest of the install
    # won't work. Remove the alternatives. This is due to ansible's
    # python 2.x requirement.
    if [[ $(readlink -f /etc/alternatives/pip) =~ "pip3" ]]; then
        sudo -H update-alternatives --remove pip $(readlink -f /etc/alternatives/pip)
    fi

    # We need to prepare our virtualenv now
    virtualenv --quiet --no-site-packages ${XCI_VENV}
    set +u
    source ${XCI_VENV}/bin/activate
    set -u

    # We are inside the virtualenv now so we should be good to use pip and python from it.
    pip -q install --upgrade -c $uc ara virtualenv pip setuptools ansible==$XCI_ANSIBLE_PIP_VERSION ansible-lint==3.4.21

    ara_location=$(python -c "import os,ara; print(os.path.dirname(ara.__file__))")
    export ANSIBLE_CALLBACK_PLUGINS="/etc/ansible/roles/plugins/callback:${ara_location}/plugins/callbacks"
}

ansible_lint() {
    set -eu
    # Use the upper-constraints file from the pinned requirements repository.
    local uc="https://raw.githubusercontent.com/openstack/requirements/${OPENSTACK_REQUIREMENTS_VERSION}/upper-constraints.txt"
    local playbooks_dir=(xci/playbooks xci/installer/osa/playbooks xci/installer/kubespray/playbooks)
    # Extract role from scenario information
    local testing_role=$(sed -n "/^- scenario: ${DEPLOY_SCENARIO}/,/^$/p" ${XCI_PATH}/xci/opnfv-scenario-requirements.yml | grep role | rev | cut -d '/' -f -1 | rev)

    # Clone OSA rules too
    git clone --quiet --depth 1 https://github.com/openstack/openstack-ansible-tests.git \
        ${XCI_CACHE}/repos/openstack-ansible-tests

    # Because of https://github.com/willthames/ansible-lint/issues/306, ansible-lint does not understand
    # import and includes yet so we need to trick it with a fake playbook so we can test our roles. We
    # only test the role for the scenario we are testing
    echo "Building testing playbook for role: ${testing_role}"
    cat > ${XCI_PATH}/xci/playbooks/test-playbook.yml << EOF
        - name: Testing playbook
          hosts: localhost
          roles:
            - ${testing_role}
EOF

    # Only check our own playbooks
    for dir in ${playbooks_dir[@]}; do
        for play in $(ls ${XCI_PATH}/${dir}/*.yml); do
            echo -en "Checking '${play}' playbook..."
            ansible-lint --nocolor -R -r \
                ${XCI_CACHE}/repos/openstack-ansible-tests/ansible-lint ${play}
            echo -en "[OK]\n"
        done
    done

    # Remove testing playbook
    rm ${XCI_PATH}/xci/playbooks/test-playbook.yml
}

collect_xci_logs() {
    echo "----------------------------------"
    echo "Info: Collecting XCI logs"
    echo "----------------------------------"

    # Create the ARA log directory and store the sqlite source database
    mkdir -p ${LOG_PATH}/ara/ ${LOG_PATH}/opnfv/ara

    rsync -q -a "${HOME}/.ara/ansible.sqlite" "${LOG_PATH}/ara/"
    rsync -q -a root@${OPNFV_HOST_IP}:releng-xci/${LOG_PATH#$XCI_PATH/}/ ${LOG_PATH}/opnfv/ &> /dev/null || true
    rsync -q -a root@${OPNFV_HOST_IP}:.ara/ansible.sqlite ${LOG_PATH}/opnfv/ara/ &> /dev/null || true

    sudo -H -E bash -c 'chown ${SUDO_UID}:${SUDO_GID} -R ${LOG_PATH}/'
}

# vim: set ts=4 sw=4 expandtab:
