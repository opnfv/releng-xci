.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Ericsson AB and Others

.. Links
.. _Open Networking Automation Platform: https://www.onap.org/
.. _ONAP on OpenStack: https://wiki.onap.org/display/DW/ONAP+Installation+in+Vanilla+OpenStack
.. _ONAP Installation In Developer Lab: https://wiki.onap.org/download/attachments/15997434/ONAP%20Installation%20in%20Developer%20Lab.pdf?version=1&modificationDate=1506546937000&api=v2
.. OPNFV Edge Cloud Proposal: https://wiki.opnfv.org/display/PROJ/Edge+cloud
.. ONAP installation HEAT templates: https://github.com/onap/demo/tree/master/heat/ONAP
.. Configuring OpenStack-Ansible for Open vSwitch: https://medium.com/@travistruman/configuring-openstack-ansible-for-open-vswitch-b7e70e26009d

This spec introduces the work required to include os-nosdn-onap XCI scenario
for `Open Networking Automation Platform`_ (ONAP) installation on the OpenStack
platform using HEAT templates.


Problem description
===================
There is an edge cloud project approved in OPNFV to have an initial release in
G release (if possible) which aims at bringing a reference platform for edge
cloud.  It is obvious that ONAP requires to be installed for managing multiple
VIMs and closed loop automation of VNFs. So XCI requires ONAP if it aims to
deploy edge cloud scenarios.
This would enable to get reference platform for edge cloud with continuous
integration.

Recommended Minimum Hardware requirements:
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

On the Compute:
^^^^^^^^^^^^^^^

  * RAM:    128 GB
  * HD:     600 GB
  * vCores: 56

On the Controller:
^^^^^^^^^^^^^^^^^^

  * RAM:    12 GB
  * HD:     100 GB
  * vCores: 4

The initial supported flavor is mini. noha and ha flavors can be supported later.


Proposed change
===============

1. Override ram, disk and cpu parameters (or) Have pdf file specific to this
   scenario to install ONAP components for virtual deployments.

2. Enhance the pdf file for the Baremetal deployment to accomodate system
   parameters mentioned in 1.

3. Reuse the design of os-nosdn-nofeature under os-nosdn-onap scenario for
   the deployment of ONAP.

4. Create required Public Network, Flavors, Floating IP Addresses in
   OpenStack.
   This step is needed to be executed immediately after the OpenStack
   installation. Currently OpenStack-Ansible doesn't configure OVS
   (in neutron_plugin_type: ml2.ovs configuration) for external network
   connectivity over its neutron router. So this requires some effort
   in openstack ansible neutron role to configure controller's openvswitch
   agent in providing internet connectivity for the private VMs created
   by ONAP heat templates.

5. Run OpenStack Health check provided by XCI and make sure it passes
   before proceeding with below steps 6-9.

6. Clone and Integrate ONAP demo repository
   https://gerrit.onap.org/r/gitweb?p=demo.git;a=tree;h=refs/heads/master;hb=refs/heads/master

7. Populate onap_openstack.env
  (see https://gerrit.onap.org/r/gitweb?p=demo.git;a=blob;f=heat/ONAP/onap_openstack.env;h=fa87e42e2473eb9dae2aa1554b6761694dd62d85;hb=refs/heads/master)
  with above (step 4) created OpenStack object id references. It also has URLs
  of code, artifacts and repositories, etc. which will be kept as default
  values to use the latest ONAP code (i.e. master) and its latest docker
  images.

8. Install the ONAP Heat Template (openstack stack create -t onap_openstack_float.yaml -e onap_openstack_float.env onap1.1)

9. Run ONAP Health Check by running the instructions as mentioned in
   http://onap.readthedocs.io/en/latest/guides/onap-developer/settingup/fullonap.html#test-the-installation


Code impact
-----------
os-nosdn-onap scenario specific code will be placed under xci/scenarios
directory of releng-xci-scenarios repository.
The ONAP installation (steps 4-7 mentioned in Proposed change section)
happens after the VMs/Baremetal servers have been provisioned
with OpenStack components.


Tentative User guide
--------------------
NA


Implementation
==============
See the Proposed change section.


Assignee(s)
-----------

Primary assignee:
  Periyasamy Palanisamy (epalper)
  Victor Morales (electrocucaracha)
  Fatih Degirmenci (fdegir)

Work items
----------
1. Enhance os neutron role to provide external network connectivity when OVS
   is used for the overcloud networking.
2. Define in-band os-nosdn-onap scenario in XCI.
3. Resources and Sizing definition for Virtual (or) Baremetal deployment.
4. Create OpenStack objects for ONAP environment after OpenStack Installation.
5. Integrate and execute ONAP installation heat templates.

Glossary
--------