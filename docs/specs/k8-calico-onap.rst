.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Intel Corporation

.. Links
.. _Open Networking Automation Platform: https://www.onap.org/
.. _ONAP metric analysis: https://onap.biterg.io/
.. _ONAP on Kubernetes: http://onap.readthedocs.io/en/latest/submodules/oom.git/docs/oom_quickstart_guide.html
.. _Helm: https://docs.helm.sh/
.. _ONAP on OpenStack: https://wiki.onap.org/display/DW/ONAP+Installation+in+Vanilla+OpenStack
.. _OOM Software Requirements: http://onap.readthedocs.io/en/latest/submodules/oom.git/docs/oom_cloud_setup_guide.html#software-requirements

This spec introduces the work required to include the XCI scenario
for `Open Networking Automation Platform`_ (ONAP) through the ONAP
Operations Manager(OOM) tool. This tool provides the ability to manage
the entire life-cycle of an ONAP installation on top of a Kubernetes
deployment.

Problem description
===================
According to the `ONAP metric analysis`_, more than 26K commit
changes have been submited since its announcement. Every patchset
that is merged raises a Jenkins Job for the creation and deployment
of a Docker container image for the corresponding service. Those new
images are consumed by deployment methods like `ONAP on Kubernetes`_
and `ONAP on OpenStack`_) during the installation of ONAP services.

Given that ONAP is constantly changing, an early issue detected can
be crucial for ensuring the proper operation of OOM tool.

Hardware Requirements
=====================

Initially, the No-HA and HA flavors will be supported. ONAP requires
a large amount of resources. These are the recommended resources for
All-in-One flavor:

  * RAM:    128 GB
  * HD:     120 - 160 GB
  * vCores: 16 - 32

Given that No-HA and HA have multiple compute nodes, the hardware
resources are distributed between the nodes resulting in a smaller
amount of resources.  These are the recommended resources for
No-HA and HA flavors:

  * RAM:    64 GB
  * HD:     120 GB
  * vCores: 16

.. note::
    This recommendation is work in progress and we will
    adjust the amount of hardware resources for these scenarios

Proposed change
===============

In order to guarantee the proper installation and validation of ONAP
services this spec proposes two phases that complements each other:

1 - Creation k8-calico-onap scenario for the installation of ONAP
services. This new scenario will be designed to validate the
installation process provided by OOM tool.
2 - Adding Integration tests for ensuring that ONAP is operating
properly. This process should cover Design and Runtime phases.

Code impact
-----------
New code will be created base on k8-nosdn-nofeature scenario and will
placed in the xci/scenarios/k8-calico-onap directory. The ONAP
installation proceess needs to happen after the VIM has been
provisioned and before the OPNFV tests are executed.

Compared with the default configuration for the virtual resources (4
vCPUs, 8 GB, 100 GB), ONAP services consume more virtual resources.
Therefore it's necessary to adapt the bifrost-provision.sh script to
satisfy these needs. It's recomended to adapt these values based on
the selected flavor so every VM can only consume the resources
required for its services and the amount of resources required for
flavors with multiple VMs, like mini, noHA and HA, can be minimized.

OOM has suffered changes that affects the way to be consumed during
its development in Beijing Release. In this latest and current
release, it depends on Helm and kubectl tools in their v2.8.x
and 1.8.10 versions respectively (`OOM Software Requirements`_).

The OOM also provides a Makefile that collects instructions for the
creation of ONAP packages into the Tiller repository. To determine
which ONAP services are going to be enabled, this configuration can
be done by the OOM configuration, this new file will be named
onap.yaml and will be placed in xci/files common folder.


Tentative User guide
--------------------
TBD

Implementation
==============
TBD

Assignee(s)
-----------

Primary assignee:
  Victor Morales (electrocucaracha)
  Periyasamy Palanisamy (epalper)
  Fatih Degirmenci (fdegir)
  Jack Morgan (jmorgan1)

Work items
----------
TBD

Glossary
--------
