.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Ericsson AB and Others

.. Links
.. _OpenDaylight COE: https://wiki.opendaylight.org/view/COE:Main
.. _setting-up-coe-dev-environment: https://github.com/opendaylight/coe/blob/master/docs/setting-up-coe-dev-environment.rst
.. _ansible-opendaylight: https://git.opendaylight.org/gerrit/gitweb?p=integration/packaging/ansible-opendaylight.git;a=tree

This spec proposes adding an k8-odl-coe XCI scenario for OpenDaylight as the
networking provider for Kubernetes using the OpenDaylight COE (Container
Orchestration Engine) and NetVirt projects.

Problem Description
===================

Currently OpenDaylight COE is not part of any scenario, so OpenDaylight's
advanced networking capabilities are not leveraged in any Kubernetes
deployments. This spec proposes a reference platform for deployments that want
to use OpenDaylight as a networking backend for Kubernetes.

Minimum Hardware Requirements
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Hardware for Kubernetes Master Node(s)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* RAM:    16 GB (20 GB for ha flavor i.e. for OpenDaylight Clustering)
* HD:     80 GB
* vCores: 6

Hardware for Kubernetes Worker Node(s)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* RAM:    12 GB
* HD:     80 GB
* vCores: 6

The supported flavors are mini, noha and ha.

Proposed Change
===============

1. Provide Pod Descriptor Files (PDF) and IDF (TODO Descriptor Files) specific
   to this scenario to install Kubernetes with OpenDaylight COE.
2. Introduce a new scenario k8-odl-coe in releng-xci-scenarios repository.
3. Reuse the role from k8-nosdn-nofeature scenario to install Kubernetes.
   It has kube_network_plugin option to 'cloud' in k8s-cluster.yml so that
   Kubespray doesn't configure networking between pods. This enables
   OpenDaylight to be chosen as a networking backend in steps 4-7.
4. Enhance upstream `ansible-opendaylight`_ role to deploy OpenDaylight with
   COE Watcher on k8s master node(s) and CNI plugin on the k8s master and
   worker node(s).
5. Add the required Ansible tasks in k8-odl-coe role to direct XCI and
   ansible-opendaylight role to configure k8s with OpenDaylight as the
   networking backend for pod connectivity.
6. Run the Health Check by testing the pods' connectivity.

The COE Watcher binary and COE CNI plugin are built from OpenDaylight COE
source code. The user will have flexibility to choose its SHA from XCI's
ansible-role-requirements.yml file.

Code Impact
-----------

Code specific to the k8-odl-coe scenario will be added to the xci/scenarios
directory of the releng-xci-scenarios repository.

User Guide
----------

No user guide will be provided.

Implementation
==============

See the Proposed Change section.

Assignee(s)
-----------

Primary assignees:

* Prem Sankar G (premsa)
* Periyasamy Palanisamy (epalper)
* Fatih Degirmenci (fdegir)

Work Items
----------

1. Enhance the akka.conf.j2 in upstream ansible-opendaylight role to work
   with k8s deployments (i.e. run ODL cluster on k8s master nodes).
   Currently this works only for the deployments based on Openstack-Ansible.
2. Enhance upstream ansible-opendaylight role to install odl-netvirt-coe and
   odl-restconf Karaf features, build COE watcher and CNI plugin binaries
   from source.
3. Implement configure-kubenet.yml to choose OpenDaylight COE as the
   networking backend.
4. Implement Health Check tests.

Glossary
--------
