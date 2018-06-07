.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Ericsson AB and Others

.. Links
.. _open-source-mano: https://osm.etsi.org/
.. _install-osm: https://osm.etsi.org/wikipub/index.php/OSM_Release_FOUR
.. _register-openstack-as-vim: https://osm.etsi.org/wikipub/index.php/Openstack_configuration_(Release_FOUR)

This spec proposes adding os-nosdn-osm XCI scenario for OSM as MANO.

Problem Description
===================

Currently OSM is not part of any scenario so OSM is not deployed and tested
within OPNFV. This spec proposes a reference platform for deployments that
want to use OSM as MANO.

Minimum Hardware Requirements
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Hardware for OSM Node
^^^^^^^^^^^^^^^^^^^^^

* RAM:    32 GB
* HD:     80 GB
* vCores: 8

OSM will be installed on OPNFV Deployment VM.

Hardware for OpenStack Controller Node(s)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* RAM:    32 GB
* HD:     80 GB
* vCores: 8

Hardware for OpenStack Compute Node(s)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* RAM:    32 GB
* HD:     80 GB
* vCores: 6

The supported flavors are mini, noha and ha.

Proposed Change
===============

1. Provide Pod Descriptor Files (PDF) and Installer Descriptor Files (IDF)
   specific to virtual deployment of this scenario to install OpenStack and OSM.
2. Introduce a new scenario os-nosdn-osm in releng-xci-scenarios repository.
3. Reuse the role from os-nosdn-nofeature scenario to install OpenStack.
4. Create new role(s) to install OSM on OPNFV VM, register OpenStack as VIM to
   OSM, onboard and activate VNFs to check the sanity of OSM installation.

Code Impact
-----------

Code specific to the os-nosdn-osm scenario will be added to the xci/scenarios
directory of the releng-xci-scenarios repository.

User Guide
----------

No user guide will be provided.

Implementation
==============

See the Proposed Change section.

Assignee(s)
-----------

* Fatih Degirmenci (fdegir)
* Manuel Buil (mbuil)
* Gianpietro Lavado

Work Items
----------

1. Create Ansible roles to install OSM, register OpenStack as VIM to OSM,
   onboard and activte VNFs to check the sanity of OSM Installation.
2. Consume OSM smoke tests from upstream and ensure the test cases are included
   in corresponding OPNFV Test projects.
3. Contribute created Ansible Role to install OSM back to OSM community so it
   can be developed further, maintained and made available to others who (want
   to) use Ansible for deployment automation.

Glossary
--------
