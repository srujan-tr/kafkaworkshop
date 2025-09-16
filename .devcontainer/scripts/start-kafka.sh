#!/usr/bin/env bash
set -euo pipefail

KAFKA_HOME=${KAFKA_HOME:-"${HOME}/kafka"}
CFG="${KAFKA_HOME}/config/kraft/server.properties"

if [[ ! -x "${KAFKA_HOME}/bin/kafka-server-start.sh" ]]; then
	echo "Kafka not installed at ${KAFKA_HOME}. Run setup first." >&2
	exit 1
fi

# If already listening, refuse to start
if command -v nc >/dev/null 2>&1; then
	if nc -z localhost 9092 >/dev/null 2>&1; then
		echo "Kafka appears to be running (port 9092 open)." >&2
		exit 1
	fi
fi

# Compute heap
mem_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
fraction=${KAFKA_HEAP_FRACTION:-80}
heap_mb=${KAFKA_HEAP_MB:-0}
if [[ "${heap_mb}" == "0" || -z "${heap_mb}" ]]; then
	heap_mb=$(( mem_kb * fraction / 100 / 1024 ))
	if (( heap_mb < 512 )); then heap_mb=512; fi
fi
export KAFKA_HEAP_OPTS="-Xms${heap_mb}m -Xmx${heap_mb}m"

echo "Starting Kafka with KAFKA_HEAP_OPTS='${KAFKA_HEAP_OPTS}'"
exec "${KAFKA_HOME}/bin/kafka-server-start.sh" "${CFG}"
