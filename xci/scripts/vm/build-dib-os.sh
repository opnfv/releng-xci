#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2017 SUSE LINUX GmbH.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

ONE_DISTRO=${1:-}

docker_cmd="sudo docker"
# See if we can run docker as regular user.
docker ps &> /dev/null && docker_cmd="docker"
docker_name="docker_xci_builder_${ONE_DISTRO:-all}"

# Destroy previous containers
if eval $docker_cmd ps -a | grep -q ${docker_name} &>/dev/null; then
	echo "Destroying previous container..."
	eval $docker_cmd rm -f ${docker_name}
fi

# Prepare new working directory
dib_workdir="${XCI_CACHE_DIR:-${HOME}/.cache/opnfv_xci_deploy}/clean_vm/images"
[[ ! -d $dib_workdir ]] && mkdir -p $dib_workdir

# Record our information
uid=$(id -u)
gid=$(id -g)

sudo chmod 777 -R $dib_workdir
sudo chown $uid:$gid -R $dib_workdir

echo "Getting the latest docker image..."
eval $docker_cmd pull hwoarang/docker-dib-xci:latest

# Get rid of stale files
rm -rf $dib_workdir/${ONE_DISTRO}.qcow2 \
	$dib_workdir/${ONE_DISTRO}.sha256.txt \
	$dib_workdir/${ONE_DISTRO}.d
echo "Initiating dib build..."
eval $docker_cmd run --name ${docker_name} \
	--rm --privileged=true -e ONE_DISTRO=${ONE_DISTRO} \
	-t -v $dib_workdir:$dib_workdir -w $dib_workdir \
	hwoarang/docker-dib-xci '/usr/bin/do-build.sh'
sudo chown $uid:$gid $dib_workdir/${ONE_DISTRO}.qcow2
