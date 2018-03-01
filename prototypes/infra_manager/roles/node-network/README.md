Nodes network configuration
===========================

Prepare the network configuration on the nodes using PDF, IDF and XCI_FLAVOR.


Requirements
------------

none

Role Variables
--------------

set_bridges: setup bridge on interface or not. Default: false
             interface to bridge mapping is defined in
             default/main.yml - bridge_mapping

Dependencies
------------

none

Example Playbook
----------------

- hosts: all
  gather_facts: true
  become: true
  vars_files:
    - var/idf.yml
    - var/pdf.yml
    - var/opnfv.yml
  roles:
    - role: node-network


License
-------

Apache 2
