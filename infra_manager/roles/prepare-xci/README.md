Prepare XCI
========

This role will just set a few variable in ansible, set a bunch of dirs
for config, venv, sources and scripts

Requirements
------------

None

Role Variables
--------------

Default variables:
* forks: set ansible forks number. Default: 10
* xci_root: the folder containing xci created files. Default: "/opt/xci"
* user: the user used by OPNFV. Default: opnfv

Variables:
* home: The home folder. Default to  "/home/{{ user }}"
* xci_configs_root: the folder containing OPNFV config files
* xci_venv_root: the folder containing OPNFV virtual environments
* xci_src_root: the folder containing OPNFV sources (from git or other)
* xci_log_root: the folder containing OPNFV logs
* xci_bin_root: the folder containing OPNFV scripts and bin
* ssh_certs_folder: the folder containing ssh public and private keys.
    default: .ssh folder in home

License
-------

Apache2

Author Information
------------------

David Blaisonneau (david.blaisonneau_AT_orange.com)
