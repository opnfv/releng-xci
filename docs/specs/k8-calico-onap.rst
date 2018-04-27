.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Intel Corporation

.. Links
.. _Open Networking Automation Platform: https://www.onap.org/
.. _ONAP metric analysis: https://onap.biterg.io/
.. _ONAP on Kubernetes: http://onap.readthedocs.io/en/latest/submodules/oom.git/docs/oom_quickstart_guide.html
.. _Helm: https://docs.helm.sh/
.. _ONAP on OpenStack: https://wiki.onap.org/display/DW/ONAP+Installation+in+Vanilla+OpenStack
.. _OOM Minimum Hardware Configuration: http://onap.readthedocs.io/en/latest/submodules/oom.git/docs/oom_cloud_setup_guide.html#minimum-hardware-configuration
.. _OOM Software Requirements: http://onap.readthedocs.io/en/latest/submodules/oom.git/docs/oom_cloud_setup_guide.html#software-requirements
.. _seed code: https://gitlab.com/Orange-OpenSource/onap_oom_automatic_installation
.. _Orange ONAP OOM Deployment Resource Requirements: https://gitlab.com/Orange-OpenSource/kubespray_automatic_installation/blob/521fa87b20fdf4643f30fc28e5d70bdf9f1c98f3/vars/pdf.yaml

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

Minimum Hardware Requirements
=============================

Initially, No HA flavor will be the only supported flavor in order to
bring a reference implementation of the scenario. Support for other
flavors will be introduced based on this implementation.

According to the `OOM Minimum Hardware Configuration`_, ONAP requires
large amount of resources, especially on Kubernetes Worker nodes.

Given that No HA flavor has multiple worker nodes, the containers can
be distributed between the nodes resulting in a smaller footprint of
of resources.

The No HA scenario consists of 1 Kubernetes master node and 2 Kubernetes
Worker nodes. Total resource requirements should be calculated based on
the number of nodes.

This recommendation is work in progress and based on Orange
implementation which can be seen from
`Orange ONAP OOM Deployment Resource Requirements`_.
The resource requirements are subject to change and the scenario will
be updated as necessary.

Hardware for Kubernetes Master Node(s)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* RAM:    8GB
* HD:     150GB
* vCores: 8

Hardware for Kubernetes Worker Node(s)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* RAM:    64GB
* HD:     80GB
* vCores: 16

Proposed change
===============

In order to guarantee the proper installation and validation of ONAP
services, this spec proposes two phases that complements each other:

1. Creation k8-calico-onap scenario for the installation of ONAP
services. This new scenario will be designed to validate the
installation process provided by OOM tool.
2. Adding Integration tests for ensuring that ONAP is operating
properly. This process should cover Design and Runtime phases.

Code impact
-----------
New code will be created based on the existing k8-calico-nofeature
scenario and will be placed in scenarios/k8-calico-onap directory
in releng-xci-scenario repo. The ONAP installation should proceed
once the VIM has been installed and before the OPNFV tests are run.


The default configuration for the virtual resources (4 vCores, 8GB RAM,
and 100GB HD) offered by XCI does not satisfy the ONAP needs. The
scenario override mechanism will be used to bring up nodes with
the necessary amount of resources. This will be replaced by PDF and
IDF once they become available. PDF and IDF implementation is a
separate work item and it is not expected as dependency for the
implementation of this scenario.

Software Requirements
---------------------

OOM has gone through significant changes during Beijing release
cycle. This resulted in changed way of installing ONAP.

In its current release, new software is necessary to install ONAP
as listed below and on `OOM Software Requirements`_..

Helm:    2.8.x
kubectl: 1.8.10

The OOM also provides a Makefile that collects instructions for the
creation of ONAP packages into the Tiller repository. To determine
which ONAP services are going to be enabled, this configuration can
be done by the OOM configuration, this new role will be placed in
scenarios/k8-calico-onap/role/k8-calico-onap/tasks folder in
releng-xci-scenario repository.

Tentative User guide
--------------------
TBD

Implementation
==============
The Orange team has been working on this scenario for a while, this
new role can use and adapt their `seed code`_ during the implementation.

Assignee(s)
-----------

Primary assignee:
  Victor Morales (electrocucaracha)
  Fatih Degirmenci (fdegir)
  Jack Morgan (jmorgan1)

Work items
----------
TBD

Glossary
--------
