PDF and IDF support in XCI
###########################
:date: 2018-04-30

This spec introduces the work required to adapt XCI to use PDF and IDF which
will be used for virtual and baremetal deployments

Definition of Terms
===================
* Baremetal deployment: Deployment on physical servers as opposed to deploying
software on virtual machines or containers running in the same physical server

* Virtual deployment: Deployment on virtual machines, i.e. the servers where
nodes will be deployed are virtualized. For example, in OpenStack, computes and
controllers will be virtual machines. This deployment is normally done on just
one physical server

* PDF: It stands for POD Descriptor File, which is a document that lists the
hardware characteristics of a set of physical or virtual machines which form
the infrastructure. Example:

https://git.opnfv.org/pharos/tree/config/pdf/pod1.yaml

* IDF: It stands for Installer Descriptor File, which is a document that
includes useful information for the installers to accomplish the baremetal
deployment. Example:

https://git.opnfv.org/fuel/tree/mcp/config/labs/local/idf-pod1.yaml

Problem description
===================

Currently, XCI only supports virtualized deployments running in one server. This
is good when the user has limited resources, however, baremetal is the preferred
way to deploy NFV platforms in lab or production environments. Besides, this
limits the scope of the testing greatly because we cannot test NFV hardware
specific features such as SRIOV.

Proposed change
===============

Introduce the infra_manager tool which will prepare the infrastructure for XCI
to drive the deployment in a set of virtual or baremetal nodes. This tool will
execute two tasks:

1 - Creation of virtual nodes or initialization of the preparations for
baremetal nodes
2 - OS provisioning on nodes, both virtual or baremetal

Once those steps are ready, XCI will continue with the deployment of the
scenario on the provisioned nodes.

The infra_manager tool will consume the PDF and IDF files describing the
infrastructure as input. It will then use a <yet-to-be-created-tool> to do
step 1 and bifrost to boot the Operating System in the nodes.

Among other services Bifrost uses:
- Disk image builder (dib) to generate the OS images
- dnsmasq as the DHCP server which will provide the pxe boot mechanism
- ipmitool to manage the servers

Bifrost will be deployed inside a VM in the jumphost.

For the time being, we will create the infrastructure based on the defined XCI
flavors, however, the implementation should not hinder the possibility of
having one pdf and idf per scenario, defining the characteristics and the
number of nodes to be deployed.

Tentative User guide
--------------------

Assuming the user cloned releng-xci in the jumphost, the following should be
done:

1 - Move the idf and pdf files which describe the infrastructure to
releng-xci/xci/prototypes/infra_manager/var. There is an example under xci/var

2 - Export the XCI_FLAVOR variable (e.g. export XCI_FLAVOR=noha)

3 - Run the <yet-to-be-created-tool> to create the virtual nodes based on the
provided PDF information (cpu, ram, disk...) or initialize the preparations for
baremetal nodes

4 - Start the bifrost process to boot the nodes

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
  Jack Morgan (jmorgan1)
  Somebody_else_please (niceperson)

Work items
----------

1. Provide support for a dynamically generated inventory based on PDF and IDF.
This mechanism could be used for both baremetal and virtual deployments.

2. Contribute the servers-prepare.sh script

3. Contribute the nodes-deploy.sh script

4. Integrate the three previous components correctly

5. Provide support for the XCI supported operating systems (opensuse, Ubuntu,
centos)

6. Allow pdf and idf per scenario
