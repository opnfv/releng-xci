.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Intel Corporation

.. Links
.. _Open Networking Automation Platform: https://www.onap.org/
.. _ONAP metric analysis: https://onap.biterg.io/
.. _ONAP on Kubernetes: http://onap.readthedocs.io/en/latest/submodules/oom.git/docs/oom_quickstart_guide.html
.. _Helm: https://docs.helm.sh/
.. _ONAP on OpenStack: https://wiki.onap.org/display/DW/ONAP+Installation+in+Vanilla+OpenStack

This spec introduces the work required to include the XCI scenario for
`Open Networking Automation Platform`_ (ONAP).

Problem description
===================
According to the `ONAP metric analysis`_, more than 26K commit
changes have been submited since its announcement. Every patchset
that is merged raises a Jenkins Job that re-creates the Docker
container image for the corresponding service. Those images are
consumed by the two main deployment methods that install ONAP
services:

- `ONAP on Kubernetes`_: This method provides the ability to manage
the entire life-cycle of an ONAP installation, from the initial
deployment to final decommissioning through ONAP Operations
Manager(OOM) tool. This tool uses Helm_ charts to provision ONAP
services in Kubernetes.
Recommended Hardware requirements:
  * RAM:    128 GB
  * HD:     120 - 160 GB
  * vCores: 16 - 32

- `ONAP on OpenStack`_: This method deploys ONAP services through the
usage of Heat OpenStack Templates (HOT).
Recommended Hardware requirements:
  * RAM:    140 GB
  * HD:     100 GB
  * vCores: 60

Given this project is constantly changing, an early feedback can be
provided by the XCI project and prevent major failures.

Proposed change
===============

In order to guarantee the proper installation and validation of ONAP
services this spec proposes two phases that complements each other:

1 - Creation of scenarios for the installation of ONAP services. Those
new scenarios (os-nosdn-onap and k8s-nosdn-onap) will be designed to
validate the installation process provided by OOM and HOT.
2 - Addition of integration tests for validation of ONAP operation.

Code impact
-----------
New code will be placed in the xci/scenarios existing directory. The
ONAP installation proceess needs to happen after the VIM has been
provisioned and before the OPNFV tests are executed.

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

Work items
----------
TBD

Glossary
--------
