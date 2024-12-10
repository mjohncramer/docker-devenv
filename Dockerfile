# Stage 1: Builder Stage
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG SSH_PORT=2222
ARG DEV_USER=devuser

# Use a tmpfs mount for improved performance during apt operations
RUN --mount=type=tmpfs,target=/tmp,size=5120m \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        vim \
        python3 \
        python3-pip \
        curl \
        gnupg2 \
        lsb-release \
        ca-certificates \
        iproute2 \
        build-essential \
        pkg-config \
        zip \
        unzip \
        software-properties-common && \
    rm -rf /var/lib/apt/lists/*

# Create the sshd user for privilege separation
RUN adduser --system --no-create-home --shell /usr/sbin/nologin --group --disabled-password sshd

# Install Ansible and Terraform
RUN --mount=type=tmpfs,target=/tmp,size=1000m \
    add-apt-repository --yes ppa:ansible/ansible && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y ansible terraform && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user for development
RUN useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG sudo "$DEV_USER" && \
    echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$DEV_USER" && \
    chmod 440 /etc/sudoers.d/"$DEV_USER"

# Prepare SSH directories and keys
RUN mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd
RUN rm -f /etc/ssh/ssh_host_ed25519_key && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q

# Harden SSH Configuration
RUN sed -i \
    -e "s/#Port 22/Port $SSH_PORT/" \
    -e "s/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/" \
    -e 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' \
    -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' \
    -e 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' \
    -e 's/#UsePAM yes/UsePAM yes/' \
    -e 's/#X11Forwarding yes/X11Forwarding no/' \
    -e 's/#PrintMotd yes/PrintMotd no/' \
    -e 's/#UseDNS yes/UseDNS no/' \
    /etc/ssh/sshd_config && \
    echo "AllowUsers $DEV_USER" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 0" >> /etc/ssh/sshd_config && \
    echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config && \
    echo "MaxAuthTries 3" >> /etc/ssh/sshd_config && \
    echo "Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com" >> /etc/ssh/sshd_config && \
    echo "KexAlgorithms curve25519-sha256" >> /etc/ssh/sshd_config && \
    echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com" >> /etc/ssh/sshd_config

# Secure host key permissions
RUN chmod 600 /etc/ssh/ssh_host_ed25519_key && \
    chown root:root /etc/ssh/ssh_host_ed25519_key

# Add devuser's public key for SSH access
COPY docker_ed25519.pub /tmp/docker_ed25519.pub
RUN mkdir -p /home/"$DEV_USER"/.ssh && \
    chmod 700 /home/"$DEV_USER"/.ssh && \
    chown -R "$DEV_USER":"$DEV_USER" /home/"$DEV_USER" && \
    cp /tmp/docker_ed25519.pub /home/"$DEV_USER"/.ssh/authorized_keys && \
    rm /tmp/docker_ed25519.pub && \
    chmod 600 /home/"$DEV_USER"/.ssh/authorized_keys && \
    chown "$DEV_USER":"$DEV_USER" /home/"$DEV_USER"/.ssh/authorized_keys

WORKDIR /home/"$DEV_USER"

# Stage 2: Final Minimal Runtime Image
FROM ubuntu:24.04

ARG DEV_USER=devuser
ARG SSH_PORT=2222
ENV DEBIAN_FRONTEND=noninteractive

# Copy necessary files and directories from builder
COPY --from=builder /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
COPY --from=builder /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
COPY --from=builder /etc/ssh/sshd_config /etc/ssh/sshd_config
COPY --from=builder /usr/sbin/sshd /usr/sbin/sshd
COPY --from=builder /usr/bin/ansible /usr/bin/ansible
COPY --from=builder /usr/bin/terraform /usr/bin/terraform
COPY --from=builder /usr/bin/python3 /usr/bin/python3
COPY --from=builder /usr/bin/pip3 /usr/bin/pip3
COPY --from=builder /usr/lib/ /usr/lib/
COPY --from=builder /usr/share/ /usr/share/
COPY --from=builder /bin/ /bin/
COPY --from=builder /sbin/ /sbin/
COPY --from=builder /lib/ /lib/
COPY --from=builder /lib64/ /lib64/
COPY --from=builder /etc/sudoers.d/$DEV_USER /etc/sudoers.d/$DEV_USER
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /etc/shadow /etc/shadow
COPY --from=builder /etc/gshadow /etc/gshadow
COPY --from=builder /home/$DEV_USER /home/$DEV_USER
COPY --from=builder /var/run/sshd /var/run/sshd

EXPOSE $SSH_PORT/tcp

USER root
WORKDIR /home/$DEV_USER

# Run sshd in foreground
CMD ["/usr/sbin/sshd", "-D", "-e"]
