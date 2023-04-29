#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# Alpine Linux is not officially supported by the RabbitMQ team -- use at your own risk!
FROM alpine:3.17 as build-base

RUN apk add --no-cache \
	build-base \
	dpkg-dev \
	dpkg \
	gnupg \
	libc-dev \
	linux-headers \
	ncurses-dev

FROM build-base as openssl-builder

# Default to a PGP keyserver that pgp-happy-eyeballs recognizes, but allow for substitutions locally
ARG PGP_KEYSERVER=keyserver.ubuntu.com
# If you are building this image locally and are getting `gpg: keyserver receive failed: No data` errors,
# run the build with a different PGP_KEYSERVER, e.g. docker build --tag rabbitmq:3.10 --build-arg PGP_KEYSERVER=pgpkeys.eu 3.10/ubuntu
# For context, see https://github.com/docker-library/official-images/issues/4252

ENV OPENSSL_VERSION 3.0.8
ENV OPENSSL_SOURCE_SHA256="6c13d2bf38fdf31eac3ce2a347073673f5d63263398f1f69d0df4a41253e4b3e"
# https://www.openssl.org/community/otc.html
ENV OPENSSL_PGP_KEY_IDS="0x8657ABB260F056B1E5190839D9C4D26D0E604491 0xB7C1C14360F353A36862E4D5231C84CDDCC69C45 0xC1F33DD8CE1D4CC613AF14DA9195C48241FBF7DD 0x95A9908DDFA16830BE9FB9003D30A3A9FF1360DC 0x7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C 0xA21FAB74B0088AA361152586B8EF1A6BA9DA2D5C 0xE5E52560DD91C556DDBDA5D02064C53641C25E5D"

ENV OTP_VERSION 25.3.1
# TODO add PGP checking when the feature will be added to Erlang/OTP's build system
# https://erlang.org/pipermail/erlang-questions/2019-January/097067.html
ENV OTP_SOURCE_SHA256="1d5e4b97a7cfa0afa8787ae60a66426806f55897085dde1fd553ac2db39a6082"

# Install dependencies required to build Erlang/OTP from source
# https://erlang.org/doc/installation_guide/INSTALL.html
# dpkg-dev: Required to set up host & build type when compiling Erlang/OTP
# gnupg: Required to verify OpenSSL artefacts
# libncurses5-dev: Required for Erlang/OTP new shell & observer_cli - https://github.com/zhongwencool/observer_cli
RUN set -eux; \
# /usr/local/src doesn't exist in Alpine by default
	mkdir -p /usr/local/src; \
	\
	OPENSSL_SOURCE_URL="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"; \
	OPENSSL_PATH="/usr/local/src/openssl-$OPENSSL_VERSION"; \
	OPENSSL_CONFIG_DIR=/usr/local/etc/ssl; \
	\
# Required by the crypto & ssl Erlang/OTP applications
	wget --output-document "$OPENSSL_PATH.tar.gz.asc" "$OPENSSL_SOURCE_URL.asc"; \
	wget --output-document "$OPENSSL_PATH.tar.gz" "$OPENSSL_SOURCE_URL"; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $OPENSSL_PGP_KEY_IDS; do \
		gpg --batch --keyserver "$PGP_KEYSERVER" --recv-keys "$key"; \
	done; \
	gpg --batch --verify "$OPENSSL_PATH.tar.gz.asc" "$OPENSSL_PATH.tar.gz"; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	echo "$OPENSSL_SOURCE_SHA256 *$OPENSSL_PATH.tar.gz" | sha256sum -c -; \
	mkdir -p "$OPENSSL_PATH"; \
	tar --extract --file "$OPENSSL_PATH.tar.gz" --directory "$OPENSSL_PATH" --strip-components 1; \
	\
# Configure OpenSSL for compilation
	cd "$OPENSSL_PATH"; \
# OpenSSL's "config" script uses a lot of "uname"-based target detection...
	MACHINE="$(dpkg-architecture --query DEB_BUILD_GNU_CPU)" \
	RELEASE="4.x.y-z" \
	SYSTEM='Linux' \
	BUILD='???' \
	./config \
		enable-fips \
		--openssldir="$OPENSSL_CONFIG_DIR" \
# add -rpath to avoid conflicts between our OpenSSL's "libssl.so" and the libssl package by making sure /usr/local/lib64 is searched first (but only for Erlang/OpenSSL to avoid issues with other tools using libssl; https://github.com/docker-library/rabbitmq/issues/364)
		-Wl,-rpath=/usr/local/lib64 \
	; \
# Compile, install OpenSSL, verify that the command-line works & development headers are present
	make -j "$(getconf _NPROCESSORS_ONLN)"; \
	make install_sw install_ssldirs install_fips; \
# use Alpine's CA certificates
	rmdir "$OPENSSL_CONFIG_DIR/certs" "$OPENSSL_CONFIG_DIR/private"; \
	ln -sf /etc/ssl/certs /etc/ssl/private "$OPENSSL_CONFIG_DIR"

# smoke test
RUN openssl version

FROM openssl-builder as erlang-builder

RUN set -eux; \
# /usr/local/src doesn't exist in Alpine by default
	mkdir -p /usr/local/src; \
	\
	OTP_SOURCE_URL="https://github.com/erlang/otp/releases/download/OTP-$OTP_VERSION/otp_src_$OTP_VERSION.tar.gz"; \
	OTP_PATH="/usr/local/src/otp-$OTP_VERSION"; \
	\
# Download, verify & extract OTP_SOURCE
	mkdir -p "$OTP_PATH"; \
	wget --output-document "$OTP_PATH.tar.gz" "$OTP_SOURCE_URL"; \
	echo "$OTP_SOURCE_SHA256 *$OTP_PATH.tar.gz" | sha256sum -c -; \
	tar --extract --file "$OTP_PATH.tar.gz" --directory "$OTP_PATH" --strip-components 1; \
	\
# Configure Erlang/OTP for compilation, disable unused features & applications
# https://erlang.org/doc/applications.html
# ERL_TOP is required for Erlang/OTP makefiles to find the absolute path for the installation
	cd "$OTP_PATH"; \
	export ERL_TOP="$OTP_PATH"; \
	export CFLAGS='-g -O2'; \
# add -rpath to avoid conflicts between our OpenSSL's "libssl.so" and the libssl package by making sure /usr/local/lib64 is searched first (but only for Erlang/OpenSSL to avoid issues with other tools using libssl; https://github.com/docker-library/rabbitmq/issues/364)
	export CFLAGS="$CFLAGS -Wl,-rpath=/usr/local/lib64"; \
	hostArch="$(dpkg-architecture --query DEB_HOST_GNU_TYPE)"; \
	buildArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	dpkgArch="$(dpkg --print-architecture)"; dpkgArch="${dpkgArch##*-}"; \
# JIT is only supported on amd64 (until 24.x+1, where it will support arm64 as well); https://github.com/erlang/otp/blob/OTP-24.0.5/erts/configure#L21694-L21709 / https://github.com/erlang/otp/pull/4869
	jitFlag=; \
	case "$dpkgArch" in \
		amd64) jitFlag='--enable-jit' ;; \
	esac; \
	./configure \
		--host="$hostArch" \
		--build="$buildArch" \
		--disable-dynamic-ssl-lib \
		--disable-hipe \
		--disable-sctp \
		--disable-silent-rules \
		--enable-clock-gettime \
		--enable-hybrid-heap \
		--enable-kernel-poll \
		--enable-builtin-zlib \
		--enable-smp-support \
		--enable-threads \
		--with-microstate-accounting=extra \
		--without-common_test \
		--without-debugger \
		--without-dialyzer \
		--without-diameter \
		--without-edoc \
		--without-erl_docgen \
		--without-et \
		--without-eunit \
		--without-ftp \
		--without-hipe \
		--without-jinterface \
		--without-megaco \
		--without-observer \
		--without-odbc \
		--without-reltool \
		--without-ssh \
		--without-tftp \
		--without-wx \
		$jitFlag \
	; \
# Compile & install Erlang/OTP
	make -j "$(getconf _NPROCESSORS_ONLN)" GEN_OPT_FLGS="-O2 -fno-strict-aliasing"; \
	make install; \
	\
# Remove unnecessary files
	find /usr/local/lib/erlang -type d -name examples -exec rm -rf '{}' +; \
	find /usr/local/lib/erlang -type d -name src -exec rm -rf '{}' +; \
	find /usr/local/lib/erlang -type d -name include -exec rm -rf '{}' +

# Check that Erlang/OTP crypto & ssl were compiled against OpenSSL correctly
RUN erl -noshell -eval 'ok = crypto:start(), ok = io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'

FROM alpine:3.17

COPY --from=erlang-builder /usr/local/bin/ /usr/local/bin/
COPY --from=erlang-builder /usr/local/etc/ssl/ /usr/local/etc/ssl/
COPY --from=erlang-builder /usr/local/lib/ /usr/local/lib/

ENV RABBITMQ_DATA_DIR=/var/lib/rabbitmq

RUN set -eux; \
# Configure OpenSSL to use system certs
	ln -vsf /etc/ssl/certs /etc/ssl/private /usr/local/etc/ssl; \
	\
# Ensure run-time dependencies are installed
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("test -e /usr/local/lib/" $1) == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache --virtual .otp-run-deps $runDeps; \
	\
# Check that OpenSSL still works after purging build dependencies
	sed -i.ORIG -e '/\.include.*fips/s/.*/.include \/usr\/local\/etc\/ssl\/fipsmodule.cnf/' \
	    -e '/# fips =/s/.*/fips = fips_sect/' /usr/local/etc/ssl/openssl.cnf; \
	sed -i.ORIG -e '/^activate/s/^/#/' /usr/local/etc/ssl/fipsmodule.cnf; \
	openssl version; \
	openssl version -d; \
	\
# Check that Erlang/OTP crypto & ssl were compiled against OpenSSL correctly
	erl -noshell -eval 'ok = crypto:start(), ok = io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'; \
	\
# Create rabbitmq system user & group, fix permissions & allow root user to connect to the RabbitMQ Erlang VM
	addgroup -g 101 -S rabbitmq; \
	adduser -u 100 -S -h "$RABBITMQ_DATA_DIR" -G rabbitmq rabbitmq; \
	mkdir -p "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
	chown -fR rabbitmq:rabbitmq "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
	chmod 1777 "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
	ln -sf "$RABBITMQ_DATA_DIR/.erlang.cookie" /root/.erlang.cookie; \
	\
	apk add --no-cache \
# grab su-exec for easy step-down from root
		'su-exec>=0.2' \
# bash for docker-entrypoint.sh
		bash \
# "ps" for "rabbitmqctl wait" (https://github.com/docker-library/rabbitmq/issues/162)
		procps \
# Bring in tzdata so users could set the timezones through the environment
		tzdata

# Use the latest stable RabbitMQ release (https://www.rabbitmq.com/download.html)
ENV RABBITMQ_VERSION 3.10.22
# https://www.rabbitmq.com/signatures.html#importing-gpg
ENV RABBITMQ_PGP_KEY_ID="0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"
ENV RABBITMQ_HOME=/opt/rabbitmq

# Add RabbitMQ to PATH
ENV PATH=$RABBITMQ_HOME/sbin:$PATH

# Install RabbitMQ
RUN set -eux; \
# /usr/local/src doesn't exist in Alpine by default
	mkdir -p /usr/local/src; \
	\
	apk add --no-cache --virtual .build-deps \
		gnupg \
		xz \
	; \
	\
	RABBITMQ_SOURCE_URL="https://github.com/rabbitmq/rabbitmq-server/releases/download/v$RABBITMQ_VERSION/rabbitmq-server-generic-unix-latest-toolchain-$RABBITMQ_VERSION.tar.xz"; \
	RABBITMQ_PATH="/usr/local/src/rabbitmq-$RABBITMQ_VERSION"; \
	\
	wget --output-document "$RABBITMQ_PATH.tar.xz.asc" "$RABBITMQ_SOURCE_URL.asc"; \
	wget --output-document "$RABBITMQ_PATH.tar.xz" "$RABBITMQ_SOURCE_URL"; \
	\
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$RABBITMQ_PGP_KEY_ID"; \
	gpg --batch --verify "$RABBITMQ_PATH.tar.xz.asc" "$RABBITMQ_PATH.tar.xz"; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME"; \
	\
	mkdir -p "$RABBITMQ_HOME"; \
	tar --extract --file "$RABBITMQ_PATH.tar.xz" --directory "$RABBITMQ_HOME" --strip-components 1; \
	rm -rf "$RABBITMQ_PATH"*; \
# Do not default SYS_PREFIX to RABBITMQ_HOME, leave it empty
	grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	sed -i 's/^SYS_PREFIX=.*$/SYS_PREFIX=/' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	chown -R rabbitmq:rabbitmq "$RABBITMQ_HOME"; \
	\
	apk del --no-network .build-deps; \
	\
# verify assumption of no stale cookies
	[ ! -e "$RABBITMQ_DATA_DIR/.erlang.cookie" ]; \
# Ensure RabbitMQ was installed correctly by running a few commands that do not depend on a running server, as the rabbitmq user
# If they all succeed, it's safe to assume that things have been set up correctly
	su-exec rabbitmq rabbitmqctl help; \
	su-exec rabbitmq rabbitmqctl list_ciphers; \
	su-exec rabbitmq rabbitmq-plugins list; \
# no stale cookies
	rm "$RABBITMQ_DATA_DIR/.erlang.cookie"

# Enable Prometheus-style metrics by default (https://github.com/docker-library/rabbitmq/issues/419)
RUN su-exec rabbitmq rabbitmq-plugins enable --offline rabbitmq_prometheus

# Added for backwards compatibility - users can simply COPY custom plugins to /plugins
RUN ln -sf /opt/rabbitmq/plugins /plugins

# set home so that any `--user` knows where to put the erlang cookie
ENV HOME $RABBITMQ_DATA_DIR
# Hint that the data (a.k.a. home dir) dir should be separate volume
VOLUME $RABBITMQ_DATA_DIR

# warning: the VM is running with native name encoding of latin1 which may cause Elixir to malfunction as it expects utf8. Please ensure your locale is set to UTF-8 (which can be verified by running "locale" in your shell)
# Setting all environment variables that control language preferences, behaviour differs - https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html#The-LANGUAGE-variable
# https://docs.docker.com/samples/library/ubuntu/#locales
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

COPY --chown=rabbitmq:rabbitmq 10-defaults.conf 20-management_agent.disable_metrics_collector.conf /etc/rabbitmq/conf.d/
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 4369 5671 5672 15691 15692 25672
CMD ["rabbitmq-server"]
