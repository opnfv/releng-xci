#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export ANSIBLE_STDOUT_CALLBACK=debug
export LAB=$1
export POD=$2

#-------------------------------------------------------------------------------
# Check run as root
#-------------------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit -1
fi

echo "
#-------------------------------------------------------------------------------
# cleanup local vars
#-------------------------------------------------------------------------------
"
# Clean OS envvars
for var in $(export |cut -d\  -f3| cut -d= -f1| grep '^OS_'); do
    unset var;
    export ${var}=''
done

echo "
#-------------------------------------------------------------------------------
# install ansible
#-------------------------------------------------------------------------------
"
# remove old ansible
if test $(pip freeze|grep ansible); then
    pip uninstall -y ansible
fi
# remove folders
rm -rf /usr/local/bin/ansible*
rm -rf /etc/ansible/
# install ansible from package
apt update
apt install -y software-properties-common python-setuptools \
    python-dev libffi-dev libssl-dev git python-pip
pip install --upgrade pip cryptography ansible netaddr
mkdir -p /etc/ansible
echo "jumphost ansible_connection=local" > /etc/ansible/hosts

cd /opt/bosa
echo "
#-------------------------------------------------------------------------------
# Cleanup previous install and prepare jumphost
#-------------------------------------------------------------------------------
"
ansible-playbook opnfv-jumphost.yaml

echo "
#-------------------------------------------------------------------------------
# Setup and run Bifrost
#-------------------------------------------------------------------------------
"
ansible-playbook opnfv-bifrost.yaml

echo "
#-------------------------------------------------------------------------------
# Prepare nodes
#-------------------------------------------------------------------------------
"
ansible-playbook -i /etc/bosa/ansible_inventory opnfv-nodes-prepare.yaml

echo "
#-------------------------------------------------------------------------------
# Prepare OSA
#-------------------------------------------------------------------------------
"
ansible-playbook opnfv-osa-prepare.yaml
/opt/openstack-ansible/scripts/bootstrap-ansible.sh
ansible-playbook opnfv-osa-configure.yaml

echo "
#-------------------------------------------------------------------------------
# Run OSA
#-------------------------------------------------------------------------------
"
cd /opt/openstack-ansible/playbooks
openstack-ansible setup-hosts.yml
openstack-ansible setup-infrastructure.yml
ansible galera_container -m shell -a \
    "mysql -h localhost -e 'show status like \"%wsrep_cluster_%\";'"
openstack-ansible setup-openstack.yml

echo "
#-------------------------------------------------------------------------------
# Fetch openrc and cert
#-------------------------------------------------------------------------------
"
CNT=$(ssh infra1 lxc-ls |grep utility)
ssh infra1 lxc-attach -n $CNT -- cat /root/openrc > /etc/bosa/openstack_openrc
scp infra1:/etc/ssl/certs/haproxy.cert  /etc/bosa/ca.cert
echo 'export OS_CACERT=/etc/bosa/ca.cert' >>  /etc/bosa/openstack_openrc

echo "
#-------------------------------------------------------------------------------
# Post install
#-------------------------------------------------------------------------------
"
cd /opt/bosa
source /etc/bosa/openstack_openrc
ansible-playbook opnfv-post-install.yaml

URL=$(grep AUTH_URL /etc/bosa/openstack_openrc | perl -pe 's!^.*//(.*):.*!$1!')
PASS=$(grep PASSWORD /etc/bosa/openstack_openrc | perl -pe "s/^.*'(.*)'/\$1/")

echo "
#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
You can now connect to https://${URL}
with login: admin
and password: ${PASS}
"
