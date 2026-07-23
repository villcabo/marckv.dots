# docker-aliases v2 — e2e test image.
#
# Deliberately minimal: bash, zsh, the docker CLI and the compose plugin.
# Nothing else. This image exists to prove the aliases behave identically
# across distros and shells, so anything that is not a shell or docker is
# noise that only makes the build slower.
#
# Everything is pinned. No "latest", no GitHub API calls (rate limited to 60/h
# unauthenticated, which turns into random build failures), no hardcoded arch.

ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ARG DOCKER_VERSION=29.4.1
ARG COMPOSE_VERSION=5.1.3

ENV DEBIAN_FRONTEND=noninteractive

# Both shells live in one image on purpose: two images per distro would double
# the build, the push and the maintenance to test the very same code.
RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends \
        bash \
        zsh \
        ca-certificates \
        curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Static docker CLI + compose plugin.
#
# Static binaries rather than the distro package: identical versions on every
# distro, so a red test means the *shell* differs, never the tooling. No daemon
# ships in the image — `docker compose config` parses YAML without one, which
# is all the preview path needs.
RUN set -eux; \
    arch="$(uname -m)"; \
    curl -fsSL "https://download.docker.com/linux/static/stable/${arch}/docker-${DOCKER_VERSION}.tgz" \
        -o /tmp/docker.tgz; \
    tar -C /tmp -xzf /tmp/docker.tgz docker/docker; \
    mv /tmp/docker/docker /usr/local/bin/docker; \
    rm -rf /tmp/docker /tmp/docker.tgz; \
    mkdir -p /usr/local/lib/docker/cli-plugins; \
    curl -fsSL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-${arch}" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose; \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose; \
    docker --version; \
    docker compose version

# zsh only defines compdef after compinit has run. The completion tests depend
# on it, so bake it in rather than making every test remember.
RUN printf 'autoload -Uz compinit\ncompinit -u\n' > /root/.zshrc

WORKDIR /repo/docker-aliases-v2

CMD ["sleep", "infinity"]
