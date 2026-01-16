# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:

FROM rabbitmq:4.0-alpine

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

RUN set -eux; \
	arch="$(apk --print-arch)"; \
	\
	case "$arch" in \
		'x86_64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.22.0/rabbitmqadmin-2.22.0-x86_64-unknown-linux-musl'; digest='ed3a1cf449e9ab7b24d35308e45973da671f7ed014bd8f8dff1908668e64ba36' ;; \
		'aarch64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.22.0/rabbitmqadmin-2.22.0-aarch64-unknown-linux-musl'; digest='3348c28d466e95bf03a0a6c4ca3e8e985f44d85f630fe1cd7b72b12b7fb28dec' ;; \
		*) echo "[INFO] rabbitmqadmin is not available on $arch (yet?)"; exit 0 ;; \
	esac; \
	\
	wget -O /usr/local/bin/rabbitmqadmin "$url"; \
	echo "$digest */usr/local/bin/rabbitmqadmin" | sha256sum -c -; \
	\
	chmod +x /usr/local/bin/rabbitmqadmin; \
	rabbitmqadmin --help

EXPOSE 15671 15672
