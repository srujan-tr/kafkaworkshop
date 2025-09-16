#!/usr/bin/env bash
set -euo pipefail

# Install Kafka UI (provectuslabs/kafka-ui) as a standalone jar
# We avoid Docker per project requirements.

UI_HOME=${UI_HOME:-"${HOME}/kafka-ui"}
UI_PORT=${UI_PORT:-8080}

mkdir -p "${UI_HOME}"

# Detect latest release version from GitHub API (fallback to known version if API blocked)
LATEST_TAG=$(curl -fsSL https://api.github.com/repos/provectus/kafka-ui/releases/latest | grep -oE '"tag_name":\s*"[^"]+"' | sed -E 's/.*"tag_name":\s*"([^"]+)"/\1/' || true)
if [[ -z "${LATEST_TAG}" ]]; then
	# Fallback to a stable known tag (update as needed)
	LATEST_TAG="v0.7.2"
fi

JAR_NAME="kafka-ui-api.jar"
JAR_PATH="${UI_HOME}/${JAR_NAME}"

if [[ ! -f "${JAR_PATH}" ]]; then
	# Download packaged jar artifact from releases
	ASSET_URL=$(curl -fsSL https://api.github.com/repos/provectus/kafka-ui/releases/tags/${LATEST_TAG} | \
		grep browser_download_url | grep -E 'kafka-ui-api.*\.jar' | head -n1 | sed -E 's/.*"(https:[^"]+)".*/\1/')
	if [[ -z "${ASSET_URL}" ]]; then
		echo "Could not resolve Kafka UI jar download URL for ${LATEST_TAG}" >&2
		exit 1
	fi
	curl -fsSL "${ASSET_URL}" -o "${JAR_PATH}"
fi

# Create a minimal config file
cat > "${UI_HOME}/application.yaml" <<EOF
server:
  port: ${UI_PORT}

spring:
  application:
    name: kafka-ui

kafka:
  clusters:
    - name: workshop
      bootstrapServers: localhost:9092
      properties:
        security.protocol: PLAINTEXT
      metrics:
        enabled: false
EOF

# Create helper scripts
cat > "${UI_HOME}/start-ui.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
UI_HOME=${UI_HOME:-"${HOME}/kafka-ui"}
JAR_PATH="${UI_HOME}/kafka-ui-api.jar"
CFG="${UI_HOME}/application.yaml"
JAVA_OPTS=${JAVA_OPTS:-"-Xms256m -Xmx512m"}
if [[ ! -f "${JAR_PATH}" ]]; then echo "Kafka UI jar not found at ${JAR_PATH}" >&2; exit 1; fi
exec java ${JAVA_OPTS} -jar "${JAR_PATH}" --spring.config.location="${CFG}"
EOS

cat > "${UI_HOME}/start-ui-daemon.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
UI_HOME=${UI_HOME:-"${HOME}/kafka-ui"}
JAR_PATH="${UI_HOME}/kafka-ui-api.jar"
CFG="${UI_HOME}/application.yaml"
JAVA_OPTS=${JAVA_OPTS:-"-Xms256m -Xmx512m"}
if [[ ! -f "${JAR_PATH}" ]]; then echo "Kafka UI jar not found at ${JAR_PATH}" >&2; exit 1; fi
nohup java ${JAVA_OPTS} -jar "${JAR_PATH}" --spring.config.location="${CFG}" > "${UI_HOME}/ui.log" 2>&1 &
echo $! > "${UI_HOME}/ui.pid"
echo "Kafka UI started (PID $(cat "${UI_HOME}/ui.pid"))"
EOS

cat > "${UI_HOME}/stop-ui.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
UI_HOME=${UI_HOME:-"${HOME}/kafka-ui"}
if [[ -f "${UI_HOME}/ui.pid" ]]; then
	kill "$(cat "${UI_HOME}/ui.pid")" || true
	rm -f "${UI_HOME}/ui.pid"
	echo "Kafka UI stopped"
else
	echo "Kafka UI PID file not found; attempting to stop by port"
	if command -v pkill >/dev/null 2>&1; then pkill -f kafka-ui-api.jar || true; fi
fi
EOS

chmod +x "${UI_HOME}/"*.sh

echo "Kafka UI installed at ${UI_HOME}. Use ${UI_HOME}/start-ui.sh or start-ui-daemon.sh to run."
