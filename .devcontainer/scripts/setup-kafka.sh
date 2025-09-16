#!/usr/bin/env bash
set -euo pipefail

# Constants and defaults
KAFKA_HOME=${KAFKA_HOME:-"${HOME}/kafka"}
SCALA_VERSION=${SCALA_VERSION:-2.13}
WORK_DIR=$(pwd)

# Ensure required tools
if ! command -v sudo >/dev/null 2>&1; then
	echo "sudo not found; attempting to proceed without it"
	sudo() { "$@"; }
fi

sudo apt-get update -y
sudo apt-get install -y curl wget ca-certificates tar coreutils grep sed netcat-openbsd
# Ensure Java 17 available (runner environments may not have it)
if ! command -v java >/dev/null 2>&1; then
    sudo apt-get install -y openjdk-17-jre-headless || sudo apt-get install -y openjdk-17-jdk
fi

mkdir -p "$KAFKA_HOME"
KAFKA_HOME_ABS=$(cd "$KAFKA_HOME" && pwd)

# Helper: detect latest stable Kafka 4.x from Apache mirrors
get_latest_kafka_4x() {
	local v
	v=$(curl -fsSL https://downloads.apache.org/kafka/ | \
		grep -oE 'href="[0-9]+\.[0-9]+\.[0-9]+/?"' | \
		sed -E 's/.*href=\"([0-9]+\.[0-9]+\.[0-9]+)\/?\".*/\1/' | \
		grep -E '^4\.' | sort -V | tail -1 || true)
	if [[ -z "${v:-}" ]]; then
		v=$(curl -fsSL https://archive.apache.org/dist/kafka/ | \
			grep -oE 'href="[0-9]+\.[0-9]+\.[0-9]+/?"' | \
			sed -E 's/.*href=\"([0-9]+\.[0-9]+\.[0-9]+)\/?\".*/\1/' | \
			grep -E '^4\.' | sort -V | tail -1 || true)
	fi
	if [[ -z "${v:-}" ]]; then
		echo ""; return 1
	fi
	echo "$v"
}

# Resolve Kafka version (prefer env, else detect)
KAFKA_VERSION=${KAFKA_VERSION:-}
if [[ -z "${KAFKA_VERSION}" ]]; then
	KAFKA_VERSION=$(get_latest_kafka_4x || true)
fi
if [[ -z "${KAFKA_VERSION}" ]]; then
	echo "ERROR: Unable to resolve latest Kafka 4.x version from Apache. Set KAFKA_VERSION env and retry." >&2
	exit 1
fi

TARBALL="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
BASE_DL_URL_1="https://downloads.apache.org/kafka/${KAFKA_VERSION}"
BASE_DL_URL_2="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}"
TMP_TGZ="/tmp/${TARBALL}"
TMP_SHA="/tmp/${TARBALL}.sha512"

# Download tarball if not already installed
if [[ ! -x "${KAFKA_HOME_ABS}/bin/kafka-server-start.sh" ]]; then
	echo "Installing Apache Kafka ${KAFKA_VERSION} (Scala ${SCALA_VERSION}) to ${KAFKA_HOME_ABS}"
	set +e
	curl -fsSL "${BASE_DL_URL_1}/${TARBALL}" -o "${TMP_TGZ}"
	dl_rc=$?
	set -e
	if [[ $dl_rc -ne 0 ]]; then
		echo "Primary download failed, trying archive..."
		curl -fsSL "${BASE_DL_URL_2}/${TARBALL}" -o "${TMP_TGZ}"
	fi

	# Try SHA512 verification (best effort)
	set +e
	curl -fsSL "${BASE_DL_URL_1}/${TARBALL}.sha512" -o "${TMP_SHA}" || \
	curl -fsSL "${BASE_DL_URL_2}/${TARBALL}.sha512" -o "${TMP_SHA}"
	if [[ -s "${TMP_SHA}" ]]; then
		# Extract 128-hex-digit hash from common formats
		EXPECTED=$(awk '{ for (i=1; i<=NF; i++) if ($i ~ /^[A-Fa-f0-9]{128}$/) { print tolower($i); exit } }' "${TMP_SHA}")
		ACTUAL=$(sha512sum "${TMP_TGZ}" | awk '{print tolower($1)}')
		if [[ -n "$EXPECTED" ]]; then
			if [[ "$EXPECTED" != "$ACTUAL" ]]; then
				echo "WARNING: SHA512 mismatch (expected begins: ${EXPECTED:0:12}, actual: ${ACTUAL:0:12}). Proceeding anyway." >&2
			fi
		else
			echo "WARNING: Could not parse SHA512 file. Proceeding without strict verification." >&2
		fi
	else
		echo "WARNING: Could not fetch SHA512. Proceeding without checksum verification." >&2
	fi
	set -e

	# Extract
	tar -xzf "${TMP_TGZ}" -C "${KAFKA_HOME_ABS}" --strip-components=1
fi

# Ensure directories
mkdir -p "${KAFKA_HOME_ABS}/config/kraft" "${KAFKA_HOME_ABS}/data" "${KAFKA_HOME_ABS}/logs"

# Write server.properties (idempotent overwrite to keep workshop consistent)
cat > "${KAFKA_HOME_ABS}/config/kraft/server.properties" <<EOF
process.roles=broker,controller
node.id=1
controller.quorum.voters=1@localhost:9093
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://:9092,CONTROLLER://:9093
advertised.listeners=PLAINTEXT://localhost:9092
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
inter.broker.listener.name=PLAINTEXT
log.dirs=${KAFKA_HOME_ABS}/data

num.partitions=1
default.replication.factor=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
min.insync.replicas=1
auto.create.topics.enable=true
EOF

# Format storage if not already formatted
META_FILE="${KAFKA_HOME_ABS}/data/meta.properties"
if [[ ! -f "${META_FILE}" ]]; then
	echo "Formatting KRaft storage at ${KAFKA_HOME_ABS}/data"
	"${KAFKA_HOME_ABS}/bin/kafka-storage.sh" format -t "$("${KAFKA_HOME_ABS}/bin/kafka-storage.sh" random-uuid)" -c "${KAFKA_HOME_ABS}/config/kraft/server.properties"
fi

# Add KAFKA_HOME and PATH to shell profile (idempotent)
BASHRC="${HOME}/.bashrc"
if ! grep -q "KAFKA_HOME=${KAFKA_HOME_ABS}" "$BASHRC" 2>/dev/null; then
	echo "export KAFKA_HOME=${KAFKA_HOME_ABS}" >> "$BASHRC"
fi
if ! grep -q 'export PATH=\$KAFKA_HOME/bin:\$PATH' "$BASHRC" 2>/dev/null; then
	echo 'export PATH=$KAFKA_HOME/bin:$PATH' >> "$BASHRC"
fi

# Ensure helper scripts are executable if present
chmod +x .devcontainer/scripts/*.sh 2>/dev/null || true

echo "Setup complete. Kafka is installed but not started. Use start-kafka.sh to start."
