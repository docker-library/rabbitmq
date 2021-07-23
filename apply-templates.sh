#!/usr/bin/env bash
set -Eeuo pipefail

[ -f versions.json ] # run "versions.sh" first

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

jqt='.jq-template.awk'
if [ -n "${BASHBREW_SCRIPTS:-}" ]; then
	jqt="$BASHBREW_SCRIPTS/jq-template.awk"
elif [ "$BASH_SOURCE" -nt "$jqt" ]; then
	wget -qO "$jqt" 'https://github.com/docker-library/bashbrew/raw/5f0c26381fb7cc78b2d217d58007800bdcfbcfa1/scripts/jq-template.awk'
fi

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#

	EOH
}

for version; do
	export version

	for variant in alpine ubuntu; do
		export variant

		echo "processing $version/$variant ..."

		{
			generated_warning
			gawk -f "$jqt" "Dockerfile-$variant.template"
		} > "$version/$variant/Dockerfile"

		entrypoint='docker-entrypoint.sh'
		rcVersion="${version%-rc}"
		if [ "$rcVersion" = '3.8' ]; then
			entrypoint="docker-entrypoint-$rcVersion.sh"
		fi
		cp -a "$entrypoint" "$version/$variant/docker-entrypoint.sh"

		if [ "$rcVersion" != '3.8' ]; then
			cp 10-default-guest-user.conf "$version/$variant/"
		fi

		if [ "$variant" = 'alpine' ]; then
			sed -i -e 's/gosu/su-exec/g' "$version/$variant/docker-entrypoint.sh"
		fi

		echo "processing $version/$variant/management ..."

		{
			generated_warning
			gawk -f "$jqt" Dockerfile-management.template
		} > "$version/$variant/management/Dockerfile"
	done
done
