.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Ericsson AB and Others

.. Links
.. _Open Networking Automation Platform: https://www.onap.org/
.. _ONAP on OpenStack: https://wiki.onap.org/display/DW/ONAP+Installation+in+Vanilla+OpenStack
.. _ONAP Installation In Developer Lab: https://wiki.onap.org/download/attachments/15997434/ONAP%20Installation%20in%20Developer%20Lab.pdf?version=1&modificationDate=1506546937000&api=v2
.. OPNFV Edge Cloud Proposal: https://wiki.opnfv.org/display/PROJ/Edge+cloud
.. ONAP installation HEAT templates: https://github.com/onap/demo/tree/master/heat/ONAP

This spec introduces the work required to include os-nosdn-onap XCI scenario
for `Open Networking Automation Platform`_ (ONAP) installation on the Openstack
platform using HEAT templates.


Problem description
===================
There is a edge cloud project approved in OPNFV to have a initial release in
G release (if possible) which aims at bringing a reference platform for edge
cloud.  It is obvious that ONAP to be installed for multi VIM management and
closed loop automation of VNFs. So it is the opportunity for XCI to have ONAP
to be installed on Openstack platform using HEAT templates. This would enable
to get reference platform for edge cloud with with continuous integration.

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

1. Enhance {{XCI_FLAVOR }}-vars files to update ram, disk and cpu parameters.
2. Enhance the PDF file for the Baremetal deployment.
3. Extend the design of os-nosdn-nofeature scenario for the deployment of ONAP.
   - Create required Public Network, Flavors, Floating IP Addresses in Openstack.
   - Hook the above created paremeters in onap_openstack.env (see https://github.com/onap/demo/blob/master/heat/ONAP/onap_openstack.env).
   - Install the ONAP Heat Template (openstack stack create -t onap_openstack_float.yaml -e onap_openstack_float.env onap1.1)
4. Run ONAP Health Check.


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
1. Resources and Sizing definition for Virtual (or) Baremetal deployment
2. Create Openstack objects for ONAP environment afte Openstack Installation
3. Integrate and execute ONAP installation heat templates

Glossary
--------