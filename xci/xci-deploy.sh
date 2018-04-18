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
    echo "xci installer: $INSTALLER_TYPE"
    echo "xci scenario: $DEPLOY_SCENARIO"
    echo "Environment variables:"
    env | grep --color=never '\(OPNFV\|XCI\|INSTALLER_TYPE\|OPENSTACK\|SCENARIO\|ANSIBLE\)'
    echo "-------------------------------------------------------------------------"
}

exit_trap() {
    submit_bug_report
    collect_xci_logs
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
# Declare our virtualenv
export XCI_VENV=${XCI_PATH}/venv/
# source user vars
source $XCI_PATH/xci/config/user-vars
# source pinned versions
source $XCI_PATH/xci/config/pinned-versions
# source flavor configuration
source "$XCI_PATH/xci/config/${XCI_FLAVOR}-vars"
# source installer configuration
source "$XCI_PATH/xci/installer/${INSTALLER_TYPE}/env" &>/dev/null || true
# source xci configuration
source $XCI_PATH/xci/config/env-vars
# source helpers library
source ${XCI_PATH}/xci/files/install-lib.sh

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

# register our handler
trap exit_trap ERR

# We are using sudo so we need to make sure that env_reset is not present
sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers

#-------------------------------------------------------------------------------
# Log info to console
#-------------------------------------------------------------------------------
echo "Info: Starting XCI Deployment"
echo "Info: Deployment parameters"
echo "-------------------------------------------------------------------------"
echo "OPNFV scenario: $DEPLOY_SCENARIO"
echo "xci flavor: $XCI_FLAVOR"
echo "xci installer: $INSTALLER_TYPE"
echo "infra deployment: $INFRA_DEPLOYMENT"
echo "opnfv/releng-xci version: $(git rev-parse HEAD)"
[[ "$INFRA_DEPLOYMENT" == "bifrost" ]] && echo "openstack/bifrost version: $OPENSTACK_BIFROST_VERSION"
[[ "$INSTALLER_TYPE" == "osa" ]] && echo "openstack/openstack-ansible version: $OPENSTACK_OSA_VERSION"
[[ "$INSTALLER_TYPE" == "kubespray" ]] && echo "kubespray version: $KUBESPRAY_VERSION"
echo "-------------------------------------------------------------------------"

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

#-------------------------------------------------------------------------------
# Check playbooks using ansible-lint
#-------------------------------------------------------------------------------
echo "Info: Verifying XCI playbooks using ansible-lint"
echo "-------------------------------------------------------------------------"
ansible_lint
echo "-------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Get scenario variables overrides
#-------------------------------------------------------------------------------
source $(find $XCI_PATH/xci/scenarios/${DEPLOY_SCENARIO} -name xci_overrides) &>/dev/null || \
    source $(find $XCI_SCENARIOS_CACHE/${DEPLOY_SCENARIO} -name xci_overrides) &>/dev/null || :

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
