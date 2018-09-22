#!/bin/bash

set -x

ROOT=$(mktemp -d)
BUILD=$(mktemp -d)
DOCKER_CTX=$(mktemp -d)

BASH_VERSION="4.4"
COREUTILS_VERSION="8.30"
GAWK_VERSION="4.2.1"
GREP_VERSION="3.1"
KUBECTL_VERSION="v1.10.8"

BASH_URL="https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz"
COREUTILS_URL="https://ftp.gnu.org/gnu/coreutils/coreutils-${COREUTILS_VERSION}.tar.xz"
GAWK_URL="https://ftp.gnu.org/gnu/gawk/gawk-${GAWK_VERSION}.tar.xz"
GREP_URL="https://ftp.gnu.org/gnu/grep/grep-${GREP_VERSION}.tar.xz"
KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

cp Dockerfile ${DOCKER_CTX}

pushd ${BUILD}

curl -LO ${BASH_URL}
curl -LO ${COREUTILS_URL}
curl -LO ${GAWK_URL}
curl -LO ${GREP_URL}
curl -LO ${KUBECTL_URL}

# TODO(sdake) Validate signatures

tar -xf bash-${BASH_VERSION}.tar.gz
tar -xf coreutils-${COREUTILS_VERSION}.tar.xz
tar -xf gawk-${GAWK_VERSION}.tar.xz
tar -xf grep-${GREP_VERSION}.tar.xz

pushd bash-${BASH_VERSION}
./configure --without-bash-malloc LDFLAGS="-static" --prefix=${ROOT}
make install-strip
popd

pushd coreutils-${COREUTILS_VERSION}
./configure --enable-single-binary=shebangs LDFLAGS="-static" --prefix=${ROOT}
make install-strip
popd

pushd gawk-${GAWK_VERSION}
./configure LDFLAGS="-static" --prefix=${ROOT}
make install-strip
popd

pushd grep-${GREP_VERSION}
./configure LDFLAGS="-static" --prefix=${ROOT}
make install-strip
popd

strip -s kubectl
cp -a kubectl ${ROOT}/bin
install -s -m=755 kubectl ${ROOT}/bin

# remove build path context from shebange binaries for coreutils
pushd ${ROOT}
pushd bin
find . -size 1k -exec sed -i -e "s#$ROOT##g" {} \;
popd

tar -czf ${DOCKER_CTX}/root.tar.gz bin
popd #${ROOT}
popd #${BUILD)

docker build -t sdake/kubectl ${DOCKER_CTX}
echo "Done building static kubectl container"
