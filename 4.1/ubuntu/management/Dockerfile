# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:

FROM rabbitmq:4.1

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

RUN set -eux; \
	arch="$(dpkg --print-architecture)"; \
	case "$arch" in \
		'amd64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.20.0/rabbitmqadmin-2.20.0-x86_64-unknown-linux-gnu'; digest='eb3b573aeaa50b3ad279afd1c1e2bfa4d41ff0a4c0c1740bb31ddc49fa9fbd06' ;; \
		'arm64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.20.0/rabbitmqadmin-2.20.0-aarch64-unknown-linux-gnu'; digest='ab7ba536953add9a08f9d1d79f29dc76ff1d27a75c359a734223cb6b3a22535d' ;; \
		*) echo "[INFO] rabbitmqadmin is not available on $arch (yet?)"; exit 0; \
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
