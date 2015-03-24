#!/bin/bash
set -e

if [ "$1" = 'rabbitmq-server' ]; then
	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
fi

exec "$@"
