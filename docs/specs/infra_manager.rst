baremetal support for XCI
#################################
:date: 2018-04-25

This spec introduces the work required to deploy XCI using baremetal servers

Definition of Terms
===================
* Baremetal deployment: Deployment on physical servers as opposed to deploying
software on virtual machines or containers running in the same physical server

* PDF: Pod Description File. Document which lists the hardware characteristics
of a set of physical servers which form the infrastructure. Example:

https://github.com/opnfv/releng-xci/blob/master/xci/var/pdf.yml

* IDF: Installer Description File. Document which includes useful information
for the installers to accomplish the baremetal deployment. Example:

https://github.com/opnfv/releng-xci/blob/master/xci/var/idf.yml

Problem description
===================

Currently, XCI can only be deployed in one server. All the nodes created by the
XCI deployment are virtual machines running in that server. This is good when
the user has limited resources, however, baremetal is the preferred way to
deploy NFV platforms in production environments.

Unfortunately, we are not able to deploy XCI baremetal, which limits the scope
of the testing greatly. For example, we cannot test NFV hardware specific
features such as SRIOV.

Proposed change
===============

Introduce the infra_manager tool which will prepare the baremetal infrastructure
to deploy XCI.

The infra_manager tool will consume the IDF/PDF files describing the
infrastructure as input and it will use bifrost to boot the Operating System in
the physical servers. Bifrost is chosen because it is already used in XCI to
do the virtual deployment.

Among other services Bifrost uses:
- Disk image builder (dib) to generate the OS images
- dnsmasq as the DHCP server which will provide the pxe boot mechanism
- ipmitool to manage the servers

Bifrost will be deployed inside a VM in the jumphost.

Code impact
-----------

The new code will be introduced in a new directory called infra_manager under
releng-xci/xci/prototypes

Tentative User guide
--------------------

Assuming the user cloned releng-xci in the jumphost, the following should be
done:

1 - Move the idf/pdf files which describe the infrastructure to
releng-xci/xci/prototypes/infra_manager/var

2 - Export the XCI_FLAVOR variable (e.g. export XCI_FLAVOR=noha)

3 - Run the script that creates the bifrost VM in the jumphost:
releng-xci/xci/prototypes/infra_manager/servers-prepare.sh

4 - Run the script which boots the physical servers
releng-xci/xci/prototypes/infra_manager/nodes-deploy.sh

5 - Run the VIM deployer script:
releng-xci/xci/installer/$inst/deploy.sh

where $inst = {osa, kubespray, kolla}

In case of problems, the best way to debug is accessing the bifrost vm and use:

* bifrost-utils
* ipmitool
* check the DHCP messages in /var/log/syslog


Implementation
==============

Assignee(s)
-----------

Primary assignee:
  Manuel Buil (mbuil)
  Somebody_else_please (niceperson)

Work items
----------

1. Provide support for a dynamically generated inventory based on IDF/PDF. This
mechanism could be used for both baremetal and virtual deployments.

2. Contribute the servers-prepare.sh script

3. Contribute the nodes-deploy.sh script

4. Integrate the three previous components correctly

5. Provide support for the XCI supported operating systems (opensuse, Ubuntu,
centos)
