#!/bin/bash
TILLER_POD=$(kubectl get pods --all-namespaces | grep tiller | awk '{ print $2 }')
TILLER_NSPACE=$(kubectl get pods --all-namespaces | grep tiller | awk '{ print $1 }')
nohup bash -c "while true; do kubectl port-forward pod/$TILLER_POD -n $TILLER_NSPACE 44134:44134 &>/dev/null ; done &"
