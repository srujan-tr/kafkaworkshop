#!/usr/bin/env bash
set -euo pipefail

KAFKA_HOME=${KAFKA_HOME:-"${HOME}/kafka"}

if [[ ! -x "${KAFKA_HOME}/bin/kafka-server-stop.sh" ]]; then
	echo "Kafka not installed at ${KAFKA_HOME}." >&2
	exit 1
fi

"${KAFKA_HOME}/bin/kafka-server-stop.sh" || true

# Wait for port 9092 to close (up to 60s)
for i in $(seq 1 60); do
	if command -v nc >/dev/null 2>&1; then
		if nc -z localhost 9092 >/dev/null 2>&1; then
			sleep 1
		else
			echo "Kafka stopped."
			exit 0
		fi
	else
		# If nc not available, just sleep a bit and exit
		sleep 3
		echo "Requested Kafka stop (nc not available to verify)."
		exit 0
	fi

done

echo "WARNING: Kafka may still be running (port 9092 still open)."
exit 1
