# Base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ARG SSH_PORT=2222
ARG DEV_USER=devuser

# Update and install necessary tools and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        vim \
        python3.10 \
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

# Install Ansible and Terraform securely
RUN add-apt-repository --yes ppa:ansible/ansible && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y ansible terraform && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user and set permissions
RUN useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG sudo "$DEV_USER" && \
    echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$DEV_USER" && \
    chmod 440 /etc/sudoers.d/"$DEV_USER"

# Set up SSH for the non-root user
RUN mkdir -p /home/"$DEV_USER"/.ssh && \
    chmod 700 /home/"$DEV_USER"/.ssh && \
    chown -R "$DEV_USER":"$DEV_USER" /home/"$DEV_USER"

# Copy the SSH public key
COPY --chown="$DEV_USER":"$DEV_USER" ed25519_docker.pub /home/"$DEV_USER"/.ssh/authorized_keys

# Set correct permissions for SSH directory and keys
RUN chmod 600 /home/"$DEV_USER"/.ssh/authorized_keys

# Configure SSH server with security enhancements
RUN mkdir /var/run/sshd && \
    chmod 0755 /var/run/sshd && \
    sed -i \
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
    echo "MaxAuthTries 3" >> /etc/ssh/sshd_config

# Generate host keys
RUN ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''

# Expose the SSH port
EXPOSE $SSH_PORT/tcp

# Switch to the non-root user
USER "$DEV_USER"

# Set the working directory
WORKDIR /home/"$DEV_USER"

# Start SSH server
CMD ["/usr/sbin/sshd", "-D", "-e"]
