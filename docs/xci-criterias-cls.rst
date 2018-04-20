.. _xci-criterias-cls:

.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Fatih Degirmenci (fatih.degirmenci@ericsson.com)

===================================================
CI Loops, Promotion Criterias and Confidence Levels
===================================================

This document is explains CI Loops, Promotion Criterias and Confidence Levels
XCI applies for the scenarios and features that are onboarded to XCI.

The criterias documented here are expected to be updated collaboratively by
feature projects, scenario owners, test projects, release management and the XCI
team in order to find right/sufficient/necessary level of testing that are
relevant to the features and scenarios.

This document should be seen as guidance for the projects taking part in XCI
until the OPNFV CD-Based Release Model and the criterias set for the CI Loops
for that track become available. Until that happens, CI Loops will used by XCU
will follow what is documented here and provide feedback to the projects based
on the test scope set within this document.

Once the OPNFV CD-Based Release Model and accompanying criterias become
available, this document and the information documented here will be superseded
by the information and criterias set by the new release model.

Descriptions
============

This chapter contains the descriptions of the terms and examples.

CI Loop
-------

CI Loops are independent entities to execute certain activities that can take
place in CI at any given time and provide feedback.

CI Loops run repeatedly and as independently as possible from other loops, do
not trigger each other and with very little or no metadata passed directly
between them.

CI Loops can be run when certain things happen, via timer, or polling.

A sample CI Loop is verify.

CI Flow
-------

CI Flows are constituted by linking different activities together.
In this context, a CI loop corresponds to certain activity and flow then becomes
linked loops.

A sample CI Flow could be verify, post-merge and daily.

Confidence Level
----------------

A Confidence Level(CL) is a simple key value pair(quality stamp) indicating a
confidence level. CLs are applied by the loops and gained by the artifacts while
they travel through CI. CLs can be applied to compositions or baselines can also
be applied as well. Especially in OPNFV, compositions get tested rather then
standalone artifacts. What is documented in the remainder of this document uses
they word artifact and the details are applicable to compositions and baselines
as well.

Stamped versions of the artifacts can be carried over to the next loops in CI
flow to do more extensive testing. A version of the artifact can have 0..n CLs,
each given and corresponding to a loop in CI.

CLs are part of the artifact metadata.

A sample CL is "daily": "SUCCESS"

Promotion
---------

Loops in CI verify/test the artifacts that reach to that loop. Outcomes of the
loops (loop verdicts) used for identifying and applying CLs. By doing this
continuously, loops populate candidate versions for the next loops in CI flow.

Promotion in this context is the selection of a version of the artifact from
the artifact candidate list with right/needed CL for a given loop. The selected
version remains as candidate until it passes the criteria set by the loop which
started testing the version. If the selected version fulfils the criteria, it
gains a new CL and becomes a candidate for the next loop in line by being added
to the candidate list for that loop.

At this point, the artifact promotion is completed successfully and the
promotion process ends for this loop and the promoted version of the artifact.

Versions that are not good enough won’t be promoted.

Promotion Criteria
------------------

Promotion criteria is the criteria set by the loops in CI flow. The artifacts
are expected to fulfil these criterias in order for them to gain the CL set
by that loop and get promoted in order to be added to the candidate list for
the next loop in line.

Loops and the contents/scope of them should be carefully determined, providing
feedback for certain aspects. The scope of the loops should be evaluated all the
time, fine tuning it as needed, increasing the bar continusly in order to push
for even higher quality. Another key thing to highlight here is that it is
necessary to have the right balance; having too low bar means low quality and
too high makes it nearly impossible for anyone to fulfil that, especially
especially at the early phases of the project lifecycle.

Based on the content/scope of the loops, time to run them can vary; from minutes
to hours, and sometimes days and time it takes to run them is another factor to
be taken into accout while constructing loops and setting the scope for them.

CI Loops and Confidence Levels Used by XCI for the Scenarios/Features
=====================================================================

XCI will have various CI Loops to ensure the development done by the OPNFV
projects are verified properly and feedback that is fit for purpose is provided
to them in a timely manner.

The CI Loops XCI uses, what they test, and the Confidence Levels applied by them
can be seen from the table below.

+------------+------------------------------------+--------------------------------------+
| CI Loop    | Tests                              | Confidence Level Applied by the Loop |
+============+====================================+======================================+
| verify     | | open patches                     || N/A                                 |
+------------+------------------------------------+--------------------------------------+
| post-merge | | merged changes                   || merge                               |
+------------+------------------------------------+--------------------------------------+
| daily      | | scenarios promoted by merge loop || daily                               |
+------------+------------------------------------+--------------------------------------+
| weekly     | | scenarios promoted by daily loop || weekly                              |
+------------+------------------------------------+--------------------------------------+

Please note that not all these CI Loops are available at this point in time and
they will be activated as soon as they become available.

In the following chapters, what each of these loops do is explained in more
details.

verify
------

The changes and subsequent patches are tested by this loop using the criteria
this loop expects patches to fulfil.

The changes that get Verified+1 from this loop is deemed to be good and can be
merged to master if there is sufficient +2 votes from the corresponding project
committers.

There is no specific Confidence Level(CL) applied by this loop as the changes
that get merged to master gains the CL naturally by landing to master.

post-merge
----------

The changes that are merged to master are tested by this loop using the criteria
this loop expects merged changes to fulfil.

The scenarios that are successfully verified by this loop get stamped with the
CL **"merge": "SUCCESS"** and become candidates for next loop in CI Flow, which
is **daily**.

The metadata of the scenario that passes this loop gets stored on
`OPNFV Artifact Repository <http://artifacts.opnfv.org/xci.html>`_ in **merge**
folder and the next loop looks for and fetches from there.

The scenario is also displayed on **merge** column on
`XCI Dashboard <http://129.192.69.214/xci.php>`_ for projects to see what is
happening with their scenario at any given time.

daily
-----

The scenarios that were promoted by **post-merge** loop are candidates for this
loop to pick and test against the criteria this loop expects selected candidates
to fulfil.

The scenarios that are successfully verified by this loop get stamped with the
CL **"daily": "SUCCESS"** and become candidates for next loop in CI Flow, which
is **weekly**.

The metadata of the scenario that passes this loop gets stored on
`OPNFV Artifact Repository <http://artifacts.opnfv.org/xci.html>`_ in **daily**
folder and the next loop looks for and fetches from there.

The scenario is also displayed on **daily** column on
`XCI Dashboard <http://129.192.69.214/xci.php>`_ for projects to see what is
happening with their scenario at any given time.

weekly
------

The scenarios that were promoted by **daily** loop are candidates for this loop
to pick and test against the criteria this loop expects selected candidates
to fulfil.

The scenarios that are successfully verified by this loop get stamped with the
CL **"weekly": "SUCCESS"**. This CL could essentially become the CL the release
candidates are expected to have in future.

The metadata of the scenario that passes this loop gets stored on
`OPNFV Artifact Repository <http://artifacts.opnfv.org/xci.html>`_ in **weekly**
folder and the next loop looks for and fetches from there.

The scenario is also displayed on **weekly** column on
`XCI Dashboard <http://129.192.69.214/xci.php>`_ for projects to see what is
happening with their scenario at any given time.

Promotion Criterias and Loop Contents
=====================================

This chapter documents the promotion criterias and loop contents that will be
used by CI Loops to verify patches, changes, and scenarios depending on where
the loop is in overall CI Flow.

Basic Criteria for All Loops and Features/Scenarios
---------------------------------------------------

The table below shows the basic criterias that are common across different loops
and features/scenarios. All the features/scenarios are expected to pass these
basic criterias.

The feature/scenario specific testing is run in addition to basic testing.
They need to be set by the feature projects, scenario owners, test projects and
release management.

As highlighted on the table, basic criteria for some loops are not listed. It is
important the community proposes what to test there as well.

+------------+-----------------+-------------------+----------------+-----------------+--------------------+
| CI Loop    | Deployment Type | Deployment Flavor | Functest Suite | Yardstick Suite | Long Duration Test |
+============+=================+===================+==================================+====================+
| verify     | | virtual       || noha             | healthcheck    | N/A             | N/A                |
+------------+-----------------+-------------------+----------------+-----------------+--------------------+
| post-merge | | virtual       || noha             | **<addme>**    | N/A             | N/A                |
+------------+-----------------+-------------------+----------------+-----------------+--------------------+
| daily      | | baremetal     || ha               | **<addme>**    | **<addme>**     | N/A                |
+------------+-----------------+-------------------+----------------+-----------------+--------------------+
| weekly     | | baremetal     || ha               | **<addme>**    | **<addme>**     | **<addme>**        |
+------------+-----------------+-------------------+----------------+-----------------+--------------------+

Feature and Scenario Specific Testing
-------------------------------------

Feature and scenario owners are expected to provide feedback for the test loops
marked as **<addme>** below. It is important to state again that no matter what
the loop or feature/scenario, all of them are expected to meet the basic
criteria set per loop level and feature/scenario specific testing proposed by
the projects comes on top of that.

**congress**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**promise**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**os-nosdn-nofeature**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**os-nosdn-fds**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**os-nosdn-vmha**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**os-odl-nofeature**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**os-odl-sfc**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**os-odl-bgpvpn**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**k8-nosdn-nofeature**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**k8-calico-nofeature**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**k8-canal-nofeature**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

**k8-flannel-nofeature**

* verify
  - virtual noha deployment
  - functest healthcheck
* post-merge
  - virtual noha deployment
  - functest **<addme (smoke, scenario specific test, etc.)>**
* daily
  - baremetal ha deployment
  - functest **<addme (x, y, z, scenario specific test, etc.)>**
  - yardstick **<addme>**
* weekly
  - baremetal ha deployment
  - long duration test **<addme>**

CI Loops and Confidence Levels Used by XCI for the Test Projects
================================================================

TBD
