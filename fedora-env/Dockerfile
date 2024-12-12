#===============================================================================
# Stage 1: Builder Stage (Fedora)
#===============================================================================
FROM fedora:latest AS builder

ARG SSH_PORT=2222
ARG DEV_USER=devuser
ARG PUBKEY_CONTENT

# Install packages needed for building & runtime using tmpfs
RUN --mount=type=tmpfs,target=/tmp \
    dnf -y update && \
    dnf -y install --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
        openssh-server \
        sudo \
        vim nano \
        python3 python3-pip python3-virtualenv \
        curl gnupg2 ca-certificates iproute \
        gcc gcc-c++ make cmake git zip \
        rust cargo clang clang-devel \
        openssl-devel libcurl-devel libxml2-devel zlib-devel \
        postgresql-devel bzip2-devel libffi-devel readline-devel \
        sqlite-devel xz-devel ncurses-devel gdbm-devel nss-devel tk-devel gettext unzip \
        ruby ruby-devel rubygems redhat-rpm-config wget jq && \
    dnf clean all && rm -rf /var/cache/dnf

# Set up SSH, user, and authorized keys
RUN mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd && \
    useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG wheel "$DEV_USER" && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel && \
    chmod 440 /etc/sudoers.d/wheel && \
    passwd -d "$DEV_USER" && \
    rm -f /etc/ssh/ssh_host_ed25519_key && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q

# Harden SSH configuration
RUN sed -i \
    -e "s/#Port 22/Port $SSH_PORT/" \
    -e 's/#PermitRootLogin yes/PermitRootLogin no/' \
    -e 's/PasswordAuthentication yes/PasswordAuthentication no/' \
    -e 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' \
    -e 's/ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' \
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

WORKDIR /home/$DEV_USER
RUN mkdir -p /home/$DEV_USER/.ssh && \
    echo "$PUBKEY_CONTENT" > /home/$DEV_USER/.ssh/authorized_keys && \
    chmod 700 /home/$DEV_USER/.ssh && \
    chmod 600 /home/$DEV_USER/.ssh/authorized_keys && \
    chown -R "$DEV_USER":"$DEV_USER" /home/$DEV_USER/.ssh

# Remove build tools not needed at runtime (if desired)
# For example, remove cmake, gcc, etc. if runtime doesn't need them:
RUN --mount=type=tmpfs,target=/tmp \
    dnf -y remove gcc gcc-c++ cmake clang-devel postgresql-devel bzip2-devel libffi-devel \
                  readline-devel sqlite-devel xz-devel ncurses-devel gdbm-devel nss-devel tk-devel gettext && \
    dnf clean all && rm -rf /var/cache/dnf

# Builder stage ends here with a lean set of runtime tools (rust, cargo, python, ruby, etc.)

#===============================================================================
# Stage 2: Runtime Stage (Fedora)
#===============================================================================
FROM fedora:latest

ARG SSH_PORT=2222
ARG DEV_USER=devuser

# Minimal runtime setup
RUN --mount=type=tmpfs,target=/tmp \
    dnf -y update && \
    dnf -y install --setopt=install_weak_deps=False --setopt=tsflags=nodocs \
        openssh-server \
        sudo \
        vim nano \
        python3 python3-pip python3-virtualenv \
        curl ca-certificates git rust cargo ruby wget jq && \
    dnf clean all && rm -rf /var/cache/dnf

# Create user and setup sshd directories, no keys generated here
RUN mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd && \
    useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG wheel "$DEV_USER" && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel && \
    chmod 440 /etc/sudoers.d/wheel && \
    passwd -d "$DEV_USER"

# Copy SSH configuration and keys from builder
COPY --from=builder /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
COPY --from=builder /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
COPY --from=builder /etc/ssh/sshd_config /etc/ssh/sshd_config
COPY --from=builder /home/$DEV_USER/.ssh /home/$DEV_USER/.ssh
RUN chown -R "$DEV_USER":"$DEV_USER" /home/$DEV_USER/.ssh

EXPOSE 2222/tcp
CMD ["/usr/sbin/sshd", "-D", "-e"]
