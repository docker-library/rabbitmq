#!/bin/bash
set -eo pipefail

host="$(hostname || echo 'localhost')"
export RABBITMQ_NODENAME="${RABBITMQ_NODENAME:-"rabbit@$host"}"

if rabbitmqctl status; then
    exit 0
fi

exit 1
