#===============================================================================
# Stage 1: Builder Stage for Fedora
#===============================================================================
FROM fedora:latest AS builder

ARG SSH_PORT=2222
ARG DEV_USER=devuser
ARG PUBKEY_CONTENT

#ENV LANG=en_US.UTF-8
#ENV LC_ALL=en_US.UTF-8

# Update and install packages
RUN dnf -y update && \
    dnf -y install \
        openssh-server \
        sudo \
        vim \
        nano \
        python3 \
        python3-pip \
        python3-virtualenv \
        curl \
        gnupg2 \
        ca-certificates \
        iproute \
        gcc \
        gcc-c++ \
        make \
        cmake \
        git \
        zip \
        rust \
        cargo \
        clang \
        clang-devel \
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
        php-fpm \
        ruby \
        ruby-devel \
        rubygems \
        redhat-rpm-config \
        wget \
        jq \
        java-11-openjdk \
        java-11-openjdk-devel \
        liberation-fonts \
        gawk \
        doxygen \
        graphviz \
        ImageMagick \
        wkhtmltopdf \
        file-devel \
        autoconf \
        automake \
        glibc-devel \
        libtool \
        libxslt-devel \
        libsodium-devel \
        libuv-devel \
        libwebp-devel \
        libjpeg-turbo-devel \
        libpng-devel \
        libtiff-devel \
        libavif-devel \
        libheif-devel \
        dnf-plugins-core && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Set up SSH
RUN mkdir -p /var/run/sshd && chmod 0755 /var/run/sshd

# Create dev user with sudo privileges
RUN useradd -ms /bin/bash "$DEV_USER" && \
    usermod -aG wheel "$DEV_USER" && \
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel && \
    chmod 440 /etc/sudoers.d/wheel && \
    passwd -d "$DEV_USER"

# SSH Host key
RUN rm -f /etc/ssh/ssh_host_ed25519_key && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' -q

# Harden SSH configuration
RUN sed -i \
    -e "s/#Port 22/Port $SSH_PORT/" \
    -e "s/#HostKey \/etc\/ssh\/ssh_host_ed25519_key/HostKey \/etc\/ssh\/ssh_host_ed25519_key/" \
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

# Terraform & Ansible for Fedora
#RUN dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo && \
#    dnf -y install terraform ansible && \
#    dnf clean all && \
#    rm -rf /var/cache/dnf

# Node.js, npm, yarn
#RUN dnf -y module enable nodejs && \
#    dnf -y install nodejs && \
#    npm install -g yarn && \
#    dnf clean all && \
#    rm -rf /var/cache/dnf

WORKDIR /home/"$DEV_USER"

# Inject the public key from the build arg into authorized_keys
RUN mkdir -p /home/"$DEV_USER"/.ssh && \
    echo "$PUBKEY_CONTENT" > /home/"$DEV_USER"/.ssh/authorized_keys && \
    chmod 700 /home/"$DEV_USER"/.ssh && \
    chmod 600 /home/"$DEV_USER"/.ssh/authorized_keys && \
    chown -R "$DEV_USER":"$DEV_USER" /home/"$DEV_USER"/.ssh

#===============================================================================
# Stage 2: Final Image
#===============================================================================
FROM scratch
COPY --from=builder / /

# Expose the SSH port (fixed)
EXPOSE 2222/tcp

USER root
WORKDIR /home/$DEV_USER
CMD ["/usr/sbin/sshd", "-D", "-e"]
