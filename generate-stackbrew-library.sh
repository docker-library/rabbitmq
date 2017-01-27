#!/bin/bash
set -eu

defaultVariant='debian'

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

cat <<-EOH
# this file is generated via https://github.com/docker-library/rabbitmq/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/rabbitmq.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for variant in debian alpine; do
	commit="$(dirCommit "$variant")"

	fullVersion="$(git show "$commit":"$variant/Dockerfile" | awk '$1 == "ENV" && $2 == "RABBITMQ_VERSION" { print $3; exit }')"

	versionAliases=()
	while [ "${fullVersion%.*}" != "$fullVersion" ]; do
		versionAliases+=( $fullVersion )
		fullVersion="${fullVersion%.*}"
	done
	versionAliases+=(
		$fullVersion
		latest
	)

	variantAliases=( "${versionAliases[@]/%/-$variant}" )
	variantAliases=( "${variantAliases[@]//latest-/}" )

	if [ "$variant" = "$defaultVariant" ]; then
		variantAliases=( "${versionAliases[@]}" )
	fi

	echo
	cat <<-EOE
		Tags: $(join ', ' "${variantAliases[@]}")
		GitCommit: $commit
		Directory: $variant
	EOE

	for subVariant in management; do
		commit="$(dirCommit "$variant/$subVariant")"

		subVariantAliases=( "${versionAliases[@]/%/-$subVariant}" )
		subVariantAliases=( "${subVariantAliases[@]//latest-/}" )

		if [ "$variant" != "$defaultVariant" ]; then
			subVariantAliases=( "${subVariantAliases[@]/%/-$variant}" )
		fi

		echo
		cat <<-EOE
			Tags: $(join ', ' "${subVariantAliases[@]}")
			GitCommit: $commit
			Directory: $variant/$subVariant
		EOE
	done
done
