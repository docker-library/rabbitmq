FROM rabbitmqlocal:3.6.2-management

COPY rabbitmq_clusterer-3.6.x-667f92b0.ez $RABBITMQ_HOME/plugins

COPY cluster.config /etc/rabbitmq/

RUN rabbitmq-plugins enable rabbitmq_clusterer --offline