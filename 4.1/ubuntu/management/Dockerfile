# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv
#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# vim:noet:
FROM rabbitmq:4.1 AS builder

RUN set +e; set -ux; \
	apt-get update; \
	apt-get install -y --no-install-recommends build-essential unzip wget; \
	\
	wget --quiet --output-document=rmqadmin.zip "https://github.com/rabbitmq/rabbitmqadmin-ng/archive/refs/tags/v2.17.0.zip"; \
	wget --quiet --output-document=rustup-init.sh https://sh.rustup.rs; \
	\
	echo "872860dcc3358467fc8f8447cf4364d2903658d2500af100771c4eaa6b3831d4 rmqadmin.zip" | sha256sum --check --strict -; \
	echo "17247e4bcacf6027ec2e11c79a72c494c9af69ac8d1abcc1b271fa4375a106c2 rustup-init.sh" | sha256sum --check --strict -; \
	\
	/bin/sh -x ./rustup-init.sh -y --default-toolchain stable --profile minimal; \
	. "$HOME/.cargo/env"; \
	unzip -q rmqadmin.zip; \
	cd "rabbitmqadmin-ng-2.17.0"; \
	export OPENSSL_DIR=/opt/openssl; \
	\
	export RUSTFLAGS="-C link-arg=-Wl,-rpath,/opt/openssl/lib"; \
	\
	if cargo build --release && [ -f target/release/rabbitmqadmin ]; then \
		cp target/release/rabbitmqadmin /usr/local/bin/rabbitmqadmin; \
		chmod +x /usr/local/bin/rabbitmqadmin; \
	else \
		echo "[INFO] could not build rabbitmqadmin-ng via Rust toolchain."; \
	fi

RUN touch /usr/local/bin/rabbitmqadmin

FROM rabbitmq:4.1

RUN set -eux; \
	rabbitmq-plugins enable --offline rabbitmq_management; \
# make sure the metrics collector is re-enabled (disabled in the base image for Prometheus-style metrics by default)
	rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf

# Copy Rust binary from builder if it exists
COPY --from=builder /usr/local/bin/rabbitmqadmin /tmp/rabbitmqadmin-rust

RUN set -eux; \
	if [ -x /tmp/rabbitmqadmin-rust ]; then \
		mv /tmp/rabbitmqadmin-rust /usr/local/bin/rabbitmqadmin; \
		rabbitmqadmin --help; \
	else \
		echo "[INFO] rabbitmqadmin is not available on this platform."; \
	fi

EXPOSE 15671 15672
