# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:
FROM rabbitmq:4.2 AS builder

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends wget; \
	arch="$(uname -m)"; \
	if [ "$arch" = "x86_64" ]; then \
		wget --quiet --output-document=/usr/local/bin/rabbitmqadmin "https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.17.0/rabbitmqadmin-2.17.0-x86_64-unknown-linux-gnu"; \
		echo "a0995c7bb4597f33cddefce80dc2e234c571d8716c8ba946b1e288f3ab6e6dbb /usr/local/bin/rabbitmqadmin" | sha256sum --check --strict -; \
	elif [ "$arch" = "aarch64" ]; then  \
		wget --quiet --output-document=/usr/local/bin/rabbitmqadmin "https://github.com/rabbitmq/rabbitmqadmin-ng/releases/download/v2.17.0/rabbitmqadmin-2.17.0-aarch64-unknown-linux-gnu"; \
		echo "a90d65072eb3fe4cc5883b7396cdf180cf883111c0626a80a2ad6256b87879d4 /usr/local/bin/rabbitmqadmin" | sha256sum --check --strict -; \
	else \
		echo "[INFO] rabbitmqadmin is not available on Ubuntu $arch"; \
	fi; \
	chmod +x /usr/local/bin/rabbitmqadmin

RUN touch /usr/local/bin/rabbitmqadmin

FROM rabbitmq:4.2

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
