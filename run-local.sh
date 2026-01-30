#!/bin/bash
echo "Building Docker image..."
docker build -t nats-local .

echo "Running NATS locally on port 4222 (Client) and 8222 (Monitor)..."
echo "JetStream is enabled (-js)."
docker run --rm -p 4222:4222 -p 8222:8222 nats-local
