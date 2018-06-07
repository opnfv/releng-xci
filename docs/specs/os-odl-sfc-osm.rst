.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Ericsson AB and Others

.. Links
.. _open-source-mano: https://osm.etsi.org/
.. _install-osm: https://osm.etsi.org/wikipub/index.php/OSM_Release_FOUR
.. _register-openstack-as-vim: https://osm.etsi.org/wikipub/index.php/Openstack_configuration_(Release_FOUR)

This spec proposes adding os-odl-sfc-osm XCI scenario for OSM as MANO.

Problem Description
===================

OSM is capable of doing SFC through the VNFFG concept. SFC has currently only
one MANO component which is tacker and OSM could be its alternative.

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

* RAM:    16 GB
* HD:     80 GB
* vCores: 8

Hardware for OpenStack Compute Node(s)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* RAM:    16 GB
* HD:     80 GB
* vCores: 6

The supported flavors are mini, noha and ha.

Proposed Change
===============

1. Wait for the os-nofeature-osm to be ready
2. Provide OSM support into SFC testing code

Code Impact
-----------

User Guide
----------

No user guide will be provided.

Implementation
==============

See the Proposed Change section.

Assignee(s)
-----------

* Manuel Buil (mbuil)
* Gianpietro Lavado
* Eduardo Sousa

Work Items
----------

Glossary
--------

