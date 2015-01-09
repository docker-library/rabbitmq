FROM rabbitmq:3.4.3

RUN rabbitmq-plugins enable --offline rabbitmq_management
RUN echo '[{rabbit, [{loopback_users, []}]}].' > /etc/rabbitmq/rabbitmq.config

EXPOSE 15672
