# The official Canonical Ubuntu Bionic image is ideal from a security perspective,
# especially for the enterprises that we, the RabbitMQ team, have to deal with
FROM ubuntu:18.04 as openssl-otp

ARG OTP_VERSION="21.2.2"
# It would be nice if the Ericsson team published these checksums somewhere, will ask on the Erlang mailing list
ARG OTP_SOURCE_SHA256="41b1c3a8343218157a683776e71d80a05ac4eb4019a90a760846608d78817690"
ARG OTP_SOURCE_URL="https://github.com/erlang/otp/archive/OTP-$OTP_VERSION.tar.gz"
ARG OTP_PATH=/usr/local/src/otp-$OTP_VERSION
ARG OTP_INSTALL_DIR=/opt/otp
RUN mkdir -p $OTP_PATH $OTP_INSTALL_DIR

# Using the latest OpenSSL LTS release, with support until September 2023
ARG OPENSSL_VERSION="1.1.1a"
ARG OPENSSL_SOURCE_URL="https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
ARG OPENSSL_PATH=/usr/local/src/openssl-$OPENSSL_VERSION
ARG OPENSSL_INSTALL_DIR=/opt/openssl
ARG OPENSSL_CONFIG_DIR=/usr/local/ssl
RUN mkdir -p $OPENSSL_PATH $OPENSSL_INSTALL_DIR

# Disable prompts when installing packages
ENV DEBIAN_FRONTEND=noninteractive

# Install curl & CA certificates
# Verify that CA certificates work correctly - https://github.com HTTP request succeeds
# I am a true believer in progressive checks, and run the simplest of checks to ensure that installed dependency work.
RUN apt-get update && \
    apt-get install --yes --no-install-recommends curl ca-certificates && \
    curl --version && \
    curl --verbose --head --fail --fail-early --silent https://github.com

# Install dependencies required to build OTP from source
# http://erlang.org/doc/installation_guide/INSTALL.html
RUN apt-get update && \
    apt-get install --yes --no-install-recommends make && \
    make --version
RUN apt-get update && \
    apt-get install --yes --no-install-recommends gcc && \
    gcc --version
# Required to for Erlang/OTP HiPE support
RUN apt-get update && \
    apt-get install --yes --no-install-recommends m4 && \
    m4 --version
# Required for Erlang/OTP new shell & observer_cli
# It would be nice to have a basic check here, same as we do for other dependencies, not sure what/how to check this...
RUN apt-get update && \
    apt-get install --yes --no-install-recommends libncurses5-dev
# Required to configure Erlang/OTP before compiling
RUN apt-get update && \
    apt-get install --yes --no-install-recommends autoconf && \
    autoconf --version
# Required by the crypto & ssl Erlang/OTP applications
# Fail fast if SOURCE URL returns HTTP errors
RUN curl --verbose --head --fail --fail-early $OPENSSL_SOURCE_URL 1>/dev/null && \
    curl --verbose --location --silent --fail --fail-early --output $OPENSSL_PATH.tar.gz $OPENSSL_SOURCE_URL && \
    curl --verbose --location --silent --fail --fail-early --output $OPENSSL_PATH.sha256 $OPENSSL_SOURCE_URL.sha256 && \
    truncate --size -1 $OPENSSL_PATH.sha256 && \
    echo "  $OPENSSL_PATH.tar.gz" >> $OPENSSL_PATH.sha256 && \
    sha256sum --check --strict $OPENSSL_PATH.sha256 && \
    tar -zxvf $OPENSSL_PATH.tar.gz --directory $OPENSSL_PATH --strip-components=1
# Configure OpenSSL for compilation
RUN cd $OPENSSL_PATH && \
    ./config --prefix=$OPENSSL_INSTALL_DIR --openssldir=$OPENSSL_CONFIG_DIR
# Compile & install OpenSSL
RUN cd $OPENSSL_PATH && make -j $(getconf _NPROCESSORS_ONLN) && make test install
# Record OpenSSL artefacts size
RUN du -skh $OPENSSL_INSTALL_DIR $OPENSSL_CONFIG_DIR >> /BUILD_ARTEFACTS

# Download, verify & extract OTP_SOURCE
# Fail fast if SOURCE URL returns HTTP errors
RUN curl --verbose --head --fail --fail-early $OTP_SOURCE_URL 1>/dev/null && \
    curl --verbose --location --silent --fail --fail-early --output $OTP_PATH.tar.gz $OTP_SOURCE_URL && \
    echo "$OTP_SOURCE_SHA256  $OTP_PATH.tar.gz" > $OTP_PATH.sha256 && \
    sha256sum --check --strict $OTP_PATH.sha256 && \
    tar -zxvf $OTP_PATH.tar.gz --directory $OTP_PATH --strip-components=1

# Required for Erlang/OTP makefiles to find the absolute path for the installation
ENV ERL_TOP=$OTP_PATH

# Configure Erlang/OTP for compilation, disable unused features & applications
# http://erlang.org/doc/applications.html
RUN cd $OTP_PATH && \
    ./otp_build autoconf && \
    ./configure \
      --prefix=$OTP_INSTALL_DIR \
      --disable-sctp \
      --enable-hipe \
      --enable-lock-counter \
      --with-microstate-accounting=extra \
      --disable-dynamic-ssl-lib \
      --with-ssl=$OPENSSL_INSTALL_DIR \
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
RUN cd $OTP_PATH && make -j $(getconf _NPROCESSORS_ONLN) && make install
# Record Erlang/OTP artefacts size
RUN du -skh $OTP_INSTALL_DIR >> /BUILD_ARTEFACTS

# Check that Erlang/OTP crypto & ssl were compiled against OpenSSL correctly
RUN $OTP_INSTALL_DIR/bin/erl -noshell -eval 'io:format("~p~n~n~p~n~n", [crypto:supports(), ssl:versions()]), init:stop().'

# TODO
# Start with new FROM
# Copy necessary artefacts from openssl-otp
# Install RabbitMQ
# Ensure RabbitMQ starts & rabbitmqctl works correctly
