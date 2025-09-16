#!/usr/bin/env bash
set -euo pipefail

UI_PORT=${UI_PORT:-8080}
if command -v nc >/dev/null 2>&1; then
	if nc -z localhost ${UI_PORT} >/dev/null 2>&1; then
		echo "Kafka UI: RUNNING (http://localhost:${UI_PORT})"
		exit 0
	else
		echo "Kafka UI: NOT RUNNING"
		exit 1
	fi
else
	echo "nc not available; cannot probe port."
	exit 2
fi
