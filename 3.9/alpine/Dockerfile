#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

# Alpine Linux is not officially supported by the RabbitMQ team -- use at your own risk!
FROM alpine:3 AS build-base

# Install dependencies required to build OpenSSL and Erlang/OTP from source
# https://erlang.org/doc/installation_guide/INSTALL.html
# https://github.com/openssl/openssl/blob/master/INSTALL.md
# autoconf: Required to configure Erlang/OTP before compiling
# dpkg-dev: Required to set up host & build type when compiling Erlang/OTP
# gnupg: Required to verify OpenSSL artefacts
# ncurses-dev: Required for Erlang/OTP new shell & observer_cli - https://github.com/zhongwencool/observer_cli

RUN apk add --no-cache \
	autoconf \
	dpkg-dev dpkg \
	g++ \
	gcc \
	gnupg \
	libc-dev \
	linux-headers \
	make \
	ncurses-dev \
	pkgconfig

FROM build-base AS openssl-builder

# Default to a PGP keyserver that pgp-happy-eyeballs recognizes, but allow for substitutions locally
ARG PGP_KEYSERVER=keyserver.ubuntu.com
# If you are building this image locally and are getting `gpg: keyserver receive failed: No data` errors,
# run the build with a different PGP_KEYSERVER, e.g. docker build --tag rabbitmq:3.9 --build-arg PGP_KEYSERVER=pgpkeys.eu 3.9/ubuntu
# For context, see https://github.com/docker-library/official-images/issues/4252

ENV OPENSSL_VERSION 1.1.1q
ENV OPENSSL_SOURCE_SHA256 d7939ce614029cdff0b6c20f0e2e5703158a489a72b2507b8bd51bf8c8fd10ca
ENV OPENSSL_SOURCE_URL https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
ENV OPENSSL_SOURCE_PATH /usr/local/src/openssl-$OPENSSL_VERSION
ENV OPENSSL_CONFIG_DIR /usr/local/etc/ssl
# https://www.openssl.org/community/omc.html
# TODO auto-generate / scrape this list from the canonical upstream
# source instead (check the signature file and add an entry in the
# .openssl object with just the one signature that we expect to have
# signed this release, after cross-referencing the official OMC list?)
ENV OPENSSL_PGP_KEY_IDS="0x8657ABB260F056B1E5190839D9C4D26D0E604491 0x5B2545DAB21995F4088CEFAA36CEE4DEB00CFE33 0xED230BEC4D4F2518B9D7DF41F0DB4D21C1D35231 0xC1F33DD8CE1D4CC613AF14DA9195C48241FBF7DD 0x7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C 0xE5E52560DD91C556DDBDA5D02064C53641C25E5D"

WORKDIR $OPENSSL_SOURCE_PATH

RUN wget --output-document "$OPENSSL_SOURCE_PATH.tar.gz.asc" "$OPENSSL_SOURCE_URL.asc" && \
	wget --output-document "$OPENSSL_SOURCE_PATH.tar.gz" "$OPENSSL_SOURCE_URL"

RUN set -eux; \
	export GNUPGHOME="$(mktemp -d)"; \
	for key in $OPENSSL_PGP_KEY_IDS; do \
		gpg --batch --keyserver "$PGP_KEYSERVER" --recv-keys "$key"; \
	done; \
	gpg --batch --verify "$OPENSSL_SOURCE_PATH.tar.gz.asc" "$OPENSSL_SOURCE_PATH.tar.gz"; \
	gpgconf --kill all; \
	echo "$OPENSSL_SOURCE_SHA256 *$OPENSSL_SOURCE_PATH.tar.gz" | sha256sum -c -

RUN tar --extract --file "$OPENSSL_SOURCE_PATH.tar.gz" --strip-components 1

# Configure OpenSSL for compilation
#
# Without specifying "--libdir", Erlang will fail during "crypto:supports()"
# looking for a "pthread_atfork" function that doesn't exist (but only on
# arm32v7/armhf??)
#
# add -rpath to avoid conflicts between our OpenSSL's "libssl.so" and the
# libssl package by making sure /usr/local/lib is searched first (but only for
# Erlang/OpenSSL to avoid issues with other tools using libssl;
# https://github.com/docker-library/rabbitmq/issues/364)

RUN set -eux; \
	DEB_BUILD_GNU_CPU="$(dpkg-architecture --query DEB_BUILD_GNU_CPU)"; \
	DEB_BUILD_GNU_TYPE="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	RELEASE="4.x.y-z" SYSTEM='Linux' \
	MACHINE="$DEB_BUILD_GNU_CPU" BUILD="$DEB_BUILD_GNU_TYPE" ./config \
		--openssldir="$OPENSSL_CONFIG_DIR" \
		-Wl,-rpath=/usr/local/lib; \
	make -j "$(getconf _NPROCESSORS_ONLN)"; \
	make install_sw install_ssldirs

RUN set -eux; \
	rmdir "$OPENSSL_CONFIG_DIR/certs" "$OPENSSL_CONFIG_DIR/private"; \
	ln -vsf /etc/ssl/certs /etc/ssl/private "$OPENSSL_CONFIG_DIR"; \
	openssl version

FROM openssl-builder AS erlang-builder

ENV OTP_VERSION 25.1.2
# TODO add PGP checking when the feature will be added to Erlang/OTP's build system
# https://erlang.org/pipermail/erlang-questions/2019-January/097067.html
ENV OTP_SOURCE_SHA256 5442dea694e7555d479d80bc81f1428020639c258f8e40b2052732d1cc95cca5
ENV OTP_SOURCE_URL https://github.com/erlang/otp/releases/download/OTP-$OTP_VERSION/otp_src_$OTP_VERSION.tar.gz
ENV OTP_SOURCE_PATH /usr/local/src/otp-$OTP_VERSION

# Download, verify & extract OTP_SOURCE
WORKDIR $OTP_SOURCE_PATH

RUN set -eux; \
	wget --output-document "$OTP_SOURCE_PATH.tar.gz" "$OTP_SOURCE_URL"; \
	echo "$OTP_SOURCE_SHA256 *$OTP_SOURCE_PATH.tar.gz" | sha256sum -c -; \
	tar --extract --file "$OTP_SOURCE_PATH.tar.gz" --strip-components 1

# Configure Erlang/OTP for compilation, disable unused features & applications
#
# https://erlang.org/doc/applications.html
#
# ERL_TOP is required for Erlang/OTP makefiles to find the absolute path for
# the installation
#
# add -rpath to avoid conflicts between our OpenSSL's "libssl.so" and the
# libssl package by making sure /usr/local/lib is searched first (but only for
# Erlang/OpenSSL to avoid issues with other tools using libssl;
# https://github.com/docker-library/rabbitmq/issues/364)
#
# JIT is only supported on amd64 (until 24.x+1, where it will support arm64 as well)
# https://github.com/erlang/otp/blob/OTP-24.0.5/erts/configure#L21694-L21709 / https://github.com/erlang/otp/pull/4869
RUN set -eux; \
	export ERL_TOP="$OTP_SOURCE_PATH"; \
	export CFLAGS="-g -O2 -Wl,-rpath=/usr/local/lib"; \
	DEB_HOST_GNU_TYPE="$(dpkg-architecture --query DEB_HOST_GNU_TYPE)"; \
	DEB_BUILD_GNU_TYPE="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
	DEB_ARCH="$(dpkg --print-architecture)"; DEB_ARCH="${DEB_ARCH##*-}"; \
	jitFlag=; \
	case "$DEB_ARCH" in \
		amd64) jitFlag='--enable-jit' ;; \
	esac; \
	./configure \
		--host="$DEB_HOST_GNU_TYPE" \
		--build="$DEB_BUILD_GNU_TYPE" \
		--disable-dynamic-ssl-lib \
		--disable-hipe \
		--disable-sctp \
		--disable-silent-rules \
		--enable-clock-gettime \
		--enable-hybrid-heap \
		--enable-kernel-poll \
		--enable-shared-zlib \
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
		$jitFlag

# Compile and install Erlang/OTP
RUN set -eux; \
	make -j "$(getconf _NPROCESSORS_ONLN)" GEN_OPT_FLGS="-O2 -fno-strict-aliasing"; \
	make install

# Remove extra dirs
RUN set -eux; \
	find /usr/local/lib/erlang -type d -name examples -exec rm -rf '{}' +; \
	find /usr/local/lib/erlang -type d -name src -exec rm -rf '{}' +; \
	find /usr/local/lib/erlang -type d -name include -exec rm -rf '{}' +

# Check that OpenSSL still works
# Check that Erlang/OTP crypto & ssl were compiled against OpenSSL correctly
RUN set -eux; \
	openssl version; \
	erl -noshell -eval 'io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'

FROM alpine:3

# Use the latest stable RabbitMQ release (https://www.rabbitmq.com/download.html)
ENV RABBITMQ_VERSION 3.9.24
# https://www.rabbitmq.com/signatures.html#importing-gpg
ENV RABBITMQ_PGP_KEY_ID="0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"
ENV RABBITMQ_HOME=/opt/rabbitmq
ENV RABBITMQ_DATA_DIR /var/lib/rabbitmq
ENV PATH $RABBITMQ_HOME/sbin:$PATH

# warning: the VM is running with native name encoding of latin1 which may cause Elixir to malfunction as it expects utf8. Please ensure your locale is set to UTF-8 (which can be verified by running "locale" in your shell)
# Setting all environment variables that control language preferences, behaviour differs - https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html#The-LANGUAGE-variable
# https://docs.docker.com/samples/library/ubuntu/#locales
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

COPY --from=erlang-builder /usr/local/bin/ /usr/local/bin/
COPY --from=erlang-builder /usr/local/etc/ssl/ /usr/local/etc/ssl/
COPY --from=erlang-builder /usr/local/lib/ /usr/local/lib/

RUN set -eux; \
# Install dependencies required to run Erlang/OTP
# https://erlang.org/doc/installation_guide/INSTALL.html
# bash for docker-entrypoint.sh
# grab su-exec for easy step-down from root
# "ps" for "rabbitmqctl wait" (https://github.com/docker-library/rabbitmq/issues/162)
# Bring in tzdata so users could set the timezones through the environment
	apk add --no-cache \
		'su-exec>=0.2' \
		bash \
		procps \
		tzdata \
	; \
# Configure OpenSSL to use system certs
	ln -vsf /etc/ssl/certs /etc/ssl/private /usr/local/etc/ssl; \
	\
# Install run-time dependencies
	readonly runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("test -e /usr/local/lib/" $1) == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache --virtual .otp-run-deps $runDeps; \
	\
# Create rabbitmq system user & group, fix permissions & allow root user to connect to the RabbitMQ Erlang VM
	addgroup -g 101 -S rabbitmq; \
	adduser -u 100 -S -h "$RABBITMQ_DATA_DIR" -G rabbitmq rabbitmq; \
	mkdir -p "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
	chown -fR rabbitmq:rabbitmq "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
	chmod 777 "$RABBITMQ_DATA_DIR" /etc/rabbitmq /etc/rabbitmq/conf.d /tmp/rabbitmq-ssl /var/log/rabbitmq; \
	ln -sf "$RABBITMQ_DATA_DIR/.erlang.cookie" /root/.erlang.cookie; \
	\
# Install RabbitMQ
	apk add --no-cache --virtual .build-deps \
		gnupg \
		xz; \
	\
	mkdir -p /usr/local/src; \
	RABBITMQ_PATH="/usr/local/src/rabbitmq-$RABBITMQ_VERSION"; \
	RABBITMQ_SOURCE_URL="https://github.com/rabbitmq/rabbitmq-server/releases/download/v$RABBITMQ_VERSION/rabbitmq-server-generic-unix-latest-toolchain-$RABBITMQ_VERSION.tar.xz"; \
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
	rm -f "$RABBITMQ_PATH"*; \
	rmdir /usr/local/src; \
# Do not default SYS_PREFIX to RABBITMQ_HOME, leave it empty
	grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	sed -i 's/^SYS_PREFIX=.*$/SYS_PREFIX=/' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	chown -R rabbitmq:rabbitmq "$RABBITMQ_HOME"; \
	\
# Remove unnecessary packages
	apk del .build-deps; \
	\
# verify assumption of no stale cookies
	[ ! -e "$RABBITMQ_DATA_DIR/.erlang.cookie" ]; \
# Ensure RabbitMQ was installed correctly by running a few commands that do not depend on a running server, as the rabbitmq user
# If they all succeed, it's safe to assume that things have been set up correctly
	su-exec rabbitmq rabbitmqctl help; \
	su-exec rabbitmq rabbitmqctl list_ciphers; \
	su-exec rabbitmq rabbitmq-plugins list; \
# no stale cookies
	rm -f "$RABBITMQ_DATA_DIR/.erlang.cookie"; \
	\
# Enable Prometheus-style metrics by default (https://github.com/docker-library/rabbitmq/issues/419)
	su-exec rabbitmq rabbitmq-plugins enable --offline rabbitmq_prometheus; \
	echo 'management_agent.disable_metrics_collector = true' > /etc/rabbitmq/conf.d/management_agent.disable_metrics_collector.conf; \
	chown rabbitmq:rabbitmq /etc/rabbitmq/conf.d/management_agent.disable_metrics_collector.conf; \
	\
# Added for backwards compatibility - users can simply COPY custom plugins to /plugins
	ln -sf /opt/rabbitmq/plugins /plugins; \
	\
# Check that OpenSSL still works
# Check that Erlang/OTP crypto & ssl were compiled against OpenSSL correctly
	openssl version; \
	erl -noshell -eval 'io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'

# set home so that any `--user` knows where to put the erlang cookie
ENV HOME $RABBITMQ_DATA_DIR
# Hint that the data (a.k.a. home dir) dir should be separate volume
VOLUME $RABBITMQ_DATA_DIR

COPY --chown=rabbitmq:rabbitmq 10-defaults.conf /etc/rabbitmq/conf.d/
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 4369 5671 5672 15691 15692 25672
CMD ["rabbitmq-server"]
