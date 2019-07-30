Docker image to build OPNFV XCI OS images using diskimage-builder. It can build opensuse, ubuntu and centos images.
To change the distro version, edit line 7 of the file do-build.sh, where the flavors variable is defined

USERGUIDE TO BUILD
==================

1 - Build the image first using the provided Dockerfile:

docker build -t xci/builder .

2 - Then you execute the build inside the container choosing the distro with:

docker run --rm --privileged=true -e ONE_DISTRO=<opensuse|centos|ubuntu> -t -v `pwd`:`pwd` -w `pwd` xci/builder '/usr/bin/do-build.sh'

