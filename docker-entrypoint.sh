#!/bin/bash
set -e

if [ "$1" = 'rabbitmq-server' ]; then
	if [ "${ERLANG_COOKIE}" -n ]; then
		echo ${ERLANG_COOKIE} > /var/lib/rabbitmq/.erlang.cookie
	fi
	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
fi

exec "$@"
