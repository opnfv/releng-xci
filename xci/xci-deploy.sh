#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

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
# source helpers library
source ${XCI_PATH}/xci/files/xci-lib.sh

# Make sure we pass XCI_PATH everywhere
export XCI_ANSIBLE_PARAMS+=" -e xci_path=${XCI_PATH}"
# Make sure everybody knows where our global roles are
export ANSIBLE_ROLES_PATH="$HOME/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles:${XCI_PATH}/xci/playbooks/roles"

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

#
# Parse command line options
#
parse_cmdline_opts $*

#
# Bootstrap environment for XCI Deployment
#
echo "Info: Preparing host environment for the XCI deployment"
echo "-------------------------------------------------------------------------"
bootstrap_xci_env

# register our handler
trap exit_trap ERR

# We are using sudo so we need to make sure that env_reset is not present
sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers

#-------------------------------------------------------------------------------
# Clean up environment
#-------------------------------------------------------------------------------
echo "Info: Cleaning up previous XCI artifacts"
echo "-------------------------------------------------------------------------"
sudo -E bash files/xci-destroy-env.sh
echo "-------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Install ansible on localhost
#-------------------------------------------------------------------------------
echo "Info: Installing Ansible from pip"
echo "-------------------------------------------------------------------------"
install_ansible
echo "-------------------------------------------------------------------------"

# Clone OPNFV scenario repositories
#-------------------------------------------------------------------------------
# This playbook
# - removes existing scenario roles
# - clones OPNFV scenario roles based on the xci/opnfv-scenario-requirements.yml file
#-------------------------------------------------------------------------------
echo "Info: Cloning OPNFV scenario repositories"
echo "-------------------------------------------------------------------------"
cd $XCI_PATH/xci/playbooks
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i "localhost," get-opnfv-scenario-requirements.yml
echo "-------------------------------------------------------------------------"

# TESTING virbr0
ovs-vsctl show || echo "NEIN"
brctl show || echo "NEIN2"
ip a


#-------------------------------------------------------------------------------
# Check playbooks using ansible-lint
#-------------------------------------------------------------------------------
echo "Info: Verifying XCI playbooks using ansible-lint"
echo "-------------------------------------------------------------------------"
ansible_lint
echo "-------------------------------------------------------------------------"

# Get scenario variables overrides
#-------------------------------------------------------------------------------
source $(find $XCI_SCENARIOS_CACHE/${DEPLOY_SCENARIO} -name xci_overrides) &>/dev/null &&
    echo "Sourced ${DEPLOY_SCENARIO} overrides files successfully!" || :

#-------------------------------------------------------------------------------
# Log info to console
#-------------------------------------------------------------------------------
log_xci_information

# Deploy infrastructure based on the selected deloyment method
echo "Info: Deploying hardware using '${INFRA_DEPLOYMENT}'"
echo "---------------------------------------------------"
source ${XCI_PATH}/xci/infra/${INFRA_DEPLOYMENT}/infra-provision.sh

# Deploy OpenStack on the selected installer
echo "Info: Deploying '${INSTALLER_TYPE}' installer"
echo "-----------------------------------------------------------------------"
source ${XCI_PATH}/xci/installer/${INSTALLER_TYPE}/deploy.sh

# Reset trap
trap ERR

# Deployment time
xci_deploy_time=$SECONDS
echo "-------------------------------------------------------------------------------------------------------------"
echo "Info: xci_deploy.sh deployment took $(($xci_deploy_time / 60)) minutes and $(($xci_deploy_time % 60)) seconds"
echo "-------------------------------------------------------------------------------------------------------------"

collect_xci_logs

# vim: set ts=4 sw=4 expandtab:
