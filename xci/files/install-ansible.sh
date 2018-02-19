#!/bin/bash
# NOTE(hwoarang): Most parts of this this file were taken from the
# bifrost repository (scripts/install-deps.sh). This script contains all
# the necessary distro specific code to install ansible and it's dependencies.

set -eu

declare -A PKG_MAP

# workaround: for latest bindep to work, it needs to use en_US local
export LANG=c

CHECK_CMD_PKGS=(
    gcc
    libffi
    libopenssl
    lsb-release
    make
    moreutils
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
        [moreutils]=moreutils
        [net-tools]=net-tools
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
        [moreutils]=moreutils
        [net-tools]=net-tools
        [python]=python-minimal
        [python-devel]=libpython-dev
        [venv]=python-virtualenv
        [wget]=wget
    )
    EXTRA_PKG_DEPS=()
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
        [moreutils]=moreutils
        [net-tools]=net-tools
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

if ! $(python --version &>/dev/null); then
    ${INSTALLER_CMD} ${PKG_MAP[python]}
fi
if ! $(gcc -v &>/dev/null); then
    ${INSTALLER_CMD} ${PKG_MAP[gcc]}
fi
if ! $(wget --version &>/dev/null); then
    ${INSTALLER_CMD} ${PKG_MAP[wget]}
fi

if ! $(python -m virtualenv --version &>/dev/null); then
    ${INSTALLER_CMD} ${PKG_MAP[venv]}
fi

for pkg in ${CHECK_CMD_PKGS[@]}; do
    if ! $(${CHECK_CMD} ${PKG_MAP[$pkg]} &>/dev/null); then
        ${INSTALLER_CMD} ${PKG_MAP[$pkg]}
    fi
done

if [ -n "${EXTRA_PKG_DEPS-}" ]; then
    for pkg in ${EXTRA_PKG_DEPS}; do
        if ! $(${CHECK_CMD} ${pkg} &>/dev/null); then
            ${INSTALLER_CMD} ${pkg}
        fi
    done
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
echo "Using pip: $(${PIP} --version)"
sudo -H -E ${PIP} -q install --upgrade virtualenv
sudo -H -E ${PIP} -q install --upgrade pip
# upgrade setuptools, as latest version is needed to install some projects
sudo -H -E ${PIP} -q install --upgrade setuptools
${PIP} install -q --user --upgrade ansible==$XCI_ANSIBLE_PIP_VERSION
