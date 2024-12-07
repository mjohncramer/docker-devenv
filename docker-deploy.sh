#!/bin/bash

set -e

# Constants
SERVICE_NAME="devenv"
SSH_PORT=2222
DEV_USER="devuser"
SSH_KEY="$HOME/.ssh/ed25519_docker"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"

# Check if the SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key $SSH_KEY not found."
    exit 1
fi

# Step 1: Build and start the container
echo "=== Building and starting the Docker Compose service ==="
docker compose up -d --build

# Step 2: Wait for the service to become healthy
echo "=== Waiting for the SSH service to become healthy ==="
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$SERVICE_NAME")" == "healthy" ]; do
    sleep 5
done

# Step 3: Retrieve the public host key from the container
echo "=== Retrieving SSH host key from the container ==="
HOST_KEY=$(docker exec "$SERVICE_NAME" ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub | awk '{print $2}')
if [ -z "$HOST_KEY" ]; then
    echo "Error: Failed to retrieve host key from container"
    exit 1
fi

# Step 4: Add the host key to known_hosts
echo "=== Adding host key to $KNOWN_HOSTS_FILE ==="
ssh-keygen -R "[localhost]:${SSH_PORT}" -f "$KNOWN_HOSTS_FILE" 2>/dev/null || true
ssh-keyscan -p "$SSH_PORT" localhost >> "$KNOWN_HOSTS_FILE" 2>/dev/null

# Step 5: Test SSH connection
echo "=== Testing SSH connection ==="
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" "$DEV_USER"@localhost exit

if [ $? -ne 0 ]; then
    echo "Error: SSH connection failed"
    exit 1
fi

echo "=== Deployment complete! You can now SSH into the container using: ==="
echo "ssh -i ~/.ssh/ed25519_docker -p $SSH_PORT $DEV_USER@localhost"
