#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

url='git://github.com/docker-library/rabbitmq'

echo '# maintainer: InfoSiftr <github@infosiftr.com> (@infosiftr)'

commit="$(git log -1 --format='format:%H' -- .)"
fullVersion="$(grep -m1 'ENV RABBITMQ_VERSION ' Dockerfile | cut -d' ' -f3)"

# fullVersion is a Debian version and we only care about the RabbitMQ version, so let's trim -*
fullVersion="${fullVersion%%-*}"

versionAliases=()
while [ "${fullVersion%.*}" != "$fullVersion" ]; do
	versionAliases+=( $fullVersion )
	fullVersion="${fullVersion%.*}"
done
versionAliases+=( $fullVersion latest )

echo
for va in "${versionAliases[@]}"; do
	echo "$va: ${url}@${commit}"
done
