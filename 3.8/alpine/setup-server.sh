#!/bin/bash
while true
do
  rabbitmq-diagnostics check_running > /dev/null 2>&1
  verifier=$?
  if [[ $verifier == 0 ]]
    then
      if [[ -n $CLUSTER_WITH ]]; then
          rabbitmqctl stop_app
          if [[ -z $RAM_NODE ]]; then
            rabbitmqctl join_cluster rabbit@"$CLUSTER_WITH"
          else
            rabbitmqctl join_cluster --ram rabbit@"$CLUSTER_WITH"
          fi
          rabbitmqctl start_app

        if [[ -n $RABBITMQ_POLICY_HA_ALL ]]; then
          rabbitmqctl set_policy ha-all "^(?!amq\.).*" '{"ha-mode":"all", "ha-sync-mode":"automatic"}'
        fi
      fi

      if [[ -n $FEDERATE_WITH ]]; then
        # FEDERATE_WITH can be a list of servers separated by ', '
        IFS=', ' read -r -a fed_servers <<< "$FEDERATE_WITH"
        for server in "${fed_servers[@]}"
        do
          if [[ -n $RABBITMQ_DEFAULT_USER ]] &&  [[ -n $RABBITMQ_DEFAULT_PASS ]]; then
            rabbitmqctl set_parameter federation-upstream optimo-upstream '{"uri":"amqp://'$RABBITMQ_DEFAULT_USER':'$RABBITMQ_DEFAULT_PASS'@'$server'"}'
          else
            rabbitmqctl set_parameter federation-upstream optimo-upstream '{"uri":"amqp://'$server'"}'
          fi
        done

        if [[ -n $RABBITMQ_POLICY_FEDERATION ]]; then
          rabbitmqctl set_policy --apply-to queues optimo-fed-queues "^(?!amq\.).*" '{"federation-upstream-set":"all"}'
        fi
      fi
      echo "RabbitMQ has successfully started."
      break
    else
      echo "RabbitMQ is not running yet..."
      sleep 5
  fi
done

