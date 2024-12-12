#!/usr/bin/env bash

set -euo pipefail

DEV_USER="devuser"
SSH_KEY="$HOME/.ssh/docker_ed25519"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"

ENVIRON=${1:-}

if [ -z "$ENVIRON" ]; then
    echo "Which environment would you like to deploy? (ubuntu/fedora)"
    read -r ENVIRON
fi

if [[ "$ENVIRON" != "ubuntu" && "$ENVIRON" != "fedora" ]]; then
    echo "Invalid environment. Must be 'ubuntu' or 'fedora'."
    exit 1
fi

if [ "$ENVIRON" = "ubuntu" ]; then
    COMPOSE_FILE="ubuntu-env/docker-compose.yml"
    PROJECT_NAME="ubuntu"
    HOST_SSH_PORT=2222
elif [ "$ENVIRON" = "fedora" ]; then
    COMPOSE_FILE="fedora-env/docker-compose.yml"
    PROJECT_NAME="fedora"
    HOST_SSH_PORT=2223
fi

command_exists() {
    command -v "$1" &>/dev/null
}

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

check_prerequisites() {
    for cmd in docker ssh-keygen ssh-keyscan; do
        command_exists "$cmd" || error_exit "Required command '$cmd' not found."
    done

    # Check SSH key pair
    if [ ! -f "$SSH_KEY" ]; then
        error_exit "SSH private key $SSH_KEY not found. Please generate it with: ssh-keygen -t ed25519 -f $SSH_KEY -N ''"
    fi

    if [ ! -f "$SSH_KEY.pub" ]; then
        error_exit "SSH public key $SSH_KEY.pub not found. Please ensure you have a public key."
    fi

    # Prepare known_hosts
    if [ ! -f "$KNOWN_HOSTS_FILE" ]; then
        touch "$KNOWN_HOSTS_FILE"
        chmod 600 "$KNOWN_HOSTS_FILE"
    fi
}

start_services() {
    # Extract the public key content
    PUBKEY_CONTENT=$(cat "$SSH_KEY.pub")

    echo "=== Building and starting the Docker Compose service for $ENVIRON ==="
    SSH_PORT=2222 DEV_USER="$DEV_USER" HOST_SSH_PORT="$HOST_SSH_PORT" \
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build --no-cache \
        --build-arg PUBKEY_CONTENT="$PUBKEY_CONTENT" \
        || error_exit "Docker build failed."

    SSH_PORT=2222 DEV_USER="$DEV_USER" HOST_SSH_PORT="$HOST_SSH_PORT" \
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d \
        || error_exit "Docker compose up failed."

    echo "=== Waiting for the container to start running ==="
    CONTAINER_NAME=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q devenv)
    until state=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null) && [ "$state" = "true" ]; do
        sleep 2
    done
}

wait_for_health() {
    CONTAINER_NAME=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q devenv)
    echo "=== Waiting for the SSH service to become healthy ==="
    until [ "$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER_NAME")" = "healthy" ]; do
        sleep 5
    done
}

update_known_hosts() {
    echo "=== Updating $KNOWN_HOSTS_FILE with container host key for port $HOST_SSH_PORT ==="
    ssh-keygen -R "[localhost]:${HOST_SSH_PORT}" -f "$KNOWN_HOSTS_FILE" 2>/dev/null || true
    ssh-keyscan -p "$HOST_SSH_PORT" -H localhost >> "$KNOWN_HOSTS_FILE" 2>/dev/null || error_exit "Failed to retrieve SSH host key."
    chmod 600 "$KNOWN_HOSTS_FILE"
}

test_ssh_connection() {
    echo "=== Testing SSH connection to ${ENVIRON} environment at port ${HOST_SSH_PORT} ==="
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=yes -p "$HOST_SSH_PORT" "$DEV_USER"@localhost exit || error_exit "SSH connection test failed."
}

print_success_message() {
    echo "=== Deployment complete for $ENVIRON! ==="
    echo "To SSH into this environment:"
    echo "ssh -i $SSH_KEY -p $HOST_SSH_PORT $DEV_USER@localhost"
    echo
    echo "You can run the other environment (if not already) and SSH into it on its unique port."
    echo "Ubuntu runs on port 2222; Fedora runs on port 2223. Both can run simultaneously."
}

# Main Execution
check_prerequisites
start_services
wait_for_health
update_known_hosts
test_ssh_connection
print_success_message
