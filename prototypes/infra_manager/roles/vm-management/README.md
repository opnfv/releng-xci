vm-management
=========

VM Management is used by OPNFV XCI to create VM for infra using PDF/IDF
definitions.

Requirements
------------

Virtualisation capabilities

Role Variables
--------------

All the infrastructure description is done inside yaml files:
  - pdf.yml: OPNFV Pod Description Format
  - idf.yml: OPNFV Installer Description Format
  - xci-hosts.yml: a clone of the pdf to add VM not described inside the PDF

* xci_hosts_image: the cloud image to deploy on opnfv_host. Default: ubuntu
* XCI_FLAVOR: [aio, mini, noha, ha] default: mini
* deploy_definitions: Describe the flavors

See commented file in defaults and vars for more options

Tags
----

This role can be runned by subset using tags:
 - install: install all requisites, pkgd and pip packages
 - clean: clean user libvirt network and libvirt nodes
 - deploy: create network and VMs
 - start: start xci_host that is build on a cloud image

Cleanup
-------

To clean installed VM and network just run this role with 'clean' tag.
Please note that you must run this role with the same PDF/IDF config files
you used for the deploy, or the cleaning will be partial.

This cleanup will not remove installed packages as it can be used by another pod

Dependencies
------------

No dependencies


Example Playbook
----------------

```
- hosts: localhost
  connection: local
  gather_facts: true
  vars_files:
    - var/opnfv.yml
    - var/pdf.yml
    - var/idf.yml
    - var/xci_hosts.yml
  roles:
    - role: vm-management
      vars:
        deploy_size: "{{ XCI_FLAVOR }}"
        xci_root: "/opt/xci/{{ xci.pod_name }}"
        xci_hosts_image: "{{ xci_hosts_images[XCI_DISTRO|lower()]}}"
```

License
-------

Apache 2

TODO
----

Author Information
------------------

david.blaisonneau@orange.com
