#===============================================================================
# Stage 1: Builder Stage
#===============================================================================
FROM fedora:41 AS builder

# Set environment variables
ENV SSH_PORT=2222 \
    DEV_USER=devuser \
    DEBIAN_FRONTEND=noninteractive

# Update and install essential packages with minimal footprint
RUN dnf install -y --setopt=tsflags=nodocs --setopt=install_weak_deps=False \
        openssh-server \
        sudo \
        python3 \
        python3-pip \
        python3-virtualenv \
        curl \
        gnupg2 \
        lsb-release \
        ca-certificates \
        iproute \
        gcc \
        cmake \
        git \
        rust \
        cargo \
        clang \
        openssl-devel \
        libcurl-devel \
        libxml2-devel \
        zlib-devel \
        postgresql-devel \
        bzip2-devel \
        libffi-devel \
        readline-devel \
        sqlite-devel \
        xz-devel \
        ncurses-devel \
        gdbm-devel \
        nss-devel \
        tk-devel \
        gettext \
        unzip \
        php \
        php-cli \
        php-mbstring \
        php-xml \
        php-curl \
        php-zip \
        php-mysqlnd \
        php-pgsql \
        httpd \
        ruby \
        ruby-devel \
        rubygem-bundler \
        wget \
        jq \
        java-17-openjdk \
        java-17-openjdk-devel \
        liberation-fonts \
        make \
        doxygen \
        graphviz \
        ImageMagick \
        libtool \
        libsodium-devel \
        libuv-devel \
        libwebp-devel \
        libjpeg-turbo-devel \
        libpng-devel \
        libtiff-devel \
        libavif-devel \
        libheif-devel && \
    dnf clean all

# Add privilege separation user for SSHD
RUN useradd --system --no-create-home --shell /usr/sbin/nologin sshd

# Create a non-root developer user with passwordless sudo
RUN useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG wheel "$DEV_USER" && \
    echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$DEV_USER" && \
    chmod 440 /etc/sudoers.d/"$DEV_USER"

# Harden SSH configuration
RUN mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' && \
    sed -i \
    -e "s/#Port 22/Port $SSH_PORT/" \
    -e "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" \
    -e "s/#PasswordAuthentication yes/PasswordAuthentication no/" \
    -e "s/#PubkeyAuthentication yes/PubkeyAuthentication yes/" \
    -e "s/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/" \
    -e "s/#UseDNS yes/UseDNS no/" \
    -e "s/#X11Forwarding yes/X11Forwarding no/" \
    -e "s/#PrintMotd yes/PrintMotd no/" \
    -e "s/#Ciphers.*$/Ciphers aes256-ctr,chacha20-poly1305@openssh.com/" \
    -e "s/#KexAlgorithms.*$/KexAlgorithms curve25519-sha256@libssh.org/" \
    -e "s/#MACs.*$/MACs hmac-sha2-512-etm@openssh.com/" \
    /etc/ssh/sshd_config && \
    echo "AllowUsers $DEV_USER" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 0" >> /etc/ssh/sshd_config && \
    echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config

# Add devuser's SSH authorized key
COPY docker_ed25519.pub /tmp/docker_ed25519.pub
RUN mkdir -p /home/"$DEV_USER"/.ssh && \
    chmod 700 /home/"$DEV_USER"/.ssh && \
    cp /tmp/docker_ed25519.pub /home/"$DEV_USER"/.ssh/authorized_keys && \
    chmod 600 /home/"$DEV_USER"/.ssh/authorized_keys && \
    chown -R "$DEV_USER":"$DEV_USER" /home/"$DEV_USER"/.ssh && \
    rm /tmp/docker_ed25519.pub

# Optimize image size by cleaning up development tools
RUN dnf remove -y gcc cmake && \
    dnf autoremove -y && \
    dnf clean all

WORKDIR /home/"$DEV_USER"
USER "$DEV_USER"

#===============================================================================
# Stage 2: Minimal Runtime Image
#===============================================================================
FROM scratch

# Copy the prepared filesystem from the builder stage
COPY --from=builder / /

# Set runtime environment
WORKDIR /home/$DEV_USER
USER $DEV_USER

# Expose the SSH port and define the final command
EXPOSE $SSH_PORT/tcp
CMD ["/usr/sbin/sshd", "-D", "-e"]
