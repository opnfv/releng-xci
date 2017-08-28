.. _xci-overview:

.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Fatih Degirmenci (fatih.degirmenci@ericsson.com)

======================================
Cross Community Continuous Integration
======================================


This document will contain the overview, the pipelines, and stuff.

Introduction
============

OPNFV has an advanced Continuous Integration (CI) machinery that provides support
to OPNFV community to develop, integrate, test and release the integrated
reference platform for NFV.

During the past releases, OPNFV integrated, deployed and tested different
flavors (scenarios) of the platform in an entirely automated fashion, resulting
in feedback to OPNFV itself and the communities OPNFV works with. This enabled
communities to implement new features directly in the upstream, identify bugs
and issue fixes for them.


The development and release model employed by OPNFV uses stable versions of
upstream components. This helps developers and users who are after the stability
however it slows down the speed of development, testing, resulting in slower pace
in innovation.

In order to provide means for developers to work with OpenStack master
branch, cutting the time it takes to develop new features significantly and
testing them on OPNFV Infrastructure
    enable OPNFV developers to identify bugs earlier, issue fixes faster, and
get feedback on a daily basis
    establish mechanisms to run additional testing on OPNFV Infrastructure to
provide feedback to OpenStack community
    make the solutions we put in place available to other LF Networking Projects
OPNFV works with closely
    embrace the change and apply Continuous Delivery and DevOps principles and
practices to OPNFV


