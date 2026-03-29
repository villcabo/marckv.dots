ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends \
       curl git wget gcc make libc6-dev ripgrep fd-find docker.io ca-certificates \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
       -o /usr/local/lib/docker/cli-plugins/docker-compose \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install fzf (latest from GitHub — apt version is too old for fzf-lua)
RUN FZF_VERSION=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/') \
    && ARCH=$(dpkg --print-architecture | sed 's/amd64/amd64/;s/arm64/arm64/') \
    && curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${ARCH}.tar.gz" \
       -o /tmp/fzf.tar.gz \
    && tar -C /usr/local/bin -xzf /tmp/fzf.tar.gz fzf \
    && rm /tmp/fzf.tar.gz

# Install Neovim (latest stable)
RUN curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
       -o /tmp/nvim.tar.gz \
    && tar -C /opt -xzf /tmp/nvim.tar.gz \
    && mv /opt/nvim-linux-x86_64 /opt/nvim \
    && rm /tmp/nvim.tar.gz

ENV PATH="/opt/nvim/bin:${PATH}"

WORKDIR /root

CMD ["bash"]
