SDF prototype for xci-baremetal
==================

This prototype is based on a template system that shall avoid divergences of a
same configuration for all sdf files. By that way, a same configuration will
evolve in all sdf at the same time.

Installer have to agree on the same convention as much as possible, but specific
configuration is possible by this sytem.


usage
--------------------
./generate.py <scenario name> <target folder>

example: ```./generate.py os-nosdn-onap-ha ./``` will generate a sdf file in
this directory.


scenario exclusion
------------------
using the config file ```config.yaml```, it is possible to exclude deployment
types (baremetal vs virtual) and support features only on listed installers.
(the actual config file is only an example, not a list reflecting actual
supported scenarios)


node job and availability
--------------------
To avoid the usage of openstack related name in IDF, the convention is taken
to specify hardware workload: __infra__, __worker__ are
used to mark a job type on a node, and the scenario will translate that to
the correct naming of the VIM. A third workload is set to mark a node as infra
or worker job, depending of availability of the scenario: __infra_or_worker__


templates
--------------------

by default, the template used is ```templates/scenarios/generic_by_name.yaml.j2```;
but if another a file with a scenario name is present in the scenario folder it
will be used.
