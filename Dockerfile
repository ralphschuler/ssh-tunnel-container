FROM alpine:3.22

# Install minimal packages: bash for scripting, openssh-client for SSH, and yq for YAML parsing
RUN apk add --no-cache \
    bash \
    openssh-client \
    yq

WORKDIR /app

# Copy the entrypoint script into the image
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Default location of the configuration file (can be overridden with ENV)
ENV CONFIG_PATH=/config/config.yml

ENTRYPOINT ["/app/entrypoint.sh"]
