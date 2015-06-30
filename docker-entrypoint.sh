#!/bin/bash
set -e

if [ "$1" = 'rabbitmq-server' ]; then
	configs=(
		# https://www.rabbitmq.com/configure.html
		default_vhost
		default_user
		default_pass
	)

	haveConfig=
	for conf in "${configs[@]}"; do
		var="RABBITMQ_${conf^^}"
		val="${!var}"
		if [ "$val" ]; then
			haveConfig=1
			break
		fi
	done

	if [ "$haveConfig" ]; then
		cat > /etc/rabbitmq/rabbitmq.config <<-'EOH'
			[
			  {rabbit,
			    [
		EOH
		for conf in "${configs[@]}"; do
			var="RABBITMQ_${conf^^}"
			val="${!var}"
			[ "$val" ] || continue
			cat >> /etc/rabbitmq/rabbitmq.config <<-EOC
			      {$conf, <<"$val">>},
			EOC
		done
		cat >> /etc/rabbitmq/rabbitmq.config <<-'EOF'
			      {loopback_users, []}
			    ]
			  }
			].
		EOF
	fi

	chown -R rabbitmq /var/lib/rabbitmq
	set -- gosu rabbitmq "$@"
fi

exec "$@"
