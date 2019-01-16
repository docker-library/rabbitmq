# The official Canonical Ubuntu Bionic image is ideal from a security perspective,
# especially for the enterprises that we, the RabbitMQ team, have to deal with
FROM ubuntu:18.04 AS release

# Start a new builder image so that the release image remains unmodified
FROM release AS builder

# Install curl & CA certificates
# Verify that CA certificates work correctly - https://github.com HTTP request succeeds
# I believe in progressive checks: run the simplest checks to ensure that the installed dependency works
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl ca-certificates && \
    curl --version && \
    curl --verbose --head --fail --fail-early --silent https://github.com

# Install dependencies required to build Erlang/OTP from source
# http://erlang.org/doc/installation_guide/INSTALL.html
RUN apt-get update && \
    apt-get install --yes --no-install-recommends make && \
    make --version
RUN apt-get update && \
    apt-get install --yes --no-install-recommends gcc && \
    gcc --version

# Required to configure Erlang/OTP before compiling
RUN apt-get update && \
    apt-get install --yes --no-install-recommends autoconf && \
    autoconf --version

# Required to set up host & build type when compiling Erlang/OTP
RUN apt-get update && \
    apt-get install --yes --no-install-recommends dpkg-dev && \
    dpkg-architecture

# Required for Erlang/OTP HiPE support
RUN apt-get update && \
    apt-get install --yes --no-install-recommends m4 && \
    m4 --version

# Required for Erlang/OTP new shell & observer_cli - https://github.com/zhongwencool/observer_cli
# It would be nice to have a basic check here, same as we do for other dependencies, but I'm not sure what/how to check this...
RUN apt-get update && \
    apt-get install --yes --no-install-recommends libncurses5-dev

# Required to verify OpenSSL & RabbitMQ artefacts
RUN apt-get update && \
    apt-get install --yes --no-install-recommends gnupg && \
    gpg --version

# Required to uncompress xz files, such as rabbitmq-server-generic-unix-3.7.10.tar.xz
RUN apt-get update && \
    apt-get install --yes --no-install-recommends xz-utils && \
    xz --version

# Default to a PGP keyserver that pgp-happy-eyeballs recognizes, but allow for substitutions locally
# https://github.com/docker-library/official-images/issues/4252
# If you are building this image locally and are getting `gpg: keyserver receive failed: No data` errors,
# run the build with a different PGP_KEYSERVER, e.g. docker build --tag rabbitmq:3.7 --build-arg PGP_KEYSERVER=pgpkeys.eu 3.7/ubuntu
# For context, see
ARG PGP_KEYSERVER=ha.pool.sks-keyservers.net

# Using the latest OpenSSL LTS release, with support until September 2023 - https://www.openssl.org/source/
ARG OPENSSL_VERSION="1.1.1a"
ARG OPENSSL_SOURCE_URL="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
ARG OPENSSL_PATH=/usr/local/src/openssl-$OPENSSL_VERSION
ARG OPENSSL_INSTALL_DIR=/opt/openssl
ARG OPENSSL_CONFIG_DIR=/usr/local/ssl
RUN mkdir -p $OPENSSL_PATH $OPENSSL_INSTALL_DIR
# https://www.openssl.org/community/omc.html
ARG OPENSSL_PGP_KEY_ID=0x8657ABB260F056B1E5190839D9C4D26D0E604491

# Required by the crypto & ssl Erlang/OTP applications
# Fail fast if SOURCE URL returns HTTP errors
RUN curl --verbose --head --fail --fail-early $OPENSSL_SOURCE_URL 1>/dev/null && \
    curl --verbose --location --silent --fail --fail-early --output $OPENSSL_PATH.tar.gz $OPENSSL_SOURCE_URL && \
    curl --verbose --location --silent --fail --fail-early --output $OPENSSL_PATH.tar.gz.asc $OPENSSL_SOURCE_URL.asc && \
    gpg --batch --keyserver $PGP_KEYSERVER --recv-keys $OPENSSL_PGP_KEY_ID && \
    gpg --batch --verify $OPENSSL_PATH.tar.gz.asc $OPENSSL_PATH.tar.gz && \
    command -v gpgconf > /dev/null && gpgconf --kill all && \
    tar -xvf $OPENSSL_PATH.tar.gz --directory $OPENSSL_PATH --strip-components=1
# Configure OpenSSL for compilation
RUN cd $OPENSSL_PATH && \
    ./config --prefix=$OPENSSL_INSTALL_DIR --openssldir=$OPENSSL_CONFIG_DIR
# Compile, install OpenSSL, verify that the command-line works & development headers are present
# Remove docs & man pages to keep the artefact small (saves ~11MB)
RUN cd $OPENSSL_PATH && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make test install uninstall_docs && \
    LD_LIBRARY_PATH=$OPENSSL_INSTALL_DIR/lib $OPENSSL_INSTALL_DIR/bin/openssl help && \
    ls $OPENSSL_INSTALL_DIR/lib/libcrypto.so $OPENSSL_INSTALL_DIR/include/openssl/*.h
# Record OpenSSL artefacts size
RUN du -kh -d 1 $OPENSSL_INSTALL_DIR $OPENSSL_CONFIG_DIR >> /OPENSSL_BUILD_ARTEFACTS

# Use the latest stable Erlang/OTP release
ARG OTP_VERSION="21.2.3"
# TODO add PGP checking when the feature will be added to Erlang/OTP's build system
# http://erlang.org/pipermail/erlang-questions/2019-January/097067.html
ARG OTP_SOURCE_SHA256="109a5722e398bdcd3aeb4f4833cde90bf441a9c014006439643aab550a770923"
ARG OTP_SOURCE_URL="https://github.com/erlang/otp/archive/OTP-$OTP_VERSION.tar.gz"
ARG OTP_PATH=/usr/local/src/otp-$OTP_VERSION
ARG OTP_INSTALL_DIR=/opt/otp
RUN mkdir -p $OTP_PATH $OTP_INSTALL_DIR

# Download, verify & extract OTP_SOURCE
# Fail fast if SOURCE URL returns HTTP errors
RUN curl --verbose --head --fail --fail-early $OTP_SOURCE_URL 1>/dev/null && \
    curl --verbose --location --silent --fail --fail-early --output $OTP_PATH.tar.gz $OTP_SOURCE_URL && \
    echo "$OTP_SOURCE_SHA256  $OTP_PATH.tar.gz" > $OTP_PATH.sha256 && \
    sha256sum --check --strict $OTP_PATH.sha256 && \
    tar -xvf $OTP_PATH.tar.gz --directory $OTP_PATH --strip-components=1

# Configure Erlang/OTP for compilation, disable unused features & applications
# http://erlang.org/doc/applications.html
# ERL_TOP is required for Erlang/OTP makefiles to find the absolute path for the installation
RUN cd $OTP_PATH && \
    export ERL_TOP=$OTP_PATH && \
    ./otp_build autoconf && \
    export CFLAGS="$(dpkg-buildflags --get CFLAGS)" && \
    ./configure \
      --host="$(dpkg-architecture --query DEB_HOST_GNU_TYPE)" \
      --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
      --prefix=$OTP_INSTALL_DIR \
      --disable-sctp \
      --disable-silent-rules \
      --disable-dynamic-ssl-lib \
      --with-ssl=$OPENSSL_INSTALL_DIR \
      --enable-clock-gettime \
      --enable-hybrid-heap \
      --enable-kernel-poll \
      --enable-shared-zlib \
      --enable-threads \
      --enable-smp-support \
      --enable-hipe \
      --with-microstate-accounting=extra \
      --without-odbc \
      --without-diameter \
      --without-erl_interface \
      --without-ftp \
      --without-jinterface \
      --without-megaco \
      --without-ssh \
      --without-tftp \
      --without-wx \
      --without-debugger \
      --without-dialyzer \
      --without-et \
      --without-observer \
      --without-reltool \
      --without-common_test \
      --without-eunit \
      --without-edoc \
      --without-erl_docgen

# Compile & install Erlang/OTP
RUN cd $OTP_PATH && export ERL_TOP=$OTP_PATH && make -j "$(getconf _NPROCESSORS_ONLN)" GEN_OPT_FLGS="-O2 -fno-strict-aliasing" && make install

# Delete all src dirs to keep the final image size down, they add an extra 19MB
# TODO @dumbbell could this be done better, in the build/install phases?
RUN rm -fr $OTP_INSTALL_DIR/lib/erlang/lib/*/src

# Record Erlang/OTP artefacts size
RUN du -kh -d 1 $OTP_INSTALL_DIR/lib/erlang >> /OTP_BUILD_ARTEFACTS

# Check that Erlang/OTP crypto & ssl were compiled against OpenSSL correctly
RUN $OTP_INSTALL_DIR/bin/erl -noshell -eval 'io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'

# Use the latest stable RabbitMQ release
ARG RABBITMQ_VERSION="3.7.10"
ARG RABBITMQ_SOURCE_URL="https://github.com/rabbitmq/rabbitmq-server/releases/download/v$RABBITMQ_VERSION/rabbitmq-server-generic-unix-$RABBITMQ_VERSION.tar.xz"
ARG RABBITMQ_PATH=/usr/local/src/rabbitmq-$RABBITMQ_VERSION
ARG RABBITMQ_INSTALL_DIR=/opt/rabbitmq
RUN mkdir -p $RABBITMQ_INSTALL_DIR
# https://www.rabbitmq.com/signatures.html#importing-gpg
ENV RABBITMQ_PGP_KEY_ID="0x0A9AF2115F4687BD29803A206B73A36E6026DFCA"

# Install RabbitMQ
# Fail fast if SOURCE URL returns HTTP errors
RUN curl --verbose --head --fail --fail-early $RABBITMQ_SOURCE_URL 1>/dev/null && \
    curl --verbose --location --silent --fail --fail-early --output $RABBITMQ_PATH.tar.xz $RABBITMQ_SOURCE_URL && \
    curl --verbose --location --silent --fail --fail-early --output $RABBITMQ_PATH.tar.xz.asc $RABBITMQ_SOURCE_URL.asc && \
    gpg --batch --keyserver $PGP_KEYSERVER --recv-keys "$RABBITMQ_PGP_KEY_ID" && \
    gpg --batch --verify $RABBITMQ_PATH.tar.xz.asc $RABBITMQ_PATH.tar.xz && \
    command -v gpgconf > /dev/null && gpgconf --kill all && \
    tar -xvf $RABBITMQ_PATH.tar.xz --directory $RABBITMQ_INSTALL_DIR --strip-components=1

# Do not default SYS_PREFIX to RABBITMQ_HOME, leave it empty
RUN sed -i 's/^SYS_PREFIX=.*/SYS_PREFIX=/' $RABBITMQ_INSTALL_DIR/sbin/rabbitmq-defaults

# Start with the unmodified release image
FROM release
# Duplicate ARGs since they are not preserved between stages in multi-stage builds
ARG OPENSSL_INSTALL_DIR=/opt/openssl
ARG OPENSSL_CONFIG_DIR=/usr/local/ssl
ARG OTP_INSTALL_DIR=/opt/otp
ARG RABBITMQ_INSTALL_DIR=/opt/rabbitmq

ARG RABBITMQ_DATA_DIR=/var/lib/rabbitmq
ARG RABBITMQ_LOG_DIR=/var/log/rabbitmq
ARG RABBITMQ_CONF_DIR=/etc/rabbitmq
ARG RABBITMQ_TMP_SSL_DIR=/tmp/rabbitmq-ssl
# Only copy the build artefacts required to run RabbitMQ
COPY --from=builder $OPENSSL_INSTALL_DIR $OPENSSL_INSTALL_DIR
COPY --from=builder $OPENSSL_CONFIG_DIR $OPENSSL_CONFIG_DIR
COPY --from=builder $OTP_INSTALL_DIR $OTP_INSTALL_DIR
COPY --from=builder $RABBITMQ_INSTALL_DIR $RABBITMQ_INSTALL_DIR

# Add OpenSSL to PATH
ENV PATH=$OPENSSL_INSTALL_DIR/bin:$PATH LD_LIBRARY_PATH=$OPENSSL_INSTALL_DIR/lib
# Ensure OpenSSL works by listing all commands
RUN openssl help

# Add Erlang/OTP to PATH
ENV PATH=$OTP_INSTALL_DIR/bin:$PATH
# Ensure Erlang/OTP works by listing all loaded modules
RUN erl -noshell -eval 'io:format("~p~n", [code:all_loaded()]), init:stop().'

# Create rabbitmq system user & group, fix permissions & allow root user to connect to the RabbitMQ Erlang VM
RUN groupadd --system rabbitmq && \
    useradd --system --home-dir $RABBITMQ_DATA_DIR --create-home --gid rabbitmq rabbitmq && \
    mkdir -p $RABBITMQ_CONF_DIR $RABBITMQ_LOG_DIR $RABBITMQ_DATA_DIR $RABBITMQ_TMP_SSL_DIR $RABBITMQ_TMP_SSL_DIR && \
    chown -fR rabbitmq:rabbitmq $RABBITMQ_INSTALL_DIR $RABBITMQ_CONF_DIR $RABBITMQ_LOG_DIR $RABBITMQ_DATA_DIR && \
    ln -sf $RABBITMQ_DATA_DIR/.erlang.cookie /root/.erlang.cookie

# Added for backwards compatibility - users can simply COPY custom plugins to /plugins
RUN ln -sf /opt/rabbitmq/plugins /plugins

# Hint that the data (a.k.a. home dir) dir should be separate volume
VOLUME $RABBITMQ_DATA_DIR

# Add RabbitMQ to PATH, send all logs to TTY
ENV PATH=$RABBITMQ_INSTALL_DIR/sbin:$PATH RABBITMQ_LOGS=-

# warning: the VM is running with native name encoding of latin1 which may cause Elixir to malfunction as it expects utf8. Please ensure your locale is set to UTF-8 (which can be verified by running "locale" in your shell)
# Setting all environment variables that control language preferences, behaviour differs - https://www.gnu.org/software/gettext/manual/html_node/The-LANGUAGE-variable.html#The-LANGUAGE-variable
# https://docs.docker.com/samples/library/ubuntu/#locales
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

# Ensure RabbitMQ was installed correctly by running a few commands that do not depend on a running server, as the rabbitmq user
# If they all succeed, it's safe to assume that things have been set up correctly
RUN rabbitmqctl help && rabbitmqctl list_ciphers && rabbitmq-plugins list

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.10
RUN set -eux; \
      apt-get update; \
      apt-get install -y --no-install-recommends gosu; \
      rm -rf /var/lib/apt/lists/*; \
# verify that the binary works
      gosu nobody true

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s /usr/local/bin/docker-entrypoint.sh / # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 4369 5671 5672 25672
CMD ["rabbitmq-server"]
