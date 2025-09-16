#!/usr/bin/env bash
set -euo pipefail

if command -v nc >/dev/null 2>&1; then
	if nc -z localhost 9092 >/dev/null 2>&1; then
		echo "Kafka: RUNNING (localhost:9092 reachable)"
		exit 0
	else
		echo "Kafka: NOT RUNNING (localhost:9092 not reachable)"
		exit 1
	fi
else
	echo "nc not available; cannot probe port."
	exit 2
fi
