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
	rcVersion="${version%-rc}"
	rcGrepV='-v'
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi
	rcGrepV+=' -E'
	rcGrepExpr='beta|milestone|rc'

	githubTag="$(
		git ls-remote --tags https://github.com/rabbitmq/rabbitmq-server.git \
			"refs/tags/rabbitmq_v${rcVersion//./_}_*" \
			"refs/tags/v${rcVersion}.*" \
		| cut -d'/' -f3- \
		| grep $rcGrepV -- "$rcGrepExpr" \
		| sort -V \
		| tail -1
	)"

	githubReleaseUrl="https://github.com/rabbitmq/rabbitmq-server/releases/tag/$githubTag"
	fullVersion="$(
		curl -fsSL "$githubReleaseUrl" \
			| grep -o "/rabbitmq-server-generic-unix-${rcVersion}[.].*[.]tar[.]xz" \
			| head -1 \
			| sed -r "s/^.*(${rcVersion}.*)[.]tar[.]xz/\1/"
	)"
	debianVersion="$(
		curl -fsSL "$githubReleaseUrl" \
			| grep -o "/rabbitmq-server_${fullVersion//-/.}.*_all[.]deb" \
			| head -1 \
			| sed -r "s/^.*(${rcVersion}.*)_all[.]deb/\1/"
	)"

	if [ -z "$fullVersion" ] || [ -z "$debianVersion" ]; then
		echo >&2 "warning: failed to get full ('$fullVersion') or Debian ('$debianVersion') version for '$version'; skipping"
		continue
	fi

	echo "$version: $fullVersion"

	for variant in alpine debian; do
		[ -f "$version/$variant/Dockerfile" ] || continue

		sed -ri \
			-e 's/^(ENV RABBITMQ_VERSION) .*/\1 '"$fullVersion"'/' \
			-e 's/^(ENV RABBITMQ_GITHUB_TAG) .*/\1 '"$githubTag"'/' \
			-e 's/^(ENV RABBITMQ_DEBIAN_VERSION) .*/\1 '"$debianVersion"'/' \
			"$version/$variant/Dockerfile"
		cp -a "$version/docker-entrypoint.sh" "$version/$variant/"

		managementFrom="rabbitmq:$version"
		if [ "$variant" = 'alpine' ]; then
			managementFrom+='-alpine'
			sed -i 's/gosu/su-exec/g' "$version/$variant/docker-entrypoint.sh"
		fi
		sed -ri 's/^(FROM) .*$/FROM '"$managementFrom"'/' "$version/$variant/management/Dockerfile"

		travisEnv='\n  - VERSION='"$version"' VARIANT='"$variant$travisEnv"
	done
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
