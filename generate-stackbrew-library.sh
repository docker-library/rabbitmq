#!/usr/bin/env bash
set -Eeuo pipefail

declare -A aliases=(
	[3.12]='3 latest'
)
defaultVariant='ubuntu'

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r '
		to_entries
		# sort version numbers with highest first
		| sort_by(.key | split("[.-]"; "") | map(try tonumber // .))
		| reverse
		| map(if .value then .key | @sh else empty end)
		| join(" ")
	' versions.json)"
	eval "set -- $versions"
fi

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
				/^COPY/ {
					for (i = 2; i < NF; i++) {
						if ($i ~ /^--from=/) {
							next
						}
						print $i
					}
				}
			')
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -name Dockerfile -exec awk '
			/^FROM/ {
				if (index($2, ":") > 0 && index($2, "'"$repo"'") == 0) {
					print "'"$officialImagesUrl"'" $2
				}
			}' '{}' + | sort -u \
		| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'rabbitmq'

cat <<-EOH
# this file is generated via https://github.com/docker-library/rabbitmq/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/rabbitmq.git
Builder: buildkit
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version; do
	export version
	rcVersion="${version%-rc}"

	if ! fullVersion="$(jq -er '.[env.version] | if . then .version else empty end' versions.json)"; then
		# support running "generate-stackbrew-library.sh" on a singular "null" version ("3.10-rc" when the RC is older than the GA release, for example)
		continue
	fi

	# if this is a "-rc" release, let's make sure the release it contains isn't already GA (and thus something we should not publish anymore)
	export rcVersion
	if [ "$rcVersion" != "$version" ] && rcFullVersion="$(jq -r '.[env.rcVersion].version // ""' versions.json)" && [ -n "$rcFullVersion" ]; then
		latestVersion="$({ echo "$fullVersion"; echo "$rcFullVersion"; } | sort -V | tail -1)"
		if [[ "$fullVersion" == "$rcFullVersion"* ]] || [ "$latestVersion" = "$rcFullVersion" ]; then
			# "x.y.z-rc1" == x.y.z*
			continue
		fi
	fi

	versionAliases=()
	if [ "$version" = "$rcVersion" ]; then
		while [ "$fullVersion" != "$version" -a "${fullVersion%[.-]*}" != "$fullVersion" ]; do
			versionAliases+=( $fullVersion )
			fullVersion="${fullVersion%[.-]*}"
		done
	else
		versionAliases+=( $fullVersion )
	fi
	versionAliases+=(
		$version
		${aliases[$version]:-}
	)

	for variant in ubuntu alpine; do
		dir="$version/$variant"
		commit="$(dirCommit "$dir")"

		if [ "$variant" = "$defaultVariant" ]; then
			variantAliases=( "${versionAliases[@]}" )
		else
			variantAliases=( "${versionAliases[@]/%/-$variant}" )
			variantAliases=( "${variantAliases[@]//latest-/}" )
		fi

		variantParent="$(awk '
			/^FROM/ {
				if (index($2, ":") > 0) {
					print $2
					exit 0
				}
			}' "$dir/Dockerfile")"
		variantArches="${parentRepoToArches[$variantParent]}"

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $variantArches)
			GitCommit: $commit
			Directory: $dir
		EOE

		for subVariant in management; do
			subDir="$dir/$subVariant"
			commit="$(dirCommit "$subDir")"

			subVariantAliases=( "${versionAliases[@]/%/-$subVariant}" )
			subVariantAliases=( "${subVariantAliases[@]//latest-/}" )

			if [ "$variant" != "$defaultVariant" ]; then
				subVariantAliases=( "${subVariantAliases[@]/%/-$variant}" )
			fi

			echo
			cat <<-EOE
				Tags: $(join ', ' "${subVariantAliases[@]}")
				Architectures: $(join ', ' $variantArches)
				GitCommit: $commit
				Directory: $subDir
			EOE
		done
	done
done
