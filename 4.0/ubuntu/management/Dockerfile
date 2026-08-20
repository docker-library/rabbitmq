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
		'amd64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.34.0/rabbitmqadmin-2.34.0-x86_64-unknown-linux-gnu'; digest='0d5d8d2613232e10eebac62d43754666d45b034f6ba1a42eded0480d67d60d0e' ;; \
		'arm64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.34.0/rabbitmqadmin-2.34.0-aarch64-unknown-linux-gnu'; digest='995d2b2fa0060b9c2533bbbf118092c577770bf3b772e4952adbfef42c9e7ad6' ;; \
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
