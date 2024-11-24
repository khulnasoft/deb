#!/bin/bash

# Copyright 2020 - KhulnaSoft Authors <hikhulnasoft@posteo.de>
# SPDX-License-Identifier: MPL-2.0

set -eo pipefail

check_deps () {
  local deps=("curl" "fpm" "gpg" "dpkg-sig")
  set +e
  for dep in "${deps[@]}"; do
    if [ ! -x "$(which $dep)" ]; then
      echo "This script requires $dep to be installed, cannot continue"
      exit 1
    fi
  done
  set -e
}

download () {
  rm -rf bin && mkdir bin
  curl -sSL https://get.khulnasoft.com/$1 | tar -xvz -C bin
  if [ ! -f "bin/khulnasoft-linux-$2" ]; then
    echo "Tarball did not include binary for $2"
    exit 1
  fi
  curl https://keybase.io/hikhulnasoft/pgp_keys.asc | gpg --import
  gpg --verify "bin/khulnasoft-linux-$2.asc" "bin/khulnasoft-linux-$2"

  echo "Successfully downloaded binaries and verified signature."
}

package () {
  rm -f *.deb

  local stripped_version=$(echo $1 | cut -c 2-)
  local artifact="khulnasoft_${stripped_version}_${2}.deb"

  fpm \
    --maintainer "$META_MAINTAINER" \
    --url "$META_URL" \
    --license "$META_LICENSE" \
    --vendor "$META_VENDOR" \
    --description "$META_DESCRIPTION" \
    --after-install "after_install.sh" \
    --deb-systemd "khulnasoft.service" \
    -p $artifact \
    -s dir -t deb -n khulnasoft -v $stripped_version \
    bin/khulnasoft-linux-$2=/usr/local/bin/khulnasoft \
    khulnasoft.env=/etc/khulnasoft/

  dpkg-sig --sign builder $artifact

  echo "Successfully packaged and signed $artifact."
}

setup_vars () {
  source ./version
  source ./meta
  if [ -z "$KHULNASOFT_VERSION" ]; then
    echo "Expected KHULNASOFT_VERSION to be set, got none."
    exit 1
  fi
}

run () {
  check_deps
  setup_vars
  download $KHULNASOFT_VERSION $1
  package $KHULNASOFT_VERSION $1
}

run ${1:-amd64}
