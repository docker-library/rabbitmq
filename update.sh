#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

fullVersion="$(curl -sSL 'http://www.rabbitmq.com/debian/dists/testing/main/binary-amd64/Packages' | grep -m1 -A10 '^Package: rabbitmq-server$' | grep -m1 '^Version: ' | cut -d' ' -f2)"

# fullVersion is a Debian version and we only care about the RabbitMQ version for tags, so let's trim -*
tagVersion="${fullVersion%%-*}"

set -x
sed -ri 's/^(ENV RABBITMQ_VERSION) .*/\1 '"$fullVersion"'/' Dockerfile
