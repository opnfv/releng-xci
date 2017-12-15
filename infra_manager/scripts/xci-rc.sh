#!/bin/bash

# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 Orange and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

##
# Bug report function
##
submit_bug_report() {
  local lc="$BASH_COMMAND" rc=$?
  echo ""
  echo "---------------------------------------------------------------------"
  echo "Oh nooooo! The XCI servers deployment failed miserably :-("
  echo ""
  echo "If you need help, please choose one of the following options"
  echo "* #opnfv-pharos @ freenode network"
  echo "* opnfv-tech-discuss mailing list:"
  echo "  https://lists.opnfv.org/mailman/listinfo/opnfv-tech-discuss"
  echo "  Please prefix the subject with [XCI]"
  echo "* https://jira.opnfv.org (Release Engineering project)"
  echo ""
  echo "Do not forget to submit the following information on your bug report:"
  echo ""
  git diff --quiet && echo "releng-xci tree status: clean" \
    || echo "releng-xci tree status: local modifications"
  echo
  echo ">> Crash on command <<"
  echo
  echo $lc
  echo
  echo ">> Exit code <<"
  echo
  echo $rc
  echo
  echo ">> Environment variables <<"
  echo
  env |grep --color=never '\(OPNFV\|XCI\|OPENSTACK\|POD\)' |sed 's/^/export /'
  echo "---------------------------------------------------------------------"
}

##
# Print a clear banner
##
step_banner() {
  echo ""
  echo "====================================================================="
  echo "${XCI_RUN_SCRIPT}"
  date
  echo "${1}"
  echo "====================================================================="
  echo ""
}

##
# Warn if run as root
##
no_root_needed() {
  if [[ $(whoami) == "root" ]]; then
      echo "WARNING: This script should not be run as root!"
      echo "Elevated privileges are aquired automatically when necessary"
      echo "Waiting 10s to give you a chance to stop the script (Ctrl-C)"
      for x in $(seq 10 -1 1); do echo -n "$x..."; sleep 1; done
  fi
}

##
# Create a local ssh key if not present
##
create_local_ssh_key() {
  if [ ! -e "${HOME}/.ssh/id_rsa" ] ; then
    ssh-keygen -f  ${HOME}/.ssh/id_rsa -t rsa -N ''
  fi
}
