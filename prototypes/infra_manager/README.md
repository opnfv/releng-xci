OPNFV Infra manager
===================

This set of playbooks intend to prepare infrastructure to receive OPNFV
deployment. Its config source is shared config files among all OPNFV installers:
 - PDF - Pod Description File: describing the hardware level of the
   infrastructure hosting the VIM
 - IDF - Installer Description File: A flexible file allowing installer to
   set specific parameters close to the infra settings, linked with the install
   sequence
This installer also used a xci_hosts definition, based on PDF, describing local
VMs required by the XCI installer (it can be more than one, to set a log server
or any other extra VMs)

goals
-----

The goals of this infra_manager are:
  - set all the servers (Virtual or Baremetal) ready to be used by an Installer.
  - configure a management IP, reachable using SSH
  - set an inventory of prepared nodes, including nodes' roles, nodes' IPs
    and interfaces (using the ansible inventory model)

Run
---

The infra manager runs in 2 steps:
- servers-prepare: it prepare the jumphost and creates as many VM as required
  by the PDF/IDF config (if not existing, the bridge will be created).
  In a Baremetal deployment it will only create the opnfv_host VMs that will
  host the server deployment tool (bifrost) and the VIM Installer.
- nodes-deploy: it install the server deployment tool (bifrost) and deploy
  all the nodes that are required by the VIM installer.

just Run
```
export XCI_FLAVOR=noha
./servers-prepare.sh
./nodes-deploy.sh

```

if you want to deploy all XCI in VM mode, with the installer deploy, just run:

```
./xci-deploy.sh
```

Philosophy
----------

Those roles, Bifrost in particular, are set to run 'as in official doc', it
implies that it may not be the cleaner way, but the one shared by external
projects.

Variables
---------

* XCI_FLAVOR: the model of deployment:
 * aio: All in One: all in the same VM
 * mini: 1 installer node (aka opnfv_host), 1 controller, 1 compute
 * noha: 1 installer node (aka opnfv_host), 1 controller, 2 compute
 * ha: 1 installer node (aka opnfv_host), 3 controller, 2 compute

Other variables are issued from PDF/IDF/xci_hosts
