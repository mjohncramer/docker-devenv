#!/bin/bash

# Name of the Docker Compose service
SERVICE_NAME="devenv"

echo "=== Cleaning up Docker Compose resources ==="
# Stop and remove Docker Compose services
docker compose down --volumes --remove-orphans

echo "=== Cleaning up standalone Docker resources ==="
# Stop all running containers
echo "Stopping all running Docker containers..."
docker ps -q | xargs -r docker stop

# Remove all containers
echo "Removing all Docker containers..."
docker ps -aq | xargs -r docker rm -f

# Remove all images, including intermediate stages
echo "Removing all Docker images, including intermediate stages..."
docker images -q | xargs -r docker rmi -f

# Remove dangling images and intermediate build containers
echo "Removing dangling images and intermediate build containers..."
docker image prune -f
docker builder prune -f --all

# Remove all unused volumes
echo "Removing all Docker volumes..."
docker volume prune -f

# Remove all custom networks (excluding default networks: bridge, host, none)
echo "Removing all custom Docker networks..."
docker network ls --format "{{.ID}} {{.Name}}" | grep -vE "bridge|host|none" | awk '{print $1}' | xargs -r docker network rm

# Prune all unused Docker resources
echo "Pruning unused Docker resources..."
docker system prune -a --volumes -f

echo "=== Cleaning up SSH known_hosts entry ==="
# Remove old SSH key for the container from known_hosts
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
if [ -f "$KNOWN_HOSTS_FILE" ]; then
  echo "Removing old SSH host keys for localhost:2222 from $KNOWN_HOSTS_FILE..."
  ssh-keygen -f "$KNOWN_HOSTS_FILE" -R "[localhost]:2222"
fi

echo "=== Cleaning up workspace directory (if exists) ==="
# Remove workspace directory if specified
WORKSPACE_DIR="/var/lib/docker/rootless-data/workspace"
if [ -d "$WORKSPACE_DIR" ]; then
  echo "Removing workspace directory: $WORKSPACE_DIR..."
  rm -rf "$WORKSPACE_DIR"
fi

echo "=== Resetting Docker Buildx cache ==="
# Clean up Docker Buildx cache
docker buildx prune -f --all

echo "Docker environment reset is complete!"
