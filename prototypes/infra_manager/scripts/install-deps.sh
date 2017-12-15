#!/bin/bash
# NOTE(david_orange): Most parts of this this file were taken from the
# bifrost repository (scripts/install-deps.sh). This script contains all
# the necessary distro specific code to install jq and yq.

set -eu

declare -A PKG_MAP

CHECK_CMD_PKGS=(
    libffi
    libopenssl
    net-tools
    python-devel
)

source /etc/os-release || source /usr/lib/os-release

case ${ID,,} in
    *suse)
        OS_FAMILY="Suse"
        INSTALLER_CMD="sudo -H -E zypper install -y"
        CHECK_CMD="zypper search --match-exact --installed"
        PKG_MAP=(
            [jq]=jq
            [python]=python
            [python-devel]=python-devel
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
        INSTALLER_CMD="sudo -H -E apt-get -y install"
        CHECK_CMD="dpkg -l"
        PKG_MAP=(
            [jq]=jq
            [python]=python-minimal
            [python-devel]=libpython-dev
        )
        EXTRA_PKG_DEPS=()
        sudo apt-get update
    ;;

    rhel|centos|fedora)
        OS_FAMILY="RedHat"
        PKG_MANAGER=$(which dnf || which yum)
        INSTALLER_CMD="sudo -H -E ${PKG_MANAGER} -y install"
        CHECK_CMD="rpm -q"
        PKG_MAP=(
            [jq]=jq
            [python]=python
            [python-devel]=python-devel
        )
        sudo yum updateinfo
        EXTRA_PKG_DEPS=()
    ;;

    *)
        echo "ERROR: Supported package manager not found.
              Supported: apt,yum,zypper"
        exit 1
    ;;
esac

if ! $(jq --version &>/dev/null); then
    ${INSTALLER_CMD} ${PKG_MAP[jq]}
fi

if ! $(python --version &>/dev/null); then
    ${INSTALLER_CMD} ${PKG_MAP[python]}
fi

# If we're using a venv, we need to work around sudo not
# keeping the path even with -E.
PYTHON=$(which python)

# To install python packages, we need pip.
#
# We can't use the apt packaged version of pip since
# older versions of pip are incompatible with
# requests, one of our indirect dependencies (bug 1459947).
#
# Note(cinerama): We use pip to install an updated pip plus our
# other python requirements. pip breakages can seriously impact us,
# so we've chosen to install/upgrade pip here rather than in
# requirements (which are synced automatically from the global ones)
# so we can quickly and easily adjust version parameters.
# See bug 1536627.
#
# Note(cinerama): If pip is linked to pip3, the rest of the install
# won't work. Remove the alternatives. This is due to ansible's
# python 2.x requirement.
if [[ $(readlink -f /etc/alternatives/pip) =~ "pip3" ]]; then
    sudo -H update-alternatives --remove pip $(readlink -f /etc/alternatives/pip)
fi

if ! which pip; then
    wget -O /tmp/get-pip.py https://bootstrap.pypa.io/get-pip.py
    sudo -H -E ${PYTHON} /tmp/get-pip.py
fi

PIP=$(which pip)

${PIP} install --user "pip>6.0"
${PIP} install --user --upgrade yq
