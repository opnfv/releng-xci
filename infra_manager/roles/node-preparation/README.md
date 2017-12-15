Role Name
=========

Do a brief preparation of a just installed node before passing to next step.
Install network packages, basic python packages

Requirements
------------

none

Role Variables
--------------

none

Dependencies
------------

none

Example Playbook
----------------

- hosts: all
  gather_facts: true
  vars_files:
    - var/idf.yml
  roles:
    - node-preparation

License
-------

Apache 2
