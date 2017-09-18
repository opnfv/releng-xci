# Kubernetes Role

## Introduction

Aim is to propose a role that onboard a k8s cluster using rancher 2.0

## Hosts configuration

You need a server (HA work not done), one or several nodes and a jumphost

Simplest example for host file:

```
[server]
huawei1.k8s.opnfv.fr ansible_user=debian

[node:children]
server

[jumphost:children]
server

[k8s-cluster:children]
server
node
jumphost
```

# TODO

- [] HA Mode for server
- [] Deploy Registry Cache for Docker
- [] Functionnal tests
