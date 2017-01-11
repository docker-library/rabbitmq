FROM alpine:3.5

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN addgroup -S rabbitmq && adduser -S -h /var/lib/rabbitmq -G rabbitmq rabbitmq

# grab su-exec for easy step-down from root
RUN apk add --no-cache 'su-exec>=0.2'

RUN apk add --no-cache \
# Bash for docker-entrypoint
		bash \
# Erlang for RabbitMQ
		erlang-asn1 \
		erlang-hipe \
		erlang-crypto \
		erlang-eldap \
		erlang-inets \
		erlang-mnesia \
		erlang \
		erlang-os-mon \
		erlang-public-key \
		erlang-ssl \
		erlang-xmerl

# get logs to stdout (thanks @dumbbell for pushing this upstream! :D)
ENV RABBITMQ_LOGS=- RABBITMQ_SASL_LOGS=-
# https://github.com/rabbitmq/rabbitmq-server/commit/53af45bf9a162dec849407d114041aad3d84feaf

ENV RABBITMQ_HOME /opt/rabbitmq
ENV PATH $RABBITMQ_HOME/sbin:$PATH

# https://www.rabbitmq.com/install-generic-unix.html
ENV GPG_KEY 0A9AF2115F4687BD29803A206B73A36E6026DFCA

ENV RABBITMQ_VERSION 3.6.6

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		ca-certificates \
		gnupg \
		openssl \
		tar \
		xz \
	; \
	\
	wget -O rabbitmq-server.tar.xz "https://www.rabbitmq.com/releases/rabbitmq-server/v${RABBITMQ_VERSION}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz"; \
	wget -O rabbitmq-server.tar.xz.asc "https://www.rabbitmq.com/releases/rabbitmq-server/v${RABBITMQ_VERSION}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz.asc"; \
	\
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY"; \
	gpg --batch --verify rabbitmq-server.tar.xz.asc rabbitmq-server.tar.xz; \
	rm -r "$GNUPGHOME" rabbitmq-server.tar.xz.asc; \
	\
	mkdir -p "$RABBITMQ_HOME"; \
	tar \
		--extract \
		--verbose \
		--file rabbitmq-server.tar.xz \
		--directory "$RABBITMQ_HOME" \
		--strip-components 1 \
	; \
	rm rabbitmq-server.tar.xz; \
	\
# update SYS_PREFIX (first making sure it's set to what we expect it to be)
	grep -qE '^SYS_PREFIX=\$\{RABBITMQ_HOME\}$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	sed -ri 's!^(SYS_PREFIX=).*$!\1!g' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	grep -qE '^SYS_PREFIX=$' "$RABBITMQ_HOME/sbin/rabbitmq-defaults"; \
	\
	apk del .build-deps

# set home so that any `--user` knows where to put the erlang cookie
ENV HOME /var/lib/rabbitmq

RUN mkdir -p /var/lib/rabbitmq /etc/rabbitmq \
	&& echo '[ { rabbit, [ { loopback_users, [ ] } ] } ].' > /etc/rabbitmq/rabbitmq.config \
	&& chown -R rabbitmq:rabbitmq /var/lib/rabbitmq /etc/rabbitmq \
	&& chmod -R 777 /var/lib/rabbitmq /etc/rabbitmq
VOLUME /var/lib/rabbitmq

# add a symlink to the .erlang.cookie in /root so we can "docker exec rabbitmqctl ..." without gosu
RUN ln -sf /var/lib/rabbitmq/.erlang.cookie /root/

RUN ln -sf "$RABBITMQ_HOME/plugins" /plugins

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 4369 5671 5672 25672
CMD ["rabbitmq-server"]
