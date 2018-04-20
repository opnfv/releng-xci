.. _xci-criterias-cls:

.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. (c) Fatih Degirmenci (fatih.degirmenci@ericsson.com)

===================================================
CI Loops, Promotion Criterias and Confidence Levels
===================================================

This document explains CI Loops, Promotion Criterias and Confidence Levels
XCI applies for the scenarios and features that are onboarded to XCI.

The criterias documented here are expected to be updated collaboratively by
feature projects, scenario owners, test projects, release management and the XCI
team in order to find right/sufficient/necessary level of testing that are
relevant to the features and scenarios.

This document should be seen as guidance for the projects taking part in XCI
until the OPNFV CD-Based Release Model and the criterias set for the CI Loops
for that track become available. Until that happens, CI Loops will used by XCI
will follow what is documented here and provide feedback to the projects based
on the test scope set within this document.

Once the OPNFV CD-Based Release Model and accompanying criterias become
available, this document and the information documented here will be superseded
by the information and criterias set by the new release model.

Descriptions
============

This chapter contains the descriptions of the terms and examples.

Artifacts and Compositions
--------------------------

An artifact is one of many kinds of tangible by-products produced during the
development of software. [1] An artifact can itself be composed of many
individual artifacts. Some examples to artifacts are

* documents
* binaries produced by the build process
* container images
* test suites

A composition represents set of source, artifact and documentation items.
Compositions can be very simple, consisting of a single item, or very large,
containing any number of items when compositions are nested.

In OPNFV, the emphasis is mostly on compositions and rather then standalone
artifacts. What is written in the remainder of this document uses the words
artifact and composition interchangeably and the ideas respresented there
may equally be applicable to both depending on the context.

OPNFV scenarios can be seen as composition examples.

CI Loop
-------

CI Loops are independent entities to execute certain activities that can take
place in CI at any given time in order to test/qualify artifacts or
compositions and provide feedback.

CI Loops run repeatedly and as independently as possible from other loops, do
not call each other directly (no RPC, etc) and with no metadata passed directly
between them.

CI Loops can be run when certain things happen. Examples are Gerrit events,
events emitted by other CI Loops in a CI Flow, events published by upstream
projects, via timer, polling, or manually.

The feedback provided by CI Loops can be as simple as basic SUCCESS and FAILURE
values with the possibility of accessing further information such as the logs
produced at the end of the loop or historical information in the form of
trends.

Apart from providing feedback, the most crucial outcome of
CI Loops are the Confidence Levels applied on artifacts or compositions which
will then be used for qualifying those versions in order to carry them over
in the CI Flow.

A sample CI Loop is verify.

CI Flow
-------

CI Flows are constituted by linking different activities together. In this
context, a CI loop corresponds to certain activity and flow then becomes
linked loops.

Anything that results in the triggering of the initial CI Loop in given CI Flow
is the trigger for the CI Flow as well. An important point to highlight here is
that not all versions of all artifacts can go till the end of the CI Flow if
they fail anywhere within the flow, resulting in interruption of the flow.

CI Loops in CI Flow are run in serialized manner but not for any given
artifact. The further loops in a CI Flow are available only for the artifacts
that were qualified/deemed to be good by the preceding loops in CI Flow. For
example, if a version of an artifact fails to pass post-merge loop, it simply
gets discarded and not carried over to the next loop, which is daily in this
example.

The order in CI Flow is important as well since only the artifacts with the
right level of confidence should be carried over to the next loop that is worth
testing on that level. Artifacts can not skip loops.

The output of a CI Flow could be weekly "stable" releases or candidates for
official release depending on the confidence level reached.

A sample CI Flow could be verify, post-merge and daily.

Confidence Level
----------------

A Confidence Level(CL) is a simple key value pair indicating a quality stamp
attached to a version of an artifact or a composition in order to qualify the
version as candidate for further testing or candidate for release.

CLs are applied by the loops and gained by the artifacts while they traverse
through CI Flow.

Stamped versions of the artifacts can be carried over to the next loops in CI
flow to do more extensive testing. A version of the artifact can have 0..n CLs,
each given and corresponding to a loop in CI.

In perfect world, the artifacts should be composed using only the "good" CLs.

CLs are part of the artifact metadata.

The keys used in CLs match to the loop names and the values are the values are
simple status codes; SUCCESS and FAILURE. The values are also used by Jenkins.

A sample CL is "daily": "SUCCESS"

Promotion
---------

Loops in CI verify/test the artifacts that reach to that loop. Outcomes of the
loops (loop verdicts) are used for identifying and applying CLs. By doing this
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

The reevaluation of the content of the loops and promotion criterias can be
triggered by the use of the feedback provided by the loops themselves. If the
loops always end with succesfull results consistently  completions, it may be
time to employ tougher pass criteria since the quality is so high than what it
was before when the criteria was first set. The opposite is possible as well; if
things always fail, the criteria may need to be loosen by reducing the test
scope.

Based on the content/scope of the loops, time to run them can vary; from minutes
to hours, and sometimes days and time it takes to run them is another factor to
be taken into accout while constructing loops and setting the scope for them.

Setting the Promotion Criterias for the Scenarios
=================================================

TBD

References
==========

[1] https://en.wikipedia.org/wiki/Artifact_(software_development)

