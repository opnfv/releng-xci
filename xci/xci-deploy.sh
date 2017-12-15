#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

submit_bug_report() {
    cd ${XCI_PATH}
    echo ""
    echo "-------------------------------------------------------------------------"
    echo "Oh nooooo! The XCI deployment failed miserably :-("
    echo ""
    echo "If you need help, please choose one of the following options"
    echo "* #opnfv-pharos @ freenode network"
    echo "* opnfv-tech-discuss mailing list (https://lists.opnfv.org/mailman/listinfo/opnfv-tech-discuss)"
    echo "  - Please prefix the subject with [XCI]"
    echo "* https://jira.opnfv.org (Release Engineering project)"
    echo ""
    echo "Do not forget to submit the following information on your bug report:"
    echo ""
    git diff --quiet && echo "releng-xci tree status: clean" || echo "releng-xci tree status: local modifications"
    echo "opnfv/releng-xci version: $(git rev-parse HEAD)"
    echo "openstack/bifrost version: $OPENSTACK_BIFROST_VERSION"
    echo "openstack/openstack-ansible version: $OPENSTACK_OSA_VERSION"
    echo "xci flavor: $XCI_FLAVOR"
    echo "xci nfvi: $XCI_NFVI"
    echo "Environment variables:"
    env | grep --color=never '\(OPNFV\|XCI\|OPENSTACK\)'
    echo "-------------------------------------------------------------------------"
}

#-------------------------------------------------------------------------------
# This script should not be run as root
#-------------------------------------------------------------------------------
if [[ $(whoami) == "root" ]]; then
    echo "WARNING: This script should not be run as root!"
    echo "Elevated privileges are aquired automatically when necessary"
    echo "Waiting 10s to give you a chance to stop the script (Ctrl-C)"
    for x in $(seq 10 -1 1); do echo -n "$x..."; sleep 1; done
fi

#-------------------------------------------------------------------------------
# Set environment variables
#-------------------------------------------------------------------------------
# The order of sourcing the variable files is significant so please do not
# change it or things might stop working.
# - user-vars: variables that can be configured or overriden by user.
# - pinned-versions: versions to checkout. These can be overriden if you want to
#   use different/more recent versions of the tools but you might end up using
#   something that is not verified by OPNFV XCI.
# - flavor-vars: settings for VM nodes for the chosen flavor.
# - env-vars: variables for the xci itself and you should not need to change or
#   override any of them.
#-------------------------------------------------------------------------------
# find where are we
export XCI_PATH="$(git rev-parse --show-toplevel)"
# source user vars
source $XCI_PATH/xci/config/user-vars
# source pinned versions
source $XCI_PATH/xci/config/pinned-versions
# source flavor configuration
source "$XCI_PATH/xci/config/${XCI_FLAVOR}-vars"
# source NFVI configuration
source "$XCI_PATH/xci/nfvi/${XCI_NFVI}/env" &>/dev/null || true
# source xci configuration
source $XCI_PATH/xci/config/env-vars

if [[ -z $(echo $PATH | grep "$HOME/.local/bin")  ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

#-------------------------------------------------------------------------------
# Sanitize local development environment variables
#-------------------------------------------------------------------------------
user_local_dev_vars=(OPENSTACK_OSA_DEV_PATH OPENSTACK_BIFROST_DEV_PATH)
for local_user_var in ${user_local_dev_vars[@]}; do
    [[ -n ${!local_user_var:-} ]] && export $local_user_var=${!local_user_var%/}/
done
unset user_local_dev_vars local_user_var

# register our handler
trap submit_bug_report ERR

#-------------------------------------------------------------------------------
# Log info to console
#-------------------------------------------------------------------------------
echo "Info: Starting XCI Deployment"
echo "Info: Deployment parameters"
echo "-------------------------------------------------------------------------"
echo "xci flavor: $XCI_FLAVOR"
echo "xci nfvi: $XCI_NFVI"
echo "opnfv/releng-xci version: $(git rev-parse HEAD)"
echo "openstack/bifrost version: $OPENSTACK_BIFROST_VERSION"
echo "openstack/openstack-ansible version: $OPENSTACK_OSA_VERSION"
echo "OPNFV scenario: $OPNFV_SCENARIO"
echo "-------------------------------------------------------------------------"

# Make the VMs match the host. If we need to make this configurable
# then this logic has to be moved outside this file
source /etc/os-release || source /usr/lib/os-release
OS_FAMILY=${OS_FAMILY:-$ID}
case ${OS_FAMILY,,} in
    # These should ideally match the CI jobs
    ubuntu|debian)
        export OS_FAMILY="Debian"
        # Set ansible version to 2.4
        # (not compatible with 2.3 - import_tasks - let see if i need to work
        # on downgrade to 2.3
        XCI_ANSIBLE_PIP_VERSION=2.4.2.0
        $XCI_PATH/infra_manager/servers-prepare.sh
        $XCI_PATH/infra_manager/nodes-deploy.sh
        # Ensure vars used by infra_manager did not erase traditionnal vars
        source $XCI_PATH/xci/config/env-vars
        ;;
    rhel|fedora|centos)
        OS_FAMILY="RedHat"
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-7}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-centos-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        ;;
    *suse)
        export OS_FAMILY="Suse"
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-42.3}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-opensuse-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        ;;
    *) echo "ERROR: unsupported OS '$OS_FAMILY'"; exit 1;;
esac

# There is no CentOS support at all
if [[ $OS_FAMILY == RedHat ]]; then
    echo ""
    echo "Error: Sorry, only Ubuntu and SUSE hosts are supported for now!"
    echo "Error: CentOS 7 support is still work in progress."
    echo ""
    exit 1
fi
# David_Orange - moved after case to erase the ansible used by infra_manager
#-------------------------------------------------------------------------------
# Install ansible on localhost
#-------------------------------------------------------------------------------
echo "Info: Installing Ansible from pip"
echo "-------------------------------------------------------------------------"
source file/install-ansible.sh
echo "-------------------------------------------------------------------------"

# Clone OPNFV scenario repositories
#-------------------------------------------------------------------------------
# This playbook
# - removes existing scenario roles
# - clones OPNFV scenario roles based on the file/opnfv-scenario-requirements.yml file
#-------------------------------------------------------------------------------
echo "Info: Cloning OPNFV scenario repositories"
echo "-------------------------------------------------------------------------"
cd $XCI_PATH/xci/playbooks
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i inventory get-opnfv-scenario-requirements.yml
echo "-------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Get scenario variables overrides
#-------------------------------------------------------------------------------
if [[ -f $XCI_SCENARIOS_CACHE/${OPNFV_SCENARIO:-_no_scenario_}/xci_overrides ]]; then
    source $XCI_SCENARIOS_CACHE/$OPNFV_SCENARIO/xci_overrides
fi

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
case ${OS_FAMILY,,} in
    # These should ideally match the CI jobs
    RedHat|Suse)
      echo "Info: Starting provisining VM nodes using openstack/bifrost"
      echo "-------------------------------------------------------------------------"
      # We are using sudo so we need to make sure that env_reset is not present
      sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers
      cd $XCI_PATH/bifrost/
      sudo -E bash ./scripts/destroy-env.sh
      cd $XCI_PLAYBOOKS
      ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i inventory provision-vm-nodes.yml
      cd ${XCI_CACHE}/repos/bifrost
      bash ./scripts/bifrost-provision.sh
      echo "-----------------------------------------------------------------------"
      echo "Info: VM nodes are provisioned!"
      ;;
esac
#-------------------------------------------------------------------------------
# Configure localhost
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci repository
# - creates log directory
# - copies flavor files such as playbook, inventory, and var file
#-------------------------------------------------------------------------------

echo "Info: Configuring localhost for openstack-ansible"
echo "-----------------------------------------------------------------------"
cd $XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i inventory configure-localhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured localhost host for openstack-ansible"

#-------------------------------------------------------------------------------
# Configure openstack-ansible deployment host, opnfv
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci and openstack/openstack-ansible repositories
# - configures network
# - generates/prepares ssh keys
# - bootstraps ansible
# - copies flavor files to be used by openstack-ansible
#-------------------------------------------------------------------------------
echo "Info: Configuring opnfv deployment host for openstack-ansible"
echo "-----------------------------------------------------------------------"
cd $XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory \
    configure-opnfvhost.yml
echo "-----------------------------------------------------------------------"
echo "Info: Configured opnfv deployment host for openstack-ansible"

#-------------------------------------------------------------------------------
# Configure target hosts for openstack-ansible
#-------------------------------------------------------------------------------
# This playbook is only run for the all flavors except aio since aio is configured
# by an upstream script.

# This playbook
# - adds public keys to target hosts
# - configures network
# - configures nfs
#-------------------------------------------------------------------------------
if [[ $XCI_FLAVOR != "aio" ]]; then
    echo "Info: Configuring target hosts for openstack-ansible"
    echo "-----------------------------------------------------------------------"
    cd $XCI_PLAYBOOKS
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i ${XCI_FLAVOR_ANSIBLE_FILE_PATH}/inventory \
        configure-targethosts.yml
    echo "-----------------------------------------------------------------------"
    echo "Info: Configured target hosts"
fi

#-------------------------------------------------------------------------------
# Set up target hosts for openstack-ansible
#-------------------------------------------------------------------------------
# This is openstack-ansible playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Setting up target hosts for openstack-ansible"
>>>>>>> 2f89acd... stabilization - XCI integration
echo "-----------------------------------------------------------------------"

# Deploy OpenStack on the selected NFVI
echo "Info: Deploying '${XCI_NFVI}' NFVI"
echo "-----------------------------------------------------------------------"
source ${XCI_PATH}/xci/nfvi/${XCI_NFVI}/nfvi-deploy.sh

# vim: set ts=4 sw=4 expandtab:
