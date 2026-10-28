ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# Debian 10 and 11 are EOL, and apt fails on both without the archive.
#
# Debian 10: deb.debian.org no longer serves buster at all, and what is left in
# the archive is past its Release validity date. The security archive is not
# optional: without it `apt-get update` succeeds and `libc6-dev` then fails
# with "held broken packages" — the base image carries libc6 2.28-10+deb10u3,
# the main archive only offers libc6-dev …u1, and …u4 lives in buster/updates.
#
# Debian 11: measured 2026-10-28, deb.debian.org still serves bullseye's
# Release files but has pruned the packages they point to — every security
# update 404s (perl …deb11u5, openssl, curl). archive.debian.org has all of
# them. The failure is the confusing kind: `apt-get update` succeeds and the
# install dies on 404s, so the error does not say "EOL".
RUN . /etc/os-release 2>/dev/null; \
    case "${ID}${VERSION_ID}" in \
      debian10) \
        { \
          echo 'deb http://archive.debian.org/debian buster main contrib non-free'; \
          echo 'deb http://archive.debian.org/debian-security buster/updates main contrib non-free'; \
        } > /etc/apt/sources.list ;; \
      debian11) \
        { \
          echo 'deb http://archive.debian.org/debian bullseye main'; \
          echo 'deb http://archive.debian.org/debian bullseye-updates main'; \
          echo 'deb http://archive.debian.org/debian-security bullseye-security main'; \
        } > /etc/apt/sources.list ;; \
    esac; \
    case "${ID}${VERSION_ID}" in debian10|debian11) \
        printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99no-check-valid ;; \
    esac

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends \
       curl git wget gcc make libc6-dev ripgrep fd-find docker.io ca-certificates \
       sudo \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fsSL "https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-$(uname -m)" \
       -o /usr/local/lib/docker/cli-plugins/docker-compose \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# fzf, pinned. This used to resolve "latest" through the GitHub API, which this
# repo's own conventions rule out: unauthenticated it allows 60 requests an
# hour, and the failure lands later as a build nobody can reproduce.
ARG FZF_VERSION=0.57.0
RUN ARCH=$(dpkg --print-architecture) \
    && curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${ARCH}.tar.gz" \
       -o /tmp/fzf.tar.gz \
    && tar -C /usr/local/bin -xzf /tmp/fzf.tar.gz fzf \
    && rm /tmp/fzf.tar.gz

# Neovim, chosen by THIS image's GLIBC.
#
# It used to always fetch the latest release, which needs GLIBC 2.34. On the
# older images that binary cannot start — and it still answers `command -v`,
# so a suite that checks for presence rather than execution inherits a broken
# editor and reports failures that have nothing to do with what it tests.
# That is exactly what happened to the Ubuntu 20.04 run.
#
# Floors read from the binaries with objdump:
#   v0.12.5  GLIBC 2.34    v0.10.3  GLIBC 2.29    v0.9.5  GLIBC 2.14
RUN set -eu; \
    glibc=$(ldd --version | head -n1 | awk '{print $NF}'); \
    major=${glibc%%.*}; minor=${glibc##*.}; \
    if [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 34 ]; }; then \
        ver=v0.12.5; archive=nvim-linux-x86_64.tar.gz; dir=nvim-linux-x86_64; \
    elif [ "$major" -eq 2 ] && [ "$minor" -ge 29 ]; then \
        ver=v0.10.3; archive=nvim-linux64.tar.gz; dir=nvim-linux64; \
    else \
        ver=v0.9.5;  archive=nvim-linux64.tar.gz; dir=nvim-linux64; \
    fi; \
    echo "GLIBC ${glibc} -> Neovim ${ver}"; \
    curl -fsSL "https://github.com/neovim/neovim/releases/download/${ver}/${archive}" -o /tmp/nvim.tar.gz; \
    tar -C /opt -xzf /tmp/nvim.tar.gz; \
    mv "/opt/${dir}" /opt/nvim; \
    rm /tmp/nvim.tar.gz; \
    chmod 755 /opt/nvim; \
    /opt/nvim/bin/nvim --version | head -n1

ENV PATH="/opt/nvim/bin:${PATH}"

WORKDIR /root

CMD ["bash"]
