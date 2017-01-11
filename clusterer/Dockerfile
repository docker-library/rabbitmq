FROM rabbitmq

ENV RABBITMQ_CLUSTERER_VERSION 1.0.3

RUN set -x \
        && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
        && wget -O /usr/lib/rabbitmq/lib/rabbitmq_server-${RABBITMQ_VERSION}/plugins/rabbitmq_clusterer-${RABBITMQ_CLUSTERER_VERSION}.ez https://github.com/rabbitmq/rabbitmq-clusterer/releases/download/v${RABBITMQ_CLUSTERER_VERSION}/rabbitmq_clusterer-${RABBITMQ_CLUSTERER_VERSION}.ez \
        && apt-get purge -y --auto-remove ca-certificates wget

RUN rabbitmq-plugins enable --offline rabbitmq_clusterer
