# Kafka Workshop (GitHub Codespaces)

This Codespace installs the latest stable Apache Kafka 4.x into `~/kafka` and configures single-node KRaft mode (no ZooKeeper). Kafka does not auto-start; you start it explicitly.

## Prerequisites
- Use GitHub Codespaces for this repository.
- Prebuilds are recommended (Repo → Settings → Codespaces → Prebuilds) so setup runs ahead of time.

## First run
When your Codespace opens, containers run the setup automatically (without starting Kafka). Kafka is installed to `/home/vscode/kafka` and configured for KRaft.

## Start/Stop Kafka
- Start (foreground, shows logs):
  ```bash
  .devcontainer/scripts/start-kafka.sh
  ```
- Start (background/daemon):
  ```bash
  .devcontainer/scripts/start-kafka-daemon.sh
  ```
- Status:
  ```bash
  .devcontainer/scripts/status-kafka.sh
  ```
- Stop:
  ```bash
  .devcontainer/scripts/stop-kafka.sh
  ```
- Reset state (stop, wipe data, reformat):
  ```bash
  .devcontainer/scripts/reset-kafka.sh
  ```

Kafka CLI tools (e.g., `kafka-topics.sh`, `kafka-console-producer.sh`) are in `~/kafka/bin` and added to PATH.

## Example commands
- Create a topic:
  ```bash
  kafka-topics.sh --bootstrap-server localhost:9092 --create --topic demo --partitions 1 --replication-factor 1
  ```
- Produce messages:
  ```bash
  kafka-console-producer.sh --bootstrap-server localhost:9092 --topic demo
  ```
- Consume messages:
  ```bash
  kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic demo --from-beginning
  ```

## Notes
- Internal access only: `advertised.listeners=PLAINTEXT://localhost:9092`. External clients are not supported.
- Java 17 is installed via Dev Containers Feature.
- Heap size is dynamic (~80% of available memory by default). Override with env vars `KAFKA_HEAP_MB` or `KAFKA_HEAP_FRACTION` before starting.
- To pin Kafka to a specific version, set `KAFKA_VERSION` env in `.devcontainer/scripts/setup-kafka.sh` or in the Codespace environment and rebuild the container.
