.. _xci-developer-guide:

.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Fatih Degirmenci (fatih.degirmenci@ericsson.com)

===============
Developer Guide
===============

Introduction
============

XCI offers variety of options to ease the effort to do the development such as

* sandbox which is capable of bringing up entire stack with a single command
* high customization by setting few environment variables
* easy to follow steps while creation and provisioning of the nodes and installation
  of OpenStack
* ability to pick and choose the services that are needed for the development
* ability to override/change versions of almost anything

Following chapters explain how a developer can set up the best development and
test environment for the work he or she is doing. The steps are accompanied by
real examples.

Configuring the Deployment
==========================

Developers can configure the deployment in different ways as listed below.

* the Linux distribution
* specs of the VM nodes
* the flavor
* versions of the components
* deployed & activated services
* versions of OpenStack components

Choosing the Linux Distribution
-------------------------------

The sandbox currently picks the Linux distribution to use based on the host machine.
This means that if you have an OpenSUSE host where you intend to execute the
``xci-deploy.sh`` script to get sandbox up, the Linux distributions of the created
and provisioned nodes will also have OpenSUSE.

Adjusting the Specs of the VM Nodes
-----------------------------------

The specs of VM nodes are set in files named ``{flavor}_vars`` stored in
`config <https://git.opnfv.org/releng-xci/tree/xci/config>`_ directory of the
releng-xci repo.

You can adjust the specs of the VMs by updating the configuration file of the
flavor you intend to use.

All settings can be adjusted but it is important to highlight that changing
TEST_VM_NUM_NODES, TEST_VM_NODE_NAMES, VM_DOMAIN_TYPE, and VM_DISK_CACHE settings
might result in unexpected behaviors.

You can change the settings for VM_CPU, VM_MEMORY_SIZE, and VM_DISK to fit
your purpose assuming the host machine is capable of running the VMs with newly
configured settings.

As you notice in configuration files, the settings can be configured by
setting the corresponding environment variables as shown in the example below.

| ``export VM_CPU=16``
| ``export VM_MEMORY_SIZE=32768``
| ``export VM_DISK=200``

Sandbox will then use these specs while creating the VMs.

The changes to specs can directly be done by updating the file as well if you
want changes to persist while you are doing your work and in doubt of losing
the environment variables.

If you do that, please ensure that you set ``$RELENG_DEV_PATH`` environment
variable, pointing to the releng-xci repo which you updated the file so you
can deal with only one environment variable.

| ``export RELENG_DEV_PATH=/path/to/releng-xci/``

Choosing the Sandbox Flavor
---------------------------

The sandbox offers 4 flavors; aio, mini, noha, and ha. Please check
:ref:`XCI User Guide - Sandbox Flavors <sandbox-flavors>` to see the
details of these flavors.

The flavor can be choosen by setting the environment variable ``$XCI_FLAVOR``
as shown in the example below.

| ``export XCI_FLAVOR=ha``

This will then be used by the sandbox to create and provision the number of
VM nodes needed for the flavor using bifrost and instruct openstack-ansible
regarding the fact that this is a high availability deployment meaning that
there should be 3 nodes for OpenStack control plane and 2 nodes for compute.

Using Different Version of OpenStack
------------------------------------

Sandbox offers possibility to deploy OpenStack from the tip of the master branch
or from a commit.

It can be done by setting the environment variable ``$OPENSTACK_OSA_VERSION``
pointing to the version of OpenStack Ansible (OSA).

| ``export OPENSTACK_OSA_VERSION=master``

Sandbox will use the latest from master branch of OSA to deploy OpenStack.

You can configure the version by updating the
`pinned-versions <https://git.opnfv.org/releng-xci/tree/xci/config/pinned-versions>`_
file as well. As noted in previous sections, you need to ensure you set
``$RELENG_DEV_PATH`` before executing xci-deploy.sh script for the setting
to take effect.

Deployed and Activated OpenStack Services
-----------------------------------------

OSA uses single Ansible playbook to deploy and activate OpenStack services.
XCI has its own playbook,
`setup-openstack.yml <https://git.opnfv.org/releng-xci/tree/xci/file/setup-openstack.yml>`_
choosing the limited number of services to use within OPNFV.

If the service you need is not available in this playbook, you can get it
by updating the file and adding the playbook that deploys and activates that service.

As an example, assume you want barbican to be deployed and activated.
In this case, you update the OPNFV playbook setup-openstack.yml and add
this line into it.

| ``- include: os-barbican-install.yml``

In order for this to take effect, you need to set ``RELENG_DEV_PATH``
environment variable before executing xci-deploy.sh script.

Please check upstream OSA documentation and the upstream
`playbook <https://git.openstack.org/cgit/openstack/openstack-ansible/tree/playbooks/setup-openstack.yml>`_ to see which services are available and
the names of the playbooks of those services.

Please note that the flavor aio deploys all the services that are
enabled by the upstream and it is not possible to configure services
for it at this time.
