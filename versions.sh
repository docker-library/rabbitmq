#!/usr/bin/env bash
# vim:noet:
set -Eeuo pipefail

declare -A alpineVersions=(
	[3.13]='3.22'
	[4.0]='3.22'
	[4.1]='3.22'
	[4.2]='3.22'
)

declare -A ubuntuVersions=(
	[3.13]='24.04'
	[4.0]='24.04'
	[4.1]='24.04'
	[4.2]='24.04'
)

# https://www.rabbitmq.com/which-erlang.html ("Maximum supported Erlang/OTP")
declare -A otpMajors=(
	[3.13]='26'
	[4.0]='27'
	[4.1]='27'
	[4.2]='27'
)

# https://www.openssl.org/policies/releasestrat.html
# https://www.openssl.org/source/
declare -A opensslMajors=(
	[3.13]='3.1'
	[4.0]='3.5'
	[4.1]='3.5'
	[4.2]='3.5'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( "${!otpMajors[@]}" )
	# try RC releases after doing the non-RCs so we can check whether they're newer (and thus whether we should care)
	versions+=( "${versions[@]/%/-rc}" )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	export version

	rcVersion="${version%-rc}"
	rcGrepV='-v'
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi
	rcGrepV+=' -E'
	rcGrepExpr='beta|milestone|rc'

	githubTags=( $(
		git ls-remote --tags https://github.com/rabbitmq/rabbitmq-server.git \
			"refs/tags/v${rcVersion}"{'','.*','-*','^*'} \
			| cut -d'/' -f3- \
			| cut -d'^' -f1 \
			| { grep $rcGrepV -- "$rcGrepExpr" || :; } \
			| sort -urV
	) )

	fullVersion=
	githubTag=
	for possibleTag in "${githubTags[@]}"; do
		fullVersion="$(
			{
				# thanks GitHub...
				wget -qO- "https://github.com/rabbitmq/rabbitmq-server/releases/expanded_assets/$possibleTag" \
				|| wget -qO- "https://github.com/rabbitmq/rabbitmq-server/releases/tag/$possibleTag"
			} | grep -oE "/rabbitmq-server-generic-unix-${rcVersion}([.-].+)?[.]tar[.]xz" \
				| head -1 \
				| sed -r "s/^.*(${rcVersion}.*)[.]tar[.]xz/\1/" \
				|| :
		)"
		if [ -n "$fullVersion" ]; then
			githubTag="$possibleTag"
			break
		fi
	done
	if [ -z "$fullVersion" ] || [ -z "$githubTag" ]; then
		echo >&2 "warning: failed to get full version for '$version'; skipping"
		continue
	fi
	export fullVersion

	# if this is a "-rc" release, let's make sure the release it contains isn't already GA (and thus something we should not publish anymore)
	export rcVersion
	if [ "$rcVersion" != "$version" ] && rcFullVersion="$(jq <<<"$json" -r '.[env.rcVersion].version // ""')" && [ -n "$rcFullVersion" ]; then
		latestVersion="$({ echo "$fullVersion"; echo "$rcFullVersion"; } | sort -V | tail -1)"
		if [[ "$fullVersion" == "$rcFullVersion"* ]] || [ "$latestVersion" = "$rcFullVersion" ]; then
			# "x.y.z-rc1" == x.y.z*
			echo >&2 "warning: skipping/removing '$version' ('$rcVersion' is at '$rcFullVersion' which is newer than '$fullVersion')"
			continue
		fi
	fi

	otpMajor="${otpMajors[$rcVersion]}"
	otpVersions=( $(
		git ls-remote --tags https://github.com/erlang/otp.git \
			"refs/tags/OTP-$otpMajor.*"\
			| cut -d'/' -f3- \
			| cut -d'^' -f1 \
			| cut -d- -f2- \
			| sort -urV
	) )
	otpVersion=
	for possibleVersion in "${otpVersions[@]}"; do
		if otpSourceSha256="$(
			wget -qO- "https://github.com/erlang/otp/releases/download/OTP-$possibleVersion/SHA256.txt" \
				| awk -v v="$possibleVersion" '$2 == "otp_src_" v ".tar.gz" { print $1 }'
		)"; then
			otpVersion="$possibleVersion"
			break
		fi
	done
	if [ -z "$otpVersion" ]; then
		echo >&2 "warning: failed to get Erlang/OTP version for '$version' ($fullVersion); skipping"
		continue
	fi
	export otpVersion otpSourceSha256

	opensslMajor="${opensslMajors[$rcVersion]}"
	# grab versions from upstream and ignore any alpha/beta releases
	opensslVersions=( $(
	git ls-remote --tags https://github.com/openssl/openssl.git \
			"refs/tags/openssl-$opensslMajor.*"\
			| cut -d'/' -f3- \
			| cut -d'^' -f1 \
			| cut -d- -f2- \
			| grep -vE -- '-[A-Za-z]+' \
			| sort -urV
	) )
	opensslVersion=
	for possibleVersion in "${opensslVersions[@]}"; do
		if opensslSourceSha256="$(wget -qO- "https://github.com/openssl/openssl/releases/download/openssl-$possibleVersion/openssl-$possibleVersion.tar.gz.sha256")"; then
			opensslVersion="$possibleVersion"
			break
		fi
	done
	if [ -z "$opensslVersion" ]; then
		echo >&2 "warning: failed to get OpenSSL version for '$version' ($fullVersion); skipping"
		continue
	fi
	export opensslVersion opensslSourceSha256

	# OpenSSL 3.0.5's sha256 file starts with a single space 😬
	opensslSourceSha256="${opensslSourceSha256# }"
	# OpenSSL 3.1.8+ and 3.3.3+ now include the filename
	opensslSourceSha256="${opensslSourceSha256%% *}"

	alpineVersion="${alpineVersions[$rcVersion]}"
	export alpineVersion

	ubuntuVersion="${ubuntuVersions[$rcVersion]}"
	export ubuntuVersion

	if [[ ${rabbitmqadminVersion:-undefined} == 'undefined' ]]
	then
		rabbitmqadminVersion="$(wget --quiet --output-document=- \
			--header='Accept: application/vnd.github+json' \
			--header='X-GitHub-Api-Version: 2022-11-28' \
			https://api.github.com/repos/rabbitmq/rabbitmqadmin-ng/releases/latest | jq -r '.tag_name')"
		rabbitmqadminVersion="${rabbitmqadminVersion#v}" # NOTE: removes leading "v"
		readonly rabbitmqadminVersion

		readonly rabbitmqadminSourceZipUrl="https://github.com/rabbitmq/rabbitmqadmin-ng/archive/refs/tags/v$rabbitmqadminVersion.zip"
		wget --quiet --output-document=rmqadmin.zip "$rabbitmqadminSourceZipUrl"
		rabbitmqadminSourceSha256="$(sha256sum rmqadmin.zip | cut -d' ' -f1)"
		# TODO rm -f rmqadmin.zip
		readonly rabbitmqadminSourceSha256

		wget --quiet --output-document=rustup-init.sh https://sh.rustup.rs
		rustInitSha256="$(sha256sum rustup-init.sh | cut -d' ' -f1)"
		# TODO rm -f rustup-init.sh
		readonly rustInitSha256

		export rustInitSha256 rabbitmqadminVersion rabbitmqadminSourceSha256
	fi

	echo "$version: $fullVersion (otp $otpVersion, openssl $opensslVersion, rabbitmqadmin $rabbitmqadminVersion, alpine, $alpineVersion, ubuntu $ubuntuVersion)"

	json="$(
		jq <<<"$json" -c '
			.[env.version] = {
				version: env.fullVersion,
				openssl: {
					version: env.opensslVersion,
					sha256: env.opensslSourceSha256,
				},
				otp: {
					version: env.otpVersion,
					sha256: env.otpSourceSha256,
				},
				alpine: {
					version: env.alpineVersion
				},
				ubuntu: {
					version: env.ubuntuVersion
				},
				rabbitmqadmin: {
					version: env.rabbitmqadminVersion,
					sha256: env.rabbitmqadminSourceSha256,
					rustInitSha256: env.rustInitSha256,
				},
			}
		'
	)"

	# make sure RCs and releases have corresponding pairs
	json="$(jq <<<"$json" -c '
		.[
			env.rcVersion
			+ if env.version == env.rcVersion then
				"-rc"
			else "" end
		] //= null
	')"
done

jq <<<"$json" -S . > versions.json
