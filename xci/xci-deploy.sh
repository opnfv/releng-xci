#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

submit_bug_report() {
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
XCI_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# source user vars
source $XCI_PATH/config/user-vars
# source pinned versions
source $XCI_PATH/config/pinned-versions
# source flavor configuration
source "$XCI_PATH/config/${XCI_FLAVOR}-vars"
# source xci configuration
source $XCI_PATH/config/env-vars

if [[ -z $(echo $PATH | grep "$HOME/.local/bin")  ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

#-------------------------------------------------------------------------------
# Sanitize local development environment variables
#-------------------------------------------------------------------------------
user_local_dev_vars=(OPNFV_RELENG_DEV_PATH OPENSTACK_OSA_DEV_PATH OPENSTACK_BIFROST_DEV_PATH)
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
echo "opnfv/releng-xci version: $(git rev-parse HEAD)"
echo "openstack/bifrost version: $OPENSTACK_BIFROST_VERSION"
echo "openstack/openstack-ansible version: $OPENSTACK_OSA_VERSION"
echo "-------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Install ansible on localhost
#-------------------------------------------------------------------------------
source file/install-ansible.sh

# Make the VMs match the host. If we need to make this configurable
# then this logic has to be moved outside this file
case ${OS_FAMILY,,} in
    # These should ideally match the CI jobs
    debian)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-xenial}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-ubuntu-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vlan,vim,less,bridge-utils,language-pack-en,iputils-ping,rsyslog,curl,iptables}"
        export EXTRA_DIB_ELEMENTS="${EXTRA_DIB_ELEMENTS:-openssh-server}"
        ;;
    redhat)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-7}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-centos-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        export EXTRA_DIB_ELEMENTS="${EXTRA_DIB_ELEMENTS:-openssh-server}"
        ;;
    suse)
        export DIB_OS_RELEASE="${DIB_OS_RELEASE:-42.3}"
        export DIB_OS_ELEMENT="${DIB_OS_ELEMENT:-opensuse-minimal}"
        export DIB_OS_PACKAGES="${DIB_OS_PACKAGES:-vim,less,bridge-utils,iputils,rsyslog,curl,iptables}"
        export EXTRA_DIB_ELEMENTS="${EXTRA_DIB_ELEMETS:-openssh-server}"
        ;;
esac

# There is no CentOS support at all
if [[ $OS_FAMILY == RedHat ]]; then
    echo ""
    echo "Error: Sorry, only Ubuntu and SUSE hosts are supported for now!"
    echo "Error: CentOS 7 support is still work in progress."
    echo ""
    exit 1
fi

# TODO: The xci playbooks can be put into a playbook which will be done later.

# Clone OPNFV scenario repositories
#-------------------------------------------------------------------------------
# This playbook
# - removes existing scenario roles
# - clones OPNFV scenario roles based on the file/opnfv-scenario-requirements.yml file
#-------------------------------------------------------------------------------
echo "Info: Cloning OPNFV scenario repositories"
echo "-------------------------------------------------------------------------"
cd $XCI_PATH/playbooks
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i inventory get-opnfv-scenario-requirements.yml
echo "-------------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Get scenario variables overrides
#-------------------------------------------------------------------------------
if [[ -f $XCI_PATH/playbooks/scenarios/${OPNFV_SCENARIO:-_no_scenario_}/xci_overrides ]]; then
    source $XCI_PATH/playbooks/scenarios/$OPNFV_SCENARIO/xci_overrides
fi

#-------------------------------------------------------------------------------
# Start provisioning VM nodes
#-------------------------------------------------------------------------------
# This playbook
# - removes directories that were created by the previous xci run
# - clones opnfv/releng-xci and openstack/bifrost repositories
# - combines opnfv/releng-xci and openstack/bifrost scripts/playbooks
# - destorys VMs, removes ironic db, leases, logs
# - creates and provisions VMs for the chosen flavor
#-------------------------------------------------------------------------------
echo "Info: Starting provisining VM nodes using openstack/bifrost"
echo "-------------------------------------------------------------------------"
# We are using sudo so we need to make sure that env_reset is not present
sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers
cd $XCI_PATH/../bifrost/
sudo -E bash ./scripts/destroy-env.sh
cd $XCI_PATH/playbooks
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i inventory provision-vm-nodes.yml
cd ${OPENSTACK_BIFROST_PATH}
bash ./scripts/bifrost-provision.sh
echo "-----------------------------------------------------------------------"
echo "Info: VM nodes are provisioned!"
source $OPENSTACK_BIFROST_PATH/env-vars
ironic node-list
echo
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
cd $XCI_PATH/playbooks
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
cd ${XCI_DEVEL_ROOT}
ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i ${OPNFV_XCI_PATH}/playbooks/inventory ${OPNFV_XCI_PATH}/playbooks/configure-opnfvhost.yml
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
    cd $OPNFV_XCI_PATH/playbooks
    ansible-playbook ${XCI_ANSIBLE_VERBOSITY} -i inventory configure-targethosts.yml
    echo "-----------------------------------------------------------------------"
    echo "Info: Configured target hosts"
fi

#-------------------------------------------------------------------------------
# Set up target hosts for openstack-ansible
#-------------------------------------------------------------------------------
# This is openstack-ansible playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Setting up target hosts for openstack-ansible"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "openstack-ansible ${XCI_ANSIBLE_VERBOSITY} \
     $OPENSTACK_OSA_PATH/playbooks/setup-hosts.yml | tee setup-hosts.log "
scp root@$OPNFV_HOST_IP:~/setup-hosts.log $LOG_PATH/setup-hosts.log
echo "-----------------------------------------------------------------------"
echo "Info: Set up target hosts for openstack-ansible successfuly"

# TODO: Check this with the upstream and issue a fix in the documentation if the
# problem is valid.
#-------------------------------------------------------------------------------
# Gather facts for all the hosts and containers
#-------------------------------------------------------------------------------
# This is needed in order to gather the facts for containers due to a change in
# upstream that changed the hosts fact are gathered which causes failures during
# running setup-infrastructure.yml playbook due to lack of the facts for lxc
# containers.
#
# OSA gate also executes this command. See the link
# http://logs.openstack.org/64/494664/1/check/gate-openstack-ansible-openstack-ansible-aio-ubuntu-xenial/2a0700e/console.html
#-------------------------------------------------------------------------------
echo "Info: Gathering facts"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "cd $OPENSTACK_OSA_PATH/playbooks; \
        ansible ${XCI_ANSIBLE_VERBOSITY} -m setup -a gather_subset=network,hardware,virtual all"
echo "-----------------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Set up infrastructure
#-------------------------------------------------------------------------------
# This is openstack-ansible playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Setting up infrastructure"
echo "-----------------------------------------------------------------------"
echo "xci: running ansible playbook setup-infrastructure.yml"
ssh root@$OPNFV_HOST_IP "openstack-ansible ${XCI_ANSIBLE_VERBOSITY} \
     $OPENSTACK_OSA_PATH/playbooks//setup-infrastructure.yml | tee setup-infrastructure.log"
scp root@$OPNFV_HOST_IP:~/setup-infrastructure.log $LOG_PATH/setup-infrastructure.log
echo "-----------------------------------------------------------------------"
# check the log to see if we have any error
if grep -q 'failed=1\|unreachable=1' $LOG_PATH/setup-infrastructure.log; then
    echo "Error: OpenStack node setup failed!"
    exit 1
fi

#-------------------------------------------------------------------------------
# Verify database cluster
#-------------------------------------------------------------------------------
echo "Info: Verifying database cluster"
echo "-----------------------------------------------------------------------"
# Apply SUSE fix until https://review.openstack.org/508154 is merged
if [[ ${OS_FAMILY,,} == "suse" ]]; then
	ssh root@$OPNFV_HOST_IP "ansible --ssh-extra-args='-o StrictHostKeyChecking=no' \
		-i $OPENSTACK_OSA_PATH/playbooks/inventory/ galera_container -m shell \
		-a \"sed -i \\\"s@/var/run/mysqld/mysqld.sock@/var/run/mysql/mysql.sock@\\\" /etc/my.cnf\""
fi

ssh root@$OPNFV_HOST_IP "ansible --ssh-extra-args='-o StrictHostKeyChecking=no' \
    -i $OPENSTACK_OSA_PATH/playbooks/inventory/ galera_container -m shell \
	-a \"mysql -h localhost -e \\\"show status like '%wsrep_cluster_%';\\\"\" | tee galera.log"
scp root@$OPNFV_HOST_IP:~/galera.log $LOG_PATH/galera.log
echo "-----------------------------------------------------------------------"
# check the log to see if we have any error
if grep -q 'FAILED\|UNREACHABLE' $LOG_PATH/galera.log; then
    echo "Error: Database cluster verification failed!"
    exit 1
fi
echo "Info: Database cluster verification successful!"

#-------------------------------------------------------------------------------
# Install OpenStack
#-------------------------------------------------------------------------------
# This is openstack-ansible playbook. Check upstream documentation for details.
#-------------------------------------------------------------------------------
echo "Info: Installing OpenStack on target hosts"
echo "-----------------------------------------------------------------------"
ssh root@$OPNFV_HOST_IP "openstack-ansible ${XCI_ANSIBLE_VERBOSITY} \
     $OPENSTACK_OSA_PATH/playbooks/setup-openstack.yml | tee opnfv-setup-openstack.log"
scp root@$OPNFV_HOST_IP:~/opnfv-setup-openstack.log $LOG_PATH/opnfv-setup-openstack.log
echo "-----------------------------------------------------------------------"
# check the log to see if we have any error
if grep -q 'failed=1\|unreachable=1' $LOG_PATH/opnfv-setup-openstack.log; then
   echo "Error: OpenStack installation failed!"
   exit 1
fi
echo "Info: OpenStack installation is successfully completed!"

#-------------------------------------------------------------------------------
# - Getting OpenStack login information
#-------------------------------------------------------------------------------
echo "Info: Openstack login details"
echo "-----------------------------------------------------------------------"
OS_USER_CONFIG=$XCI_PATH/file/$XCI_FLAVOR/openstack_user_config.yml
python -c \
"import yaml
if '$XCI_FLAVOR' is 'aio':
   print 'Horizon UI is available at https://192.168.122.2'
else:
   host_info = open('$OS_USER_CONFIG', 'r')
   net_config = yaml.safe_load(host_info)
   print 'Info: Horizon UI is available at https://{}' \
         .format(net_config['global_overrides']['external_lb_vip_address'])"
USERNAME=$(ssh -q root@192.168.122.2 awk "/OS_USERNAME=./" openrc)
PASSWORD=$(ssh -q root@192.168.122.2 awk "/OS_PASSWORD=./" openrc)
echo "Info: Admin username -  ${USERNAME##*=}"
echo "Info: Admin password - ${PASSWORD##*=}"
echo "Info: It is recommended to change the default password."

# vim: set ts=4 sw=4 expandtab:
