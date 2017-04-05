#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

travisEnv=
for version in "${versions[@]}"; do
	# TODO figure out what multi-version looks like here? :(
	debianVersion="$(curl -sSL 'http://www.rabbitmq.com/debian/dists/testing/main/binary-amd64/Packages' | grep -m1 -A10 '^Package: rabbitmq-server$' | grep -m1 '^Version: ' | cut -d' ' -f2)"
	# https://github.com/docker-library/rabbitmq/pull/121#issuecomment-271816323

	rabbitmqVersion="${debianVersion%%-*}"

	if [[ "$rabbitmqVersion" != "$version".* ]]; then
		echo >&2 "warning: $rabbitmqVersion doesn't appear to be $version -- skipping for now"
		continue
	fi

	for variant in alpine debian; do
		(
			set -x
			sed -ri \
				-e 's/^(ENV RABBITMQ_VERSION) .*/\1 '"$rabbitmqVersion"'/' \
				-e 's/^(ENV RABBITMQ_DEBIAN_VERSION) .*/\1 '"$debianVersion"'/' \
				"$version/$variant/Dockerfile"
		)

		travisEnv='\n  - VERSION='"$version"' VARIANT='"$variant$travisEnv"
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
