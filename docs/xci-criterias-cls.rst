.. _xci-criterias-cls:

.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Fatih Degirmenci (fatih.degirmenci@ericsson.com)

=============================================
XCI Promotion Criterias and Confidence Levels
=============================================

This document structured in a way to explain the current Promotion Criterias and Confidence
Levels XCI uses to test and promote the scenarios. This is followed by other chapters to
start the conversation around how these criterias can be improved depending on the features
and scenarios that are onboarded to XCI.

The expectation is to update this document collaboratively with projects who are onboarded to
XCI or declared interest in doing so in order to find right level of testing.

This document should be seen as guidance for the projects taking part in XCI until
the OPNFV CD-Based Release Model and the criterias set for the CI Loops for that track
become available.

The CD-Based Release Model will supersede the information and criterias set in this document.

Existing CI Loops and Promotion Criterias
=========================================

XCI determined various CI Loops that runs for the scenarios that take part in XCI.
These loops are

* verify
* post-merge

Currently, XCI uses verify and post-merge loops to verify the changes and promote
the scenarios to the next loop in the CI Flow as candidates. The details of what
is done by each loop currently are listed below.

verify
------

The changes and subsequent patches enter this pipeline and get verified against
the most basic criteria OPNFV has.

* virtual noha deployment
* functest healthcheck

The checks done within this loop is common for all the scenarios and features no matter if
they are OpenStack or Kubernetes scenarios.

The changes that get Verified+1 from this pipeline is deemed to be good and
can be merged to master if there is sufficient +2 votes from the XCI and/or project committers.

post-merge
----------

The changes that are merged to master enter this pipeline and get verified
against the same criteria as the verify pipeline.

* virtual noha deployment
* functest healthcheck

The checks done within this loop is common for all the scenarios no matter if
they are OpenStack or Kubernetes scenarios.

The changes that are successfully verified get promoted for the next loop in
the pipeline.

Evolving CI Loops and Promotion Criterias
=========================================

TBD
