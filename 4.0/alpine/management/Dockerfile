# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:
FROM rabbitmq:4.0-alpine AS builder

RUN set -eux; \
	echo "[INFO] rabbitmqadmin is not available on Alpine Linux"

RUN touch /usr/local/bin/rabbitmqadmin

FROM rabbitmq:4.0-alpine

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

COPY --from=builder /usr/local/bin/rabbitmqadmin /tmp/rabbitmqadmin-rust

RUN set -eux; \
	if [ -s /tmp/rabbitmqadmin-rust ] && [ -x /tmp/rabbitmqadmin-rust ]; then \
		mv /tmp/rabbitmqadmin-rust /usr/local/bin/rabbitmqadmin; \
		rabbitmqadmin --help; \
	else \
		rm -f /tmp/rabbitmqadmin-rust; \
		echo "[INFO] rabbitmqadmin is not available on this platform."; \
	fi

EXPOSE 15671 15672
