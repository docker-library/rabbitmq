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
		'amd64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.22.0/rabbitmqadmin-2.22.0-x86_64-unknown-linux-gnu'; digest='daec0f7b906ea9f79e672b2ef5368db08137df79a7c7d9f9b3c4f0f66acb453e' ;; \
		'arm64') url='https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.22.0/rabbitmqadmin-2.22.0-aarch64-unknown-linux-gnu'; digest='e0bdff91823be7f760c7b030c0c24802204eda7ad21a95b907ed36be8503cb76' ;; \
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
