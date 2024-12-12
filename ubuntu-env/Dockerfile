#===============================================================================
# Stage 1: Builder Stage (Ubuntu)
#===============================================================================
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG SSH_PORT=2222
ARG DEV_USER=devuser
ARG PUBKEY_CONTENT

# Use tmpfs for package operations
RUN --mount=type=tmpfs,target=/tmp apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    vim nano \
    python3 python3-pip python3-venv \
    curl gnupg2 ca-certificates \
    iproute2 \
    build-essential pkg-config cmake \
    git zip rustc cargo clang libclang-dev \
    libssl-dev libcurl4-openssl-dev libxml2-dev zlib1g-dev libpq-dev \
    libbz2-dev libffi-dev libreadline-dev libsqlite3-dev liblzma-dev \
    libncurses5-dev libncursesw5-dev libgdbm-dev libnss3-dev tk-dev \
    gettext unzip ruby ruby-dev bundler wget jq gawk make autoconf automake \
    libc-dev libtool libxslt-dev && \
    rm -rf /var/lib/apt/lists/*

# SSH and user
RUN adduser --system --no-create-home --shell /usr/sbin/nologin --group --disabled-password sshd && \
    useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG sudo "$DEV_USER" && \
    echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$DEV_USER" && \
    chmod 440 /etc/sudoers.d/"$DEV_USER" && \
    mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd && \
    rm -f /etc/ssh/ssh_host_ed25519_key && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q

RUN sed -i \
    -e "s/#Port 22/Port $SSH_PORT/" \
    -e "s/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/" \
    -e 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' \
    -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' \
    -e 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' \
    -e 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' \
    -e 's/#UsePAM yes/UsePAM yes/' \
    -e 's/#X11Forwarding yes/X11Forwarding no/' \
    -e 's/#PrintMotd yes/PrintMotd no/' \
    -e 's/#UseDNS yes/UseDNS no/' \
    -e 's/#Ciphers.*$/Ciphers aes256-ctr,chacha20-poly1305@openssh.com/' \
    -e 's/#KexAlgorithms.*$/KexAlgorithms curve25519-sha256@libssh.org/' \
    -e 's/#MACs.*$/MACs hmac-sha2-512-etm@openssh.com/' \
    /etc/ssh/sshd_config && \
    echo "AllowUsers $DEV_USER" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 0" >> /etc/ssh/sshd_config && \
    echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config && \
    echo "MaxAuthTries 3" >> /etc/ssh/sshd_config && \
    chmod 600 /etc/ssh/ssh_host_ed25519_key && chown root:root /etc/ssh/ssh_host_ed25519_key

WORKDIR /home/"$DEV_USER"
RUN mkdir -p /home/"$DEV_USER"/.ssh && \
    echo "$PUBKEY_CONTENT" > /home/"$DEV_USER"/.ssh/authorized_keys && \
    chmod 700 /home/"$DEV_USER"/.ssh && \
    chmod 600 /home/"$DEV_USER"/.ssh/authorized_keys && \
    chown -R "$DEV_USER":"$DEV_USER" /home/"$DEV_USER"/.ssh

# Remove build tools not needed at runtime
RUN --mount=type=tmpfs,target=/tmp apt-get update && apt-get remove -y build-essential pkg-config cmake autoconf automake libtool && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

#===============================================================================
# Stage 2: Runtime Stage (Ubuntu)
#===============================================================================
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ARG SSH_PORT=2222
ARG DEV_USER=devuser

# Minimal runtime environment
RUN --mount=type=tmpfs,target=/tmp apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    vim nano \
    python3 python3-pip python3-venv \
    curl ca-certificates git rustc cargo ruby wget jq gawk \
    && rm -rf /var/lib/apt/lists/*

# Create user and sshd runtime setup
RUN adduser --system --no-create-home --shell /usr/sbin/nologin --group --disabled-password sshd && \
    useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG sudo "$DEV_USER" && \
    echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$DEV_USER" && \
    chmod 440 /etc/sudoers.d/"$DEV_USER" && \
    mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd

# Copy SSH keys and config from builder
COPY --from=builder /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
COPY --from=builder /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
COPY --from=builder /etc/ssh/sshd_config /etc/ssh/sshd_config
COPY --from=builder /home/$DEV_USER/.ssh /home/$DEV_USER/.ssh
RUN chown -R "$DEV_USER":"$DEV_USER" /home/$DEV_USER/.ssh

EXPOSE 2222/tcp
CMD ["/usr/sbin/sshd", "-D", "-e"]
