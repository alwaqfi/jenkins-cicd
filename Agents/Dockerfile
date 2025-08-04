FROM jenkins/ssh-agent:latest-jdk21

# Switch to root user
USER root

# **************************************************************************************************************************************
# Install Docker
# **************************************************************************************************************************************
ENV DOCKER_VERSION=24.0.7 \
    DOCKER_COMPOSE_VERSION=2.24.5 \
    DOCKER_TLS_CERTDIR=""

# Install Docker and required tools
RUN apt-get update && \
    apt-get install -y \
        curl \
        iptables \
        ca-certificates \
        fuse-overlayfs \
        uidmap \
        wget \
        unzip \
        pigz \
        gnupg \
        lsb-release \
        openssh-server \
        supervisor \
        socat && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli && \
    curl -SL "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN usermod -aG docker jenkins

RUN mkdir -p /var/log/supervisor

RUN systemctl enable docker.service

RUN systemctl enable containerd.service

# Ensure SSH directory exists and generate host keys
RUN mkdir -p /var/run/sshd && \
    ssh-keygen -A

# Docker needs this directory
RUN mkdir /var/lib/docker


# **************************************************************************************************************************************
# Install .Net 9
# **************************************************************************************************************************************
RUN wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN rm packages-microsoft-prod.deb
RUN apt-get update -y && apt-get install -y dotnet-sdk-9.0

# **************************************************************************************************************************************
# Install NodeJs 22
# **************************************************************************************************************************************
RUN curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh
RUN bash nodesource_setup.sh
RUN apt-get install -y nodejs
RUN node -v

# **************************************************************************************************************************************
# Install AWS CLI
# **************************************************************************************************************************************
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

# Copy supervisord.conf from Agents folder to the image environment
COPY supervisord.conf /etc/supervisord.conf

# Expose SSH and Docker daemon ports
EXPOSE 22

# Start Docker and SSH server
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
