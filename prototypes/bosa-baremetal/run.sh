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
    exit
fi

#-------------------------------------------------------------------------------
# Check config source
#-------------------------------------------------------------------------------

if [ ! -f config_sources/labs/$LAB/$POD.yaml ]; then
    echo "No PDF file (config_sources/labs/$LAB/$POD.yaml)" 1>&2
    exit
else
    cp config_sources/labs/$LAB/$POD.yaml vars/pdf.yaml
fi
if [ ! -f config_sources/labs/$LAB/idf-$POD.yaml ]; then
    echo "No IDF file (config_sources/labs/$LAB/idf-$POD.yaml)" 1>&2
    exit
else
    cp config_sources/labs/$LAB/idf-$POD.yaml vars/idf.yaml
fi

echo "
#-------------------------------------------------------------------------------
# cleanup
#-------------------------------------------------------------------------------
"

# purge ironic DB
MPWD=$(grep ironic_db_password: vars/defaults.yaml | cut -d\  -f2)
mysql -uironic -p${MPWD} -e "show databases" | \
        grep -v Database | \
        grep -v mysql| \
        grep -v information_schema| \
        gawk '{print "drop database " $1 ";select sleep(0.1);"}' | \
        mysql -uironic -p${MPWD} || true
# remove old ansible
if test $(pip freeze|grep ansible); then
    pip uninstall -y ansible
fi
# remove folders
rm -rf /usr/local/bin/ansible*
rm -rf /usr/local/bin/bifrost*
rm -rf /opt/ansible-runtime/
rm -rf /opt/bifrost/
rm -rf /opt/openstack-ansible/
rm -rf /opt/stack/
rm -rf /etc/bosa/
# Clean OS envvars
for var in $(export |cut -d\  -f3| cut -d= -f1| grep '^OS_'); do
    unset var;
done

echo "
#-------------------------------------------------------------------------------
# install ansible
#-------------------------------------------------------------------------------
"
apt update
apt install -y software-properties-common python-setuptools \
    python-dev libffi-dev libssl-dev git sshpass tree python-pip
pip install --upgrade pip
pip install cryptography
pip install ansible
pip install netaddr
mkdir -p /etc/ansible
echo "jumphost ansible_connection=local" > /etc/ansible/hosts

echo "
#-------------------------------------------------------------------------------
# Setup and run Bifrost
#-------------------------------------------------------------------------------
"
cd /opt/bosa
ansible-playbook opnfv-bifrost-install.yaml
ansible-playbook opnfv-bifrost-enroll-deploy.yaml

echo "
#-------------------------------------------------------------------------------
# Prepare nodes
#-------------------------------------------------------------------------------
"
ansible-playbook -i /etc/bosa/ansible_inventory opnfv-wait-for-nodes.yaml
ansible-playbook -i /etc/bosa/ansible_inventory opnfv-prepare-nodes.yaml

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
# Prepare Infra
#-------------------------------------------------------------------------------
"
cd /opt/bosa
source /etc/bosa/openstack_openrc
ansible-playbook opnfv-openstack-prepare.yaml

echo "
#-------------------------------------------------------------------------------
# End
#-------------------------------------------------------------------------------
"
