#================================================================================
# Stage 1: Builder Stage
#===============================================================================
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG SSH_PORT=2222
ARG DEV_USER=devuser
ARG PUBKEY_CONTENT

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        vim \
        nano \
        python3 \
        python3-pip \
        python3-venv \
        curl \
        gnupg2 \
        lsb-release \
        ca-certificates \
        iproute2 \
        build-essential \
        pkg-config \
        cmake \
        git \
        zip \
        rustc \
        cargo \
        clang \
        libclang-dev \
        libssl-dev \
        libcurl4-openssl-dev \
        libxml2-dev \
        zlib1g-dev \
        libpq-dev \
        libbz2-dev \
        libffi-dev \
        libreadline-dev \
        libsqlite3-dev \
        liblzma-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libgdbm-dev \
        libnss3-dev \
        tk-dev \
        gettext \
        unzip \
        software-properties-common \
        php \
        php-cli \
        php-mbstring \
        php-xml \
        php-curl \
        php-zip \
        php-mysql \
        php-pgsql \
        apache2 \
        libapache2-mod-php \
        ruby \
        ruby-dev \
        bundler \
        wget \
        jq \
        default-jdk \
        default-jre \
        fonts-liberation \
        gawk \
        make \
        doxygen \
        graphviz \
        imagemagick \
        wkhtmltopdf \
        libmagic-dev \
        autoconf \
        automake \
        libc-dev \
        libtool \
        libxslt-dev \
        libsodium-dev \
        libuv1-dev \
        libwebp-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libavif-dev \
        libheif-dev && \
    rm -rf /var/lib/apt/lists/*

# Add privilege separation user for sshd
RUN adduser --system --no-create-home --shell /usr/sbin/nologin --group --disabled-password sshd

# Install Ansible and Terraform
RUN add-apt-repository --yes ppa:ansible/ansible && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y ansible terraform && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js, npm, and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

# Create non-root devuser with passwordless sudo
RUN useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG sudo "$DEV_USER" && \
    echo "$DEV_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$DEV_USER" && \
    chmod 440 /etc/sudoers.d/"$DEV_USER"

# Prepare SSH host keys and directories
RUN mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd
RUN rm -f /etc/ssh/ssh_host_ed25519_key && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q

# Harden SSH configuration
RUN sed -i \
    -e "s/#Port 22/Port $SSH_PORT/" \
    -e "s/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/" \
    -e 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' \
    -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' \
    -e 's/#PubkeyAcceptedKeyTypes.*$/PubkeyAcceptedKeyTypes ssh-ed25519/' \
    -e 's/#HostKeyAcceptedAlgorithms.*$/HostKeyAcceptedAlgorithms ssh-ed25519/' \
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
    chmod 600 /etc/ssh/ssh_host_ed25519_key && \
    chown root:root /etc/ssh/ssh_host_ed25519_key

# Add devuser's SSH authorized key
RUN mkdir -p /home/"$DEV_USER"/.ssh && \
    echo "$PUBKEY_CONTENT" > /home/"$DEV_USER"/.ssh/authorized_keys && \
    chmod 700 /home/"$DEV_USER"/.ssh && \
    chown -R "$DEV_USER":"$DEV_USER" /home/"$DEV_USER" && \
    cp /tmp/docker_ed25519.pub /home/"$DEV_USER"/.ssh/authorized_keys && \
    rm /tmp/docker_ed25519.pub && \
    chmod 600 /home/"$DEV_USER"/.ssh/authorized_keys && \
    chown "$DEV_USER":"$DEV_USER" /home/"$DEV_USER"/.ssh/authorized_keys

WORKDIR /home/"$DEV_USER"

# Remove unnecessary packages to reduce final size
RUN apt-get remove -y build-essential pkg-config && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

#===============================================================================
# Stage 2: Final Minimal Runtime Image
#===============================================================================
FROM scratch
COPY --from=builder / /

EXPOSE 2222/tcp

USER root
WORKDIR /home/$DEV_USER
CMD ["/usr/sbin/sshd", "-D", "-e"]
