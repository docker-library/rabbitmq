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
		'x86_64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.33.0/rabbitmqadmin-2.33.0-x86_64-unknown-linux-musl'; digest='df23350342435f54a32e127d9c9287d5bb4a006150c6a2b40cad4bf97e113b06' ;; \
		'aarch64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.33.0/rabbitmqadmin-2.33.0-aarch64-unknown-linux-musl'; digest='051eb145b2030dfa6c011a3ff1cdba7c25bf63c83c006930bae60efce9a91222' ;; \
		*) echo "[INFO] rabbitmqadmin is not available on $arch (yet?)"; exit 0 ;; \
	esac; \
	\
	wget -O /usr/local/bin/rabbitmqadmin "$url"; \
	echo "$digest */usr/local/bin/rabbitmqadmin" | sha256sum -c -; \
	\
	chmod +x /usr/local/bin/rabbitmqadmin; \
	rabbitmqadmin --help

EXPOSE 15671 15672
