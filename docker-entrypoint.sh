#!/bin/bash
set -e

# allow the container to be started with `--user`
if [[ "$1" == rabbitmq* ]] && [ "$(id -u)" = '0' ]; then
	if [ "$1" = 'rabbitmq-server' ]; then
		chown -R rabbitmq /var/lib/rabbitmq
	fi
	exec gosu rabbitmq "$BASH_SOURCE" "$@"
fi

# backwards compatibility for old environment variables
: "${RABBITMQ_SSL_CERTFILE:=${RABBITMQ_SSL_CERT_FILE:-}}"
: "${RABBITMQ_SSL_KEYFILE:=${RABBITMQ_SSL_KEY_FILE:-}}"
: "${RABBITMQ_SSL_CACERTFILE:=${RABBITMQ_SSL_CA_FILE:-}}"

# https://www.rabbitmq.com/configure.html
fileConfigs=(
	ssl_cacertfile
	ssl_certfile
	ssl_keyfile
)
configs=(
	default_pass
	default_user
	default_vhost
	hipe_compile
	ssl_fail_if_no_peer_cert
	ssl_verify
	"${fileConfigs[@]}"
)

haveConfig=
haveSslConfig=
for conf in "${configs[@]}"; do
	var="RABBITMQ_${conf^^}"
	val="${!var}"
	if [ "$val" ]; then
		haveConfig=1
		if [[ "$conf" == ssl_* ]]; then
			haveSslConfig=1
		fi
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
for conf in "${fileConfigs[@]}"; do
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

# If long & short hostnames are not the same, use long hostnames
if [ "$(hostname)" != "$(hostname -s)" ]; then
	: "${RABBITMQ_USE_LONGNAME:=true}"
fi

if [ "$RABBITMQ_ERLANG_COOKIE" ]; then
	cookieFile='/var/lib/rabbitmq/.erlang.cookie'
	if [ -e "$cookieFile" ]; then
		if [ "$(cat "$cookieFile" 2>/dev/null)" != "$RABBITMQ_ERLANG_COOKIE" ]; then
			echo >&2
			echo >&2 "warning: $cookieFile contents do not match RABBITMQ_ERLANG_COOKIE"
			echo >&2
		fi
	else
		echo "$RABBITMQ_ERLANG_COOKIE" > "$cookieFile"
		chmod 600 "$cookieFile"
	fi
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

if [ "$1" = 'rabbitmq-server' ] && [ "$haveConfig" ]; then
	rabbitConfig=(
		"{ loopback_users, $(rabbit_array) }"
	)

	rabbitSslOptions=()
	if [ "$haveSslConfig" ]; then
		for conf in "${configs[@]}"; do
			sslConf="${conf#ssl_}"
			[ "$sslConf" != "$conf" ] || continue

			var="RABBITMQ_${conf^^}"
			val="${!var}"

			# default values
			case "$sslConf" in
				verify) : "${val:=verify_peer}" ;;
				fail_if_no_peer_cert) : "${val:=true}" ;;
			esac

			rawVal=
			case "$sslConf" in
				verify|fail_if_no_peer_cert) rawVal="$val" ;;

				*)
					[ "$val" ] || continue
					rawVal='"'"$val"'"'
					;;
			esac
			[ "$rawVal" ] || continue

			rabbitSslOptions+=( "{ $sslConf, $rawVal }" )
		done

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

	for conf in "${configs[@]}"; do
		var="RABBITMQ_${conf^^}"
		val="${!var}"

		rawVal=
		case "$conf" in
			# SSL-related options are configured above, so should be ignored here
			ssl_*) continue ;;

			# convert shell booleans into Erlang booleans
			hipe_compile)
				[ "$val" ] && rawVal='true' || rawVal='false'
				;;

			# otherwise, assume string-based (and skip or add appropriate decorations)
			*)
				[ "$val" ] || continue
				rawVal='<<"'"$val"'">>'
				;;
		esac
		[ "$rawVal" ] || continue

		rabbitConfig+=( "{ $conf, $rawVal }" )
	done

	# If management plugin is installed, then generate config consider this
	if [ "$(rabbitmq-plugins list -m -e rabbitmq_management)" ]; then
		rabbitManagementListenerConfig=()
		if [ "$haveSslConfig" ]; then
			rabbitManagementListenerConfig+=(
				'{ port, 15671 }'
				'{ ssl, true }'
				"{ ssl_opts, $(rabbit_array "${rabbitSslOptions[@]}") }"
			)
		else
			rabbitManagementListenerConfig+=(
				'{ port, 15672 }'
				'{ ssl, false }'
			)
		fi
		rabbitConfig+=(
			"{ rabbitmq_management, $(rabbit_array "{ listener, $(rabbit_array "${rabbitManagementListenerConfig[@]}") }") }"
		)
	fi

	echo "$(rabbit_array "{ rabbit, $(rabbit_array "${rabbitConfig[@]}") }")." > /etc/rabbitmq/rabbitmq.config
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
	export RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS="-pa '$ERL_SSL_PATH' -proto_dist inet_tls -ssl_dist_opt server_certfile '$combinedSsl' -ssl_dist_opt server_secure_renegotiate true client_secure_renegotiate true"
	export RABBITMQ_CTL_ERL_ARGS="$RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS"
fi

exec "$@"
