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
    echo "xci installer: $XCI_INSTALLER"
    echo "xci scenario: $DEPLOY_SCENARIO"
    echo "Environment variables:"
    env | grep --color=never '\(OPNFV\|XCI\|OPENSTACK\|SCENARIO\)'
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
# source installer configuration
source "$XCI_PATH/xci/installer/${XCI_INSTALLER}/env" &>/dev/null || true
# source xci configuration
source $XCI_PATH/xci/config/env-vars
# Make sure we pass XCI_PATH everywhere
export XCI_ANSIBLE_PARAMS+=" -e XCI_PATH=${XCI_PATH}"

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
echo "xci installer: $XCI_INSTALLER"
echo "opnfv/releng-xci version: $(git rev-parse HEAD)"
echo "openstack/bifrost version: $OPENSTACK_BIFROST_VERSION"
echo "openstack/openstack-ansible version: $OPENSTACK_OSA_VERSION"
echo "OPNFV scenario: $DEPLOY_SCENARIO"
echo "-------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Install ansible on localhost
#-------------------------------------------------------------------------------
echo "Info: Installing Ansible from pip"
echo "-------------------------------------------------------------------------"
bash files/install-ansible.sh
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
# Get scenario variables overrides
#-------------------------------------------------------------------------------
source $(find $XCI_SCENARIOS_CACHE/${DEPLOY_SCENARIO} -name xci_overrides) &>/dev/null || :

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
echo "Info: Starting provisining VM nodes using openstack/bifrost"
echo "-------------------------------------------------------------------------"
# We are using sudo so we need to make sure that env_reset is not present
sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers
cd $XCI_PATH/bifrost/
sudo -E bash ./scripts/destroy-env.sh
cd $XCI_PLAYBOOKS
ansible-playbook ${XCI_ANSIBLE_PARAMS} -i "localhost," bootstrap-bifrost.yml
cd ${XCI_CACHE}/repos/bifrost
bash ./scripts/bifrost-provision.sh
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
echo "-----------------------------------------------------------------------"

# Deploy OpenStack on the selected installer
echo "Info: Deploying '${XCI_INSTALLER}' installer"
echo "-----------------------------------------------------------------------"
source ${XCI_PATH}/xci/installer/${XCI_INSTALLER}/deploy.sh

# Deployment time
xci_deploy_time=$SECONDS
echo "-------------------------------------------------------------------------------------------------------------"
echo "Info: xci_deploy.sh deployment took $(($xci_deploy_time / 60)) minutes and $(($xci_deploy_time % 60)) seconds"
echo "-------------------------------------------------------------------------------------------------------------"

# vim: set ts=4 sw=4 expandtab:
