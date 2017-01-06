#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

debianVersion="$(curl -sSL 'http://www.rabbitmq.com/debian/dists/testing/main/binary-amd64/Packages' | grep -m1 -A10 '^Package: rabbitmq-server$' | grep -m1 '^Version: ' | cut -d' ' -f2)"

rabbitmqVersion="${debianVersion%%-*}"

rabbitmqClustererVersion="$(curl -sSL https://github.com/rabbitmq/rabbitmq-clusterer/releases/latest | awk '/<title>Release/ {print substr($2,2)}')"

set -x
sed -ri 's/^(ENV RABBITMQ_VERSION) .*/\1 '"$rabbitmqVersion"'/' Dockerfile
sed -ri 's/^(ENV RABBITMQ_DEBIAN_VERSION) .*/\1 '"$debianVersion"'/' Dockerfile
sed -ri 's/^(ENV RABBITMQ_CLUSTERER_VERSION) .*/\1 '"$rabbitmqClustererVersion"'/' Dockerfile
