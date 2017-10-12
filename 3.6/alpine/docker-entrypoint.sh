#!/bin/bash
set -eu

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# allow the container to be started with `--user`
if [[ "$1" == rabbitmq* ]] && [ "$(id -u)" = '0' ]; then
	if [ "$1" = 'rabbitmq-server' ]; then
		chown -R rabbitmq /var/lib/rabbitmq
	fi
	exec su-exec rabbitmq "$BASH_SOURCE" "$@"
fi

# backwards compatibility for old environment variables
: "${RABBITMQ_SSL_CERTFILE:=${RABBITMQ_SSL_CERT_FILE:-}}"
: "${RABBITMQ_SSL_KEYFILE:=${RABBITMQ_SSL_KEY_FILE:-}}"
: "${RABBITMQ_SSL_CACERTFILE:=${RABBITMQ_SSL_CA_FILE:-}}"

# "management" SSL config should default to using the same certs
: "${RABBITMQ_MANAGEMENT_SSL_CACERTFILE:=$RABBITMQ_SSL_CACERTFILE}"
: "${RABBITMQ_MANAGEMENT_SSL_CERTFILE:=$RABBITMQ_SSL_CERTFILE}"
: "${RABBITMQ_MANAGEMENT_SSL_KEYFILE:=$RABBITMQ_SSL_KEYFILE}"

# Allowed env vars that will be read from mounted files (i.e. Docker Secrets):
fileEnvKeys=(
	default_user
	default_pass
)

# https://www.rabbitmq.com/configure.html
sslConfigKeys=(
	cacertfile
	certfile
	depth
	fail_if_no_peer_cert
	keyfile
	verify
)
managementConfigKeys=(
	"${sslConfigKeys[@]/#/ssl_}"
)
rabbitConfigKeys=(
	default_pass
	default_user
	default_vhost
	hipe_compile
	vm_memory_high_watermark
)
fileConfigKeys=(
	management_ssl_cacertfile
	management_ssl_certfile
	management_ssl_keyfile
	ssl_cacertfile
	ssl_certfile
	ssl_keyfile
)
allConfigKeys=(
	"${managementConfigKeys[@]/#/management_}"
	"${rabbitConfigKeys[@]}"
	"${sslConfigKeys[@]/#/ssl_}"
)

declare -A configDefaults=(
	[management_ssl_fail_if_no_peer_cert]='false'
	[management_ssl_verify]='verify_none'

	[ssl_fail_if_no_peer_cert]='true'
	[ssl_verify]='verify_peer'
)

haveConfig=
haveSslConfig=
haveManagementSslConfig=
for fileEnvKey in "${fileEnvKeys[@]}"; do file_env "RABBITMQ_${fileEnvKey^^}"; done
for conf in "${allConfigKeys[@]}"; do
	var="RABBITMQ_${conf^^}"
	val="${!var:-}"
	if [ "$val" ]; then
		if [ "${configDefaults[$conf]:-}" ] && [ "${configDefaults[$conf]}" = "$val" ]; then
			# if the value set is the same as the default, treat it as if it isn't set
			continue
		fi
		haveConfig=1
		case "$conf" in
			ssl_*) haveSslConfig=1 ;;
			management_ssl_*) haveManagementSslConfig=1 ;;
		esac
	fi
done
if [ "$haveSslConfig" ]; then
	missing=()
	for sslConf in cacertfile certfile keyfile; do
		var="RABBITMQ_SSL_${sslConf^^}"
		val="${!var}"
		if [ -z "$val" ]; then
			missing+=( "$var" )
		fi
	done
	if [ "${#missing[@]}" -gt 0 ]; then
		{
			echo
			echo 'error: SSL requested, but missing required configuration'
			for miss in "${missing[@]}"; do
				echo "  - $miss"
			done
			echo
		} >&2
		exit 1
	fi
fi
missingFiles=()
for conf in "${fileConfigKeys[@]}"; do
	var="RABBITMQ_${conf^^}"
	val="${!var}"
	if [ "$val" ] && [ ! -f "$val" ]; then
		missingFiles+=( "$val ($var)" )
	fi
done
if [ "${#missingFiles[@]}" -gt 0 ]; then
	{
		echo
		echo 'error: files specified, but missing'
		for miss in "${missingFiles[@]}"; do
			echo "  - $miss"
		done
		echo
	} >&2
	exit 1
fi

# set defaults for missing values (but only after we're done with all our checking so we don't throw any of that off)
for conf in "${!configDefaults[@]}"; do
	default="${configDefaults[$conf]}"
	var="RABBITMQ_${conf^^}"
	[ -z "${!var:-}" ] || continue
	eval "export $var=\"\$default\""
done

# If long & short hostnames are not the same, use long hostnames
if [ "$(hostname)" != "$(hostname -s)" ]; then
	: "${RABBITMQ_USE_LONGNAME:=true}"
fi

if [ "${RABBITMQ_ERLANG_COOKIE:-}" ]; then
	cookieFile='/var/lib/rabbitmq/.erlang.cookie'
	if [ -e "$cookieFile" ]; then
		if [ "$(cat "$cookieFile" 2>/dev/null)" != "$RABBITMQ_ERLANG_COOKIE" ]; then
			echo >&2
			echo >&2 "warning: $cookieFile contents do not match RABBITMQ_ERLANG_COOKIE"
			echo >&2
		fi
	else
		echo "$RABBITMQ_ERLANG_COOKIE" > "$cookieFile"
	fi
	chmod 600 "$cookieFile"
fi

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}
indent() {
	if [ "$#" -gt 0 ]; then
		echo "$@"
	else
		cat
	fi | sed 's/^/\t/g'
}
rabbit_array() {
	echo -n '['
	case "$#" in
		0) echo -n ' ' ;;
		1) echo -n " $1 " ;;
		*)
			local vals="$(join $',\n' "$@")"
			echo
			indent "$vals"
	esac
	echo -n ']'
}
rabbit_string() {
	local val="$1"; shift
	# fire up erlang directly to have it do the proper escaping for us
	erl -noinput -eval 'io:format("~p\n", init:get_plain_arguments()), init:stop().' -- "$val"
}
rabbit_env_config() {
	local prefix="$1"; shift

	local ret=()
	local conf
	for conf; do
		local var="rabbitmq${prefix:+_$prefix}_$conf"
		var="${var^^}"

		local val="${!var:-}"

		local rawVal=
		case "$conf" in
			verify|fail_if_no_peer_cert|depth)
				[ "$val" ] || continue
				rawVal="$val"
				;;

			hipe_compile)
				[ "$val" ] && rawVal='true' || rawVal='false'
				;;

			cacertfile|certfile|keyfile)
				[ "$val" ] || continue
				rawVal="$(rabbit_string "$val")"
				;;

			*)
				[ "$val" ] || continue
				rawVal="<<$(rabbit_string "$val")>>"
				;;
		esac
		[ "$rawVal" ] || continue

		ret+=( "{ $conf, $rawVal }" )
	done

	join $'\n' "${ret[@]}"
}

shouldWriteConfig="$haveConfig"
if [ ! -f /etc/rabbitmq/rabbitmq.config ]; then
	shouldWriteConfig=1
fi

if [ "$1" = 'rabbitmq-server' ] && [ "$shouldWriteConfig" ]; then
	fullConfig=()

	rabbitConfig=(
		"{ loopback_users, $(rabbit_array) }"
	)

	# determine whether to set "vm_memory_high_watermark" (based on cgroups)
	memTotalKb=
	if [ -r /proc/meminfo ]; then
		memTotalKb="$(awk -F ':? +' '$1 == "MemTotal" { print $2; exit }' /proc/meminfo)"
	fi
	memLimitB=
	if [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
		# "18446744073709551615" is a valid value for "memory.limit_in_bytes", which is too big for Bash math to handle
		# "$(( 18446744073709551615 / 1024 ))" = 0; "$(( 18446744073709551615 * 40 / 100 ))" = 0
		memLimitB="$(awk -v totKb="$memTotalKb" '{
			limB = $0;
			limKb = limB / 1024;
			if (!totKb || limKb < totKb) {
				printf "%.0f\n", limB;
			}
		}' /sys/fs/cgroup/memory/memory.limit_in_bytes)"
	fi
	if [ -n "$memLimitB" ]; then
		# if we have a cgroup memory limit, let's inform RabbitMQ of what it is (so it can calculate vm_memory_high_watermark properly)
		# https://github.com/rabbitmq/rabbitmq-server/pull/1234
		rabbitConfig+=( "{ total_memory_available_override_value, $memLimitB }" )
	fi
	if [ "${RABBITMQ_VM_MEMORY_HIGH_WATERMARK:-}" ]; then
		# https://github.com/docker-library/rabbitmq/pull/105#issuecomment-242165822
		vmMemoryHighWatermark="$(
			awk '
				/^[0-9]*[.][0-9]+$|^[0-9]+([.][0-9]+)?%$/ {
					perc = $0;
					if (perc ~ /%$/) {
						gsub(/%$/, "", perc);
						perc = perc / 100;
					}
					if (perc > 1.0 || perc <= 0.0) {
						printf "error: invalid percentage for vm_memory_high_watermark: %s (must be > 0%%, <= 100%%)\n", $0 > "/dev/stderr";
						exit 1;
					}
					printf "%0.03f\n", perc;
					next;
				}
				/^[0-9]+$/ {
					printf "{ absolute, %s }\n", $0;
					next;
				}
				/^[0-9]+([.][0-9]+)?[a-zA-Z]+$/ {
					printf "{ absolute, \"%s\" }\n", $0;
					next;
				}
				{
					printf "error: unexpected input for vm_memory_high_watermark: %s\n", $0;
					exit 1;
				}
			' <(echo "$RABBITMQ_VM_MEMORY_HIGH_WATERMARK")
		)"
		if [ "$vmMemoryHighWatermark" ]; then
			# https://www.rabbitmq.com/memory.html#memsup-usage
			rabbitConfig+=( "{ vm_memory_high_watermark, $vmMemoryHighWatermark }" )
		fi
	fi

	if [ "$haveSslConfig" ]; then
		IFS=$'\n'
		rabbitSslOptions=( $(rabbit_env_config 'ssl' "${sslConfigKeys[@]}") )
		unset IFS

		rabbitConfig+=(
			"{ tcp_listeners, $(rabbit_array) }"
			"{ ssl_listeners, $(rabbit_array 5671) }"
			"{ ssl_options, $(rabbit_array "${rabbitSslOptions[@]}") }"
		)
	else
		rabbitConfig+=(
			"{ tcp_listeners, $(rabbit_array 5672) }"
			"{ ssl_listeners, $(rabbit_array) }"
		)
	fi

	IFS=$'\n'
	rabbitConfig+=( $(rabbit_env_config '' "${rabbitConfigKeys[@]}") )
	unset IFS

	fullConfig+=( "{ rabbit, $(rabbit_array "${rabbitConfig[@]}") }" )

	# if management plugin is installed, generate config for it
	# https://www.rabbitmq.com/management.html#configuration
	if [ "$(rabbitmq-plugins list -m -e rabbitmq_management)" ]; then
		rabbitManagementConfig=()

		if [ "$haveManagementSslConfig" ]; then
			IFS=$'\n'
			rabbitManagementSslOptions=( $(rabbit_env_config 'management_ssl' "${sslConfigKeys[@]}") )
			unset IFS

			rabbitManagementListenerConfig+=(
				'{ port, 15671 }'
				'{ ssl, true }'
				"{ ssl_opts, $(rabbit_array "${rabbitManagementSslOptions[@]}") }"
			)
		else
			rabbitManagementListenerConfig+=(
				'{ port, 15672 }'
				'{ ssl, false }'
			)
		fi
		rabbitManagementConfig+=(
			"{ listener, $(rabbit_array "${rabbitManagementListenerConfig[@]}") }"
		)

		# if definitions file exists, then load it
		# https://www.rabbitmq.com/management.html#load-definitions
		managementDefinitionsFile='/etc/rabbitmq/definitions.json'
		if [ -f "${managementDefinitionsFile}" ]; then
			# see also https://github.com/docker-library/rabbitmq/pull/112#issuecomment-271485550
			rabbitManagementConfig+=(
				"{ load_definitions, \"$managementDefinitionsFile\" }"
			)
		fi

		fullConfig+=(
			"{ rabbitmq_management, $(rabbit_array "${rabbitManagementConfig[@]}") }"
		)
	fi

	echo "$(rabbit_array "${fullConfig[@]}")." > /etc/rabbitmq/rabbitmq.config
fi

combinedSsl='/tmp/combined.pem'
if [ "$haveSslConfig" ] && [[ "$1" == rabbitmq* ]] && [ ! -f "$combinedSsl" ]; then
	# Create combined cert
	cat "$RABBITMQ_SSL_CERTFILE" "$RABBITMQ_SSL_KEYFILE" > "$combinedSsl"
	chmod 0400 "$combinedSsl"
fi
if [ "$haveSslConfig" ] && [ -f "$combinedSsl" ]; then
	# More ENV vars for make clustering happiness
	# we don't handle clustering in this script, but these args should ensure
	# clustered SSL-enabled members will talk nicely
	export ERL_SSL_PATH="$(erl -eval 'io:format("~p", [code:lib_dir(ssl, ebin)]),halt().' -noshell)"
	sslErlArgs="-pa $ERL_SSL_PATH -proto_dist inet_tls -ssl_dist_opt server_certfile $combinedSsl -ssl_dist_opt server_secure_renegotiate true client_secure_renegotiate true"
	export RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="${RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS:-} $sslErlArgs"
	export RABBITMQ_CTL_ERL_ARGS="${RABBITMQ_CTL_ERL_ARGS:-} $sslErlArgs"
fi

exec "$@"
