#!/bin/bash
set -e

DEFAULT_VHOST=${RABBITMQ_DEFAULT_VHOST:-"/"}
DEFAULT_USER=${RABBITMQ_DEFAULT_USER:-"guest"}
DEFAULT_PASSWORD=${RABBITMQ_DEFAULT_PASSWORD:-"guest"}

cat << EOS > /etc/rabbitmq/rabbitmq.config
[
	{rabbit,
		[
   		{default_vhost,       <<"${DEFAULT_VHOST}">>},
   		{default_user,        <<"${DEFAULT_USER}">>},
  		{default_pass,        <<"${DEFAULT_PASSWORD}">>}
		]
	}
].
EOS

if [ "$1" = 'rabbitmq-server' ]; then
	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
fi

exec "$@"
