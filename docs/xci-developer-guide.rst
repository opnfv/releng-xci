.. _xci-developer-guide:

.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Fatih Degirmenci (fatih.degirmenci@ericsson.com)

===================
XCI Developer Guide
===================

This document will contain the developer guide. As of today, XCI supports both OpenStack and Kubernetes deployments. This is indicated by the installer that is used, osa ("OpenStack Ansible") or kubespray. This guide is focusing at the moment on the osa installer and the Kubernetes parts will be added later.

Introduction
============

This document will contain details about the XCI and how things are put
together in order to support different flavors and different distros in future.

Document is for anyone who will

- do hands on development with XCI such as new features in XCI itself or bug fixes
- integrate new features
- want to know what is going on behind the scenes

It will also have guidance regarding how to develop for the sandbox.

If you are looking for User's Guide, please check README.rst in the root of
xci folder or take a look at
`Wiki <https://wiki.opnfv.org/display/INF/OpenStack>`_.

===================================
Components of XCI Developer Sandbox
===================================

TBD

=============
Detailed Flow
=============

The starting point for XCI is the script ``xci/xci-deploy.sh``. It sets some environment variables and sources the file ``xci/config/env-vars``. After setting up the scenario, it calls ``scripts/bifrost-provision.sh``.  This in turn runs ``test-bifrost-create-vm.yaml`` which uses the role ``bifrost-create-vm``. This creates the VMs.


==========================
Modifying the installation
==========================

XCI uses by default the upstream Bifrost and OpenStack. The XCI scripts have an option to use local Bifrost and OpenStack Ansible versions. These can be declarad in environment variables:

::

  export OPENSTACK_BIFROST_DEV_PATH=/opt/bifrost/
  export OPENSTACK_OSA_DEV_PATH=/opt/openstack-ansible/

The easiest of course is to have a script that sets these and other variables and then runs xci/xci-deploy.sh.

The playbook provision-vm-nodes.yml combines the opnfv/releng-xci and openstack/bifrost scripts and playbooks which means that the code that is in bifrost may not be the same that gets run. The actual code will be in ``XCI_CACHE/repos/bifrost`` which by default is ``XCI_PATH/.cache/``.

Many upstream repositories are defined in the file ``xci/config/env-vars`` . For making changes, the easiest is to clone an upstream repo to github.com, make the changes, and then configure the new url in ``env-vars``. An alternative is to host a local copy of the repo with git daemon.

Another place that defines the upstream repositories is ``xci/installer/osa/files/ansible-role-requirements.yml``.


===============================
Debugging installation failures
===============================

As mentioned earlier, the first step in the installation is that the VMs are set up. This can be checked with

::

  virsh list --all

If the VMs (or domains) are not running, it is possible to try to start them with

::

  virst start opnfv

If the VM does not have a working networking configuration, the following command gives a console access to the VM:

::

  virsh console controller00 --devname serial1

Once the VMs are up and running, they can be accessed with the normal commands

::

  ssh root@192.168.122.1

192.168.122.1 is the jumphost ("opnfv"), 192.168.122.2 is usually the first controller etc. The ssh keys are set up automatically for root access.

OpenStack Ansible installs OpenStack in lxc containers. The following commands can be helpful for dealing with them:

::

  lxc-ls

for listing all containers and then

::

  lxc-attach --name=<container name>

If an Ansible playbook fails, there is a trick to run the playbook on a single VM for debugging it:

::

  ansible -i "192.168.122.3," -u root -- setup all

This will give (Ansible) information about the VM with the address 192.168.122.3.


