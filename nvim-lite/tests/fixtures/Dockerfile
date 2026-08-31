# syntax=docker/dockerfile:1
ARG BASE=debian:12-slim
FROM ${BASE} AS build

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .
RUN make release

FROM ${BASE}
COPY --from=build /src/out/app /usr/local/bin/app
USER 65534:65534
HEALTHCHECK --interval=30s CMD ["app", "--health"]
ENTRYPOINT ["app"]
