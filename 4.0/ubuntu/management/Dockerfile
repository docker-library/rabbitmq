# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:

FROM rabbitmq:4.0

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

RUN set -eux; \
	arch="$(dpkg --print-architecture)"; \
	case "$arch" in \
		'amd64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.23.0/rabbitmqadmin-2.23.0-x86_64-unknown-linux-gnu'; digest='62e2c22df73b1f8f04bda5630cb9c32cc60ce2fa28487de0337c039625f5cbda' ;; \
		'arm64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.23.0/rabbitmqadmin-2.23.0-aarch64-unknown-linux-gnu'; digest='9ed29731a27d5aeba44fde8a64a55e04592db915028468a428069cefeee0fc29' ;; \
		*) echo "[INFO] rabbitmqadmin is not available on $arch (yet?)"; exit 0 ;; \
	esac; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	\
	wget -O /usr/local/bin/rabbitmqadmin "$url"; \
	echo "$digest */usr/local/bin/rabbitmqadmin" | sha256sum --strict --check -; \
	\
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	apt-get dist-clean; \
	\
	chmod +x /usr/local/bin/rabbitmqadmin; \
	rabbitmqadmin --help

EXPOSE 15671 15672
