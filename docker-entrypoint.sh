#!/bin/bash
set -e

if [ "$1" = 'rabbitmq-server' ]; then
	if [ -n "${ERLANG_COOKIE}" ]; then
		echo ${ERLANG_COOKIE} > /var/lib/rabbitmq/.erlang.cookie
		chmod 600 /var/lib/rabbitmq/.erlang.cookie
	fi
	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
fi

exec "$@"
