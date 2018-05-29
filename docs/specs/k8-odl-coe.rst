.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. SPDX-License-Identifier: CC-BY-4.0
.. Copyright 2018 Ericsson AB and Others

.. Links
.. _OpenDaylight COE: https://wiki.opendaylight.org/view/COE:Main
.. _COE - Kubernetes Integration Options: https://docs.google.com/presentation/d/1LrHPkoLPo6Rgc_DjpqOvUucKPFswaEcfNwO3Z2A3_TA/edit#slide=id.g21124fb95a_0_216
.. _setting-up-coe-dev-environment: https://github.com/opendaylight/coe/blob/master/docs/setting-up-coe-dev-environment.rst

This spec introduces the work required to include k8-odl-coe XCI scenario for
integrating OpenDaylight COE(Container Orchestration Engine) project which
brings OpenDaylight Networking (netvirt) capabilities for Kubernetes
environment.


Problem description
===================
Currently OpenDaylight COE is not part of any scenario to leverage advanced
networking capabilities of OpenDaylight for Kubernetes deployments. This proposal
provides a reference platform for these deployments which wants to use
OpenDaylight as a networking backend.

Recommended Minimum Hardware requirements:
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

On the Kubernetes master node(s):
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  * RAM:    16 GB (20 GB for ha flavor i.e. for OpenDaylight Clustering)
  * HD:     80 GB
  * vCores: 6

On the Kubernetes worker node(s):
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

  * RAM:    12 GB
  * HD:     80 GB
  * vCores: 6

The supported flavors are mini, noha and ha.


Proposed change
===============

1. Provide pdf & idf files specific to this scenario to install Kubernetes
   with OpenDaylight COE.

2. Introduce a new scenario k8-odl-coe in releng-xci-scenarios repository.

3. Reuse the role from k8-nosdn-nofeature scenario to install Kubernetes.
   It has kube_network_plugin option to 'cloud' in k8s-cluster.yml so that
   kubespray doesn't configure networking between pods. This enables
   OpenDaylight to be chosen as a networking backend in the steps 4-7.

4. Enhance upstream ansible-opendaylight role to deploy OpenDaylight with
   COE Watcher on k8s master node(s) and CNI plugin on the k8s worker
   node(s).

5. Add the required ansible tasks in k8-odl-coe role to direct XCI &
   ansible-opendaylight role to configure k8s with OpenDaylight as
   networking backend for PODs connectivity.

6. Run the Health check by testing the PODs connectivity.

The COE watcher binary and COE CNI plugin are built from OpenDaylight COE
source code. The user will have flexibility to choose its SHA from XCI's
ansible-role-requirements.yml file.


Code impact
-----------
k8-odl-coe scenario specific code will be placed under xci/scenarios
directory of releng-xci-scenarios repository.


Tentative User guide
--------------------
NA


Implementation
==============
See the Proposed change section.


Assignee(s)
-----------

Primary assignee:
  Prem Sankar G (premsa)
  Periyasamy Palanisamy (epalper)
  Fatih Degirmenci (fdegir)

Work items
----------
1. Enhance the akka.conf.j2 in upstream ansible-opendaylight role to work
   with k8s deployments (i.e. run ODL cluster on k8s master nodes).
   Currently this works only for the deployments based on Openstack-Ansible.
2. Enhance upstream ansible-opendaylight role to install odl-netvirt-coe and
   odl-restconf karaf features, build COE watcher and CNI plugin binaries
   from source.
3. Implement configure-kubenet.yml to choose OpenDaylight COE as the
   networking backend.
4. Implement Health check tests.

Glossary
--------