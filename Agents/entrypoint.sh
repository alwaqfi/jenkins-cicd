#!/bin/bash
set -e

# Start SSHD in the foreground
exec /usr/sbin/sshd -D

# Start Docker daemon in the background
dockerd > /var/log/dockerd.log 2>&1 &

# Wait for Docker to be ready
echo "Waiting for Docker daemon to start..."
timeout 30 bash -c 'until docker info > /dev/null 2>&1; do sleep 1; done'

