# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:

FROM rabbitmq:4.1-alpine

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

RUN set -eux; \
	arch="$(apk --print-arch)"; \
	\
	case "$arch" in \
		'x86_64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.30.0/rabbitmqadmin-2.30.0-x86_64-unknown-linux-musl'; digest='70d136a0cb1f105b0904748aae04a0fdb1619e1eb6cf93afacca773d4c7973f4' ;; \
		'aarch64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.30.0/rabbitmqadmin-2.30.0-aarch64-unknown-linux-musl'; digest='3082218c983fdf6d4a7cbbf1b038829a391c9eba056e9828dddf97c46ac43488' ;; \
		*) echo "[INFO] rabbitmqadmin is not available on $arch (yet?)"; exit 0 ;; \
	esac; \
	\
	wget -O /usr/local/bin/rabbitmqadmin "$url"; \
	echo "$digest */usr/local/bin/rabbitmqadmin" | sha256sum -c -; \
	\
	chmod +x /usr/local/bin/rabbitmqadmin; \
	rabbitmqadmin --help

EXPOSE 15671 15672
