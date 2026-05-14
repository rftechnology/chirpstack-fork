# syntax=docker/dockerfile:1.7
# linux/amd64: dist-amd64 (glibc, no cross). Build: docker build --platform linux/amd64 ...

FROM nixos/nix:2.24.9 AS base

WORKDIR /app

ENV NIX_CONFIG="sandbox = false"
ENV CARGO_INCREMENTAL=0
ENV CI=true
ARG DATABASE=postgres
ENV DATABASE=${DATABASE}

RUN nix-channel --add https://nixos.org/channels/nixos-25.11 nixpkgs \
	&& nix-channel --update

COPY . .

# Build UI
FROM base AS ui-build
RUN nix-shell shell.nix --command "make build-ui"

# Run tests
FROM ui-build AS test
RUN nix-shell shell.nix --command "make test"

# Dev tools + x86_64-only dist (no cross)
FROM ui-build AS dist
RUN nix-shell shell.nix --command "make dev-dependencies"
RUN nix-shell shell.nix --command "make dist-amd64"

# Optional runtime image
FROM debian:bookworm-slim AS runtime

WORKDIR /app

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

 COPY --from=dist /app/dist /app/dist

CMD ["ls", "-lah", "/app/dist"]
