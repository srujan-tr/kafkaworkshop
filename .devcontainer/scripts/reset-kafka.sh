#!/usr/bin/env bash
set -euo pipefail

KAFKA_HOME=${KAFKA_HOME:-"${HOME}/kafka"}
DATA_DIR="${KAFKA_HOME}/data"
CFG="${KAFKA_HOME}/config/kraft/server.properties"

if [[ ! -x "${KAFKA_HOME}/bin/kafka-storage.sh" ]]; then
	echo "Kafka not installed at ${KAFKA_HOME}. Run setup first." >&2
	exit 1
fi

# Stop if running
if command -v nc >/dev/null 2>&1 && nc -z localhost 9092 >/dev/null 2>&1; then
	"${KAFKA_HOME}/bin/kafka-server-stop.sh" || true
	# Wait briefly
	for i in $(seq 1 30); do
		if nc -z localhost 9092 >/dev/null 2>&1; then sleep 1; else break; fi
	done
fi

# Wipe data
rm -rf "${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# Reformat storage
"${KAFKA_HOME}/bin/kafka-storage.sh" format -t "$("${KAFKA_HOME}/bin/kafka-storage.sh" random-uuid)" -c "${CFG}"

echo "Kafka state reset. Start again with: .devcontainer/scripts/start-kafka.sh"
