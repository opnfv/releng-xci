# Openstack install on baremetal OPNFV pods with OSA and Bifrost

# About the jumphost

The jumphost is a fresh ubuntu 16.04 install with a direct internet connection,
and a network interface linked with the openstack br-mgmt network.

This jumphost can be virtual.

The openstack nodes are split in two parts: 3 for controllers and 2 for computes

# About log servers

This server is not installed by bifrost today, and is an ubuntu VM
installed closed to the jumphost.

# Prepare baremetal description

Please take a non null time to prepare the default config files in vars/.

Now, the baremetal description is done using Pod Description Format and an
additionnal file name IDF for installer descrition format, containing
software parameters for a specific installer and a specific pod. Those file are
now in the config_sources/labs/lab/pod. __Please check carefully those files__

# Run everything:

The installation is done from the jumphost

./run.sh <lab> <pod>
ex: ./run.sh orange pod1
