#!/bin/bash
set -e

if [ "$1" = 'rabbitmq-server' ]; then
	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"

	cat > /etc/rabbitmq/rabbitmq.config <<EOF
[
	{rabbit, [{default_user, <<"$RABBITMQ_USER">>},
                  {default_pass, <<"$RABBITMQ_PASSwD">>},
                  {default_permissions, [<<".*">>, <<".*">>, <<".*">>]}
        ]}
].
EOF
fi

exec "$@"
