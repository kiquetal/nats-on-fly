FROM nats:2.10.25-alpine

# Expose client, management, and routing ports
EXPOSE 4222 8222 6222

# Default entrypoint is already "nats-server"
CMD ["-js"]
