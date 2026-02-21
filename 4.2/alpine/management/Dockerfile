# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:

FROM rabbitmq:4.2-alpine

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

RUN set -eux; \
	arch="$(apk --print-arch)"; \
	\
	case "$arch" in \
		'x86_64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.26.0/rabbitmqadmin-2.26.0-x86_64-unknown-linux-musl'; digest='fd01f8e7429c685cd844441ca2474ae28e863fd3d5b7a8ffc083b22967892dd1' ;; \
		'aarch64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.26.0/rabbitmqadmin-2.26.0-aarch64-unknown-linux-musl'; digest='4da07a3b6aa01649d20205b8da5a059a7172276824e1c732d5a063b599a54fc6' ;; \
		*) echo "[INFO] rabbitmqadmin is not available on $arch (yet?)"; exit 0 ;; \
	esac; \
	\
	wget -O /usr/local/bin/rabbitmqadmin "$url"; \
	echo "$digest */usr/local/bin/rabbitmqadmin" | sha256sum -c -; \
	\
	chmod +x /usr/local/bin/rabbitmqadmin; \
	rabbitmqadmin --help

EXPOSE 15671 15672
