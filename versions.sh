#!/usr/bin/env bash
set -Eeuo pipefail

# https://www.rabbitmq.com/which-erlang.html ("Maximum supported Erlang/OTP")
declare -A otpMajors=(
	[3.8]='24'
	[3.9]='24'
)

# https://www.openssl.org/policies/releasestrat.html
# https://www.openssl.org/source/
declare -A opensslMajors=(
	[3.8]='1.1'
	[3.9]='1.1'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
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
			| grep $rcGrepV -- "$rcGrepExpr" \
			| sort -urV
	) )

	fullVersion=
	githubTag=
	for possibleTag in "${githubTags[@]}"; do
		fullVersion="$(
			wget -qO- "https://github.com/rabbitmq/rabbitmq-server/releases/tag/$possibleTag" \
				| grep -oE "/rabbitmq-server-generic-unix-${rcVersion}([.-].+)?[.]tar[.]xz" \
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
	opensslVersion="$(
		wget -qO- 'https://www.openssl.org/source/' \
			| grep -oE 'href="openssl-'"$opensslMajor"'[^"]+[.]tar[.]gz"' \
			| sed -e 's/^href="openssl-//' -e 's/[.]tar[.]gz"//' \
			| sort -uV \
			| tail -1
	)"
	if [ -z "$opensslVersion" ]; then
		echo >&2 "warning: failed to get OpenSSL version for '$version' ($fullVersion); skipping"
		continue
	fi
	opensslSourceSha256="$(wget -qO- "https://www.openssl.org/source/openssl-$opensslVersion.tar.gz.sha256")"
	export opensslVersion opensslSourceSha256

	echo "$version: $fullVersion (otp $otpVersion, openssl $opensslVersion)"

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
			}
		'
	)"
done

jq <<<"$json" -S . > versions.json
