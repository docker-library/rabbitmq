FROM robertobarreda/rabbitmq

RUN rabbitmq-plugins enable --offline rabbitmq_management
RUN rabbitmq-plugins enable --offline rabbitmq_mqtt

EXPOSE 15671 15672
EXPOSE 1883 8883
