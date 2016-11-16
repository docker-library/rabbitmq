FROM rabbitmq:management


ENV RABBITMQ_AUTOCLUSTER 0.6.1

RUN  apt-get update -y && apt-get install -y wget && \
wget -qO- https://github.com/aweber/rabbitmq-autocluster/releases/download/$RABBITMQ_AUTOCLUSTER/autocluster-$RABBITMQ_AUTOCLUSTER.tgz  | tar xvz -C /plugins/ --strip 1 && \
apt-get purge -y wget

RUN rabbitmq-plugins enable --offline autocluster

