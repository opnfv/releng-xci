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

OPNFV develops, operates, and maintains its Continuous Integration (CI)
used by OPNFV community to develop, integrate, test and release the integrated
reference platform for NFV.

During the past releases, OPNFV released different flavors (scenarios) of the
platform in an entirely automated fashion, resulting in feedback to OPNFV itself
and the communities OPNFV works with. This enabled the community to implement
new features, identify bugs and issue fixed for them directly in corresponding
upstream communities.

The development and release model employed by OPNFV during the past releases
uses stable versions of upstream components. This helps developers and users
who are after the stability however it slows down the speed of development,
integration, and testing thus resulting in slower pace in innovation.

In order to increase the speed of the development and evolution of the platform,
OPNFV needs to provide means for its developers and users. One of the ways to
achieve this is to ensure developers have access to the latest versions of the
upstream components they are developing, integrating, and testing.

Based on this need, OPNFV Infrastructure Working Group (Infra WG) started the
Cross Community Continuous Integration (XCI) initiative, bringing in a new
development and release model into OPNFV which is based on Continuous Delivery
and DevOps practices and principles.

Focus Areas
===========

Enabling Continuous Delivery
----------------------------

By definition, XCI focuses on master in order to

* shorten the time it takes to introduce new features
* make it easier to identify and fix bugs
* ease the effort to develop, integrate, and test the reference
  platform
* establish additional feedback loops within OPNFV, towards the users
  and between the communities OPNFV works with
* increase the visibility regarding the state of things at all times

XCI aims to enable this by applying basic CI/CD & DevOps principles and
following best practices such as

* fail fast, fix fast
* always have working software
* small and frequent commits
* work against the trunk, shortening time to develop
* fast and tailored feedback
* everything is visible to everyone all the time

and so on.

By doing this, the overall quality of the platform components provided by the
upstream communities will increase greatly, making it easier for anyone to
consume them when they need them with less trouble, helping to find and fix bugs
much earlier than what it is today and develop new features.

How good this can work depends on the nature of the changes. If the changes are
atomic and more importantly complete, the value added by XCI will increase
increase significantly.

Putting Users and Developers First
----------------------------------

Apart from applying the principles and following the best practices, XCI puts
the users and developers first by pushing for

* empowering developers by hiding the details that are generally not so
  interesting or concerning for the developers
* reduced complexity
* an easy way to try and develop things
* speed, helping developers to bring their scenarios to OPNFV fast
* real scenario ownership

The proof of the user and developer centric approach is that the first thing
XCI made available is the sandbox for the users to try things out and for the
developers to develop things.

Keeping Quality, Confidence and Predictability High
---------------------------------------------------

Another and perhaps the most crucial concern for XCI is to keep the quality high,
increase the confidence, have predictability, and have the availability of the
latest versions earlier. Some of the prerequisites to fulfill these goals are

* Test early and often
* Know the quality at all times
* Make the platform available early so people have time to develop, integrate,
  and test their work
* Avoid big bang uplift
* Avoid surprises

Source Based Deployments
------------------------

CI starts on developer workstation and this is the fastest feedback a developer
can get. In order to ensure developers can apply this principle, they need the
tools and ways to enable fast development and test cycles that are repeatable as
many times as necessary without hassle.

One way to achieve this is to bring developers closer to the source and remove
anything between them. This means that what XCI brings is not only deploying from
upstream OpenStack master but doing that from source with no intermediaries in between.

A simple scenario that demostrates the value of bringing capability of source based
deployments to OPNFV can be seen on below diagram.

.. image:: images/source-based-dev.png
   :height: 240px
   :align: center

As you can see on the diagram, XCI provides tools and ways for developers to

* patch the source code on their laptop
* get the patch deployed to the stack with a single command
* run the tests
* fix if something is broken
* repeat the cycle until they are satisfied with it and have confidence in it
* send the patch for review and CI

This does not mean building packages or using artifacts are not useful. If source
based approach is not available, they can be used. But nothing beats the source
and this is what XCI brings in on top of everything else.

Multi-distro Support
--------------------

Giving choice and not pushing developers and users to certain things are two
of the important aspects of XCI. This means that if they want to have all in one
deployments, they should be able to do that by using
:ref:`different flavors <sandbox-flavors>` provided by XCI.

Multi-distro support falls into same category for XCI; giving choice and making
sure people can pick and choose what Linux distribution they want to use.

XCI currently supports Ubuntu 16.04, CentOS 7, and OpenSUSE Leap 42.3 which the
choice is entirely left to user.

Feature parity between the OPNFV scenarios on different Linux distributions
that are supported by XCI may vary and it is possible for OPNFV community
to work on to bring them to same level.

XCI Pipelines
=============

Pipelines for Upstream Projects
-------------------------------

Pipelines for OPNFV Scenarios
-----------------------------

Pipelines for OPNFV Test Projects
---------------------------------

Pipelines for XCI Framework and Sandbox
---------------------------------------

Putting All Together
--------------------
