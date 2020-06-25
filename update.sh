#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

# https://www.rabbitmq.com/which-erlang.html ("Maximum supported Erlang/OTP")
declare -A otpMajors=(
	[3.7]='22'
	[3.8]='23'
)
declare -A otpHashCache=()

# https://www.openssl.org/policies/releasestrat.html
# https://www.openssl.org/source/
declare -A opensslMajors=(
	[3.7]='1.1'
	[3.8]='1.1'
)

# https://www.openssl.org/community/omc.html
opensslPgpKeys=(
	# Matt Caswell
	0x8657ABB260F056B1E5190839D9C4D26D0E604491

	# Mark J. Cox
	0x5B2545DAB21995F4088CEFAA36CEE4DEB00CFE33

	# Paul Dale
	0xED230BEC4D4F2518B9D7DF41F0DB4D21C1D35231

	# Tim Hudson
	0xC1F33DD8CE1D4CC613AF14DA9195C48241FBF7DD

	# Richard Levitte
	0x7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C

	# Kurt Roeckx
	0xE5E52560DD91C556DDBDA5D02064C53641C25E5D
)
# TODO auto-generate / scrape this list from the canonical upstream source instead

for version in "${versions[@]}"; do
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

	otpMajor="${otpMajors[$rcVersion]}"
	otpVersion="$(
		git ls-remote --tags https://github.com/erlang/otp.git \
			"refs/tags/OTP-$otpMajor.*"\
			| cut -d'/' -f3- \
			| cut -d'^' -f1 \
			| cut -d- -f2- \
			| sort -uV \
			| tail -1
	)"
	if [ -z "$otpVersion" ]; then
		echo >&2 "warning: failed to get Erlang/OTP version for '$version' ($fullVersion); skipping"
		continue
	fi
	otpSourceSha256="${otpHashCache[$otpVersion]:-}"
	if [ -z "$otpSourceSha256" ]; then
		# TODO these aren't published anywhere (nor is the tarball we download even provided by Erlang -- it's simply a "git archive" tar provided by GitHub)...
		otpSourceSha256="$(wget -qO- "https://github.com/erlang/otp/archive/OTP-$otpVersion.tar.gz" | sha256sum | cut -d' ' -f1)"
		otpHashCache[$otpVersion]="$otpSourceSha256"
	fi

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

	echo "$version: $fullVersion"

	for variant in alpine ubuntu; do
		[ -f "$version/$variant/Dockerfile" ] || continue

		sed -e "s!%%OPENSSL_VERSION%%!$opensslVersion!g" \
			-e "s!%%OPENSSL_SOURCE_SHA256%%!$opensslSourceSha256!g" \
			-e "s!%%OPENSSL_PGP_KEY_IDS%%!${opensslPgpKeys[*]}!g" \
			-e "s!%%OTP_VERSION%%!$otpVersion!g" \
			-e "s!%%OTP_SOURCE_SHA256%%!$otpSourceSha256!g" \
			-e "s!%%RABBITMQ_VERSION%%!$fullVersion!g" \
			"Dockerfile-$variant.template" \
			> "$version/$variant/Dockerfile"

		cp -a docker-entrypoint.sh "$version/$variant/"

		managementFrom="rabbitmq:$version"
		installPython='apt-get update; apt-get install -y --no-install-recommends python3; rm -rf /var/lib/apt/lists/*'
		if [ "$variant" = 'alpine' ]; then
			managementFrom+='-alpine'
			installPython='apk add --no-cache python3'
			sed -i 's/gosu/su-exec/g' "$version/$variant/docker-entrypoint.sh"
		fi
		sed -e "s!%%FROM%%!$managementFrom!g" \
			-e "s!%%INSTALL_PYTHON%%!$installPython!g" \
			Dockerfile-management.template \
			> "$version/$variant/management/Dockerfile"
	done
done
