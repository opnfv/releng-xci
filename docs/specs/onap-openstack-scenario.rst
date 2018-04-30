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
for `Open Networking Automation Platform`_ (ONAP) installation on the Openstack
platform using HEAT templates.


Problem description
===================
There is an edge cloud project approved in OPNFV to have an initial release in
G release (if possible) which aims at bringing a reference platform for edge
cloud.  It is obvious that ONAP to be installed for multi VIM management and
closed loop automation of VNFs. So it is the opportunity for XCI to have ONAP
to be installed on Openstack platform using HEAT templates. This would enable
to get reference platform for edge cloud with continuous integration.

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

1. Override ram, disk and cpu parameters accordingly to accomodate ONAP
   components for the given XCI flavor.

2. Enhance the PDF file for the Baremetal deployment.

3. Extend the design of os-nosdn-nofeature scenario for the deployment of
   ONAP.

4. Create required Public Network, Flavors, Floating IP Addresses in
   Openstack.
   This step is needed to be executed immediately after the Openstack
   installation. 
   Currently Openstack-Ansible doesn't configure OVS
   (in neutron_plugin_type: ml2.ovs configuration) for external network
   connectivity over its neutron router. So this requires some effort
   in openstack ansible neutron role to configure controller's openvswitch
   agent in providing internet connectivity for the private VMs created
   by ONAP heat templates.

5. Populate onap_openstack.env
  (see https://github.com/onap/demo/blob/master/heat/ONAP/onap_openstack.env)
  with above (step 4) created Openstack object id references.

6. Install the ONAP Heat Template (openstack stack create -t onap_openstack_float.yaml -e onap_openstack_float.env onap1.1)

7. Run ONAP Health Check.


Code impact
-----------
New code will be placed in the xci/scenarios existing directory. The
ONAP installation proceess needs to happen after the VIM has been
provisioned and before the OPNFV tests are executed.


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
4. Create Openstack objects for ONAP environment after Openstack Installation.
5. Integrate and execute ONAP installation heat templates.

Glossary
--------