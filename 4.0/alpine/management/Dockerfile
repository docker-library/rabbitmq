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
		'x86_64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.20.0/rabbitmqadmin-2.20.0-x86_64-unknown-linux-musl'; digest='017747084312a47c38eca52942e6f0dd06f5ab845ac0ce7e744d63de253cd0d6' ;; \
		'aarch64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.20.0/rabbitmqadmin-2.20.0-aarch64-unknown-linux-musl'; digest='13a9f4f0457c95dbe5739a357663b18bda927b277ebdefe5038f0f9bf2b96570' ;; \
		*) echo "[INFO] rabbitmqadmin is not available on $arch (yet?)"; exit 0 ;; \
	esac; \
	\
	wget -O /usr/local/bin/rabbitmqadmin "$url"; \
	echo "$digest */usr/local/bin/rabbitmqadmin" | sha256sum -c -; \
	\
	chmod +x /usr/local/bin/rabbitmqadmin; \
	rabbitmqadmin --help

EXPOSE 15671 15672
