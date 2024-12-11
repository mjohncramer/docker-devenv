#!/usr/bin/env bash

set -euo pipefail

# Variables
SERVICE_NAME="devenv"
SSH_PORT=2222
DEV_USER="devuser"
SSH_KEY="$HOME/.ssh/docker_ed25519"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"

# Functions
command_exists() {
    command -v "$1" &>/dev/null
}

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

check_prerequisites() {
    # Check required commands
    for cmd in docker ssh-keygen ssh-keyscan; do
        command_exists "$cmd" || error_exit "Required command '$cmd' not found."
    done

    # Ensure SSH key exists
    if [ ! -f "$SSH_KEY" ]; then
        error_exit "SSH key $SSH_KEY not found. Please generate it with: ssh-keygen -t ed25519 -f $SSH_KEY -N ''"
    fi

    # Ensure known_hosts file exists with proper permissions
    if [ ! -f "$KNOWN_HOSTS_FILE" ]; then
        touch "$KNOWN_HOSTS_FILE"
        chmod 600 "$KNOWN_HOSTS_FILE"
    fi
}

start_services() {
    echo "=== Building and starting the Docker Compose service ==="
    docker compose build --no-cache || error_exit "Docker build failed."
    docker compose up -d || error_exit "Docker compose up failed."

    # Wait for the container to actually start
    echo "=== Waiting for the container to start running ==="
    local state
    until state=$(docker inspect -f '{{.State.Running}}' "$SERVICE_NAME" 2>/dev/null) && [ "$state" = "true" ]; do
        sleep 2
    done
}

wait_for_health() {
    echo "=== Waiting for the SSH service to become healthy ==="
    until [ "$(docker inspect -f '{{.State.Health.Status}}' "$SERVICE_NAME")" = "healthy" ]; do
        sleep 5
    done
}

update_known_hosts() {
    echo "=== Updating $KNOWN_HOSTS_FILE with container host key ==="
    # Remove old entry if exists
    ssh-keygen -R "[localhost]:${SSH_PORT}" -f "$KNOWN_HOSTS_FILE" 2>/dev/null || true
    # Hash hostnames and add the key
    ssh-keyscan -p "$SSH_PORT" -H localhost >> "$KNOWN_HOSTS_FILE" 2>/dev/null || error_exit "Failed to retrieve SSH host key."
    chmod 600 "$KNOWN_HOSTS_FILE"
}

test_ssh_connection() {
    echo "=== Testing SSH connection ==="
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=yes -p "$SSH_PORT" "$DEV_USER"@localhost exit || error_exit "SSH connection test failed."
}

print_success_message() {
    echo "=== Deployment complete! You can now SSH into the container using: ==="
    echo "========= ssh -i $SSH_KEY -p $SSH_PORT $DEV_USER@localhost ========="
}

# Main Execution

check_prerequisites
start_services
wait_for_health
update_known_hosts
test_ssh_connection
print_success_message
