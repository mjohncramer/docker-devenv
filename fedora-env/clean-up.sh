#!/bin/bash

USER=$(whoami)

echo "=== Cleaning up Docker Compose resources ==="
# Stop and remove Docker Compose services
docker compose down --volumes --remove-orphans

echo "=== Cleaning up standalone Docker containers ==="
# Stop all running containers
echo "Stopping all running Docker containers..."
docker ps -q | xargs -r docker stop

# Remove all containers
echo "Removing all Docker containers..."
docker ps -aq | xargs -r docker rm -f

echo "=== Cleaning up Docker images related to containers ==="
# Remove dangling images and intermediate stages
echo "Removing dangling images and intermediate build containers..."
docker image prune -f

# Remove all container-related images
echo "Removing all container-related images..."
docker images -q | xargs -r docker rmi -f

echo "=== Cleaning up all Docker volumes ==="
# Remove all volumes, including named volumes
echo "Removing all Docker volumes, including named ones..."
docker volume ls -q | xargs -r docker volume rm -f

echo "=== Cleaning up custom Docker networks ==="
# Remove all custom networks (excluding default: bridge, host, none)
echo "Removing custom Docker networks..."
docker network ls --format "{{.ID}} {{.Name}}" | grep -vE "bridge|host|none" | awk '{print $1}' | xargs -r docker network rm

echo "=== Pruning build cache ==="
# Reset Docker Buildx cache
docker buildx prune -f --all

echo "=== Cleaning up SSH known_hosts entry ==="
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
if [ -f "$KNOWN_HOSTS_FILE" ]; then
  echo "Removing old SSH host keys for localhost:2222 from $KNOWN_HOSTS_FILE..."
  ssh-keygen -f "$KNOWN_HOSTS_FILE" -R "[localhost]:2222"
fi

echo "=== Cleaning up workspace directory (if exists) ==="
WORKSPACE_DIR="/var/lib/docker/rootless-data/workspace"
if [ -d "$WORKSPACE_DIR" ]; then
  echo "Removing contents of workspace directory: $WORKSPACE_DIR..."
  rm -rf "$WORKSPACE_DIR"/*
fi

echo "=== Cleaning up container-related Builder instances ==="
# Remove non-default Docker Buildx instances
docker buildx ls | awk '/^[^NAME]/ {next} {print $1}' | grep -v default | xargs -r docker buildx rm || true

echo "=== Cleaning up remaining container-related artifacts ==="
echo "Logging out from all Docker registries..."
docker logout

echo "=== Verifying complete cleanup ==="
echo "Remaining containers:"
docker ps -a

echo "Remaining images:"
docker images

echo "Remaining volumes:"
docker volume ls

echo "Remaining networks:"
docker network ls

echo "Container environment reset is complete!"
