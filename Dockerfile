# syntax=docker/dockerfile:1.7
#
# Postgres-only ChirpStack (no SQLite build variant).
#
# IMPORTANT — always build amd64:
#   docker build --platform linux/amd64 -t chirpstack:latest .
# On Apple Silicon (or ARM CI) omitting --platform builds arm64 stages and often breaks Makefile
# dist-amd64 (x86_64-gnu) vs this Dockerfile’s expectations.
#
# Targets:
#   runtime (default last stage) — runnable binary plus /app/dist from Nix `make dist-amd64`.
#   runtime-minimal — same binary only; skips `dist` (faster, no COPY --from dist).
#
# Minimal image only:
#   docker build --platform linux/amd64 --target runtime-minimal -t chirpstack:slim .

FROM nixos/nix:2.24.9 AS base

WORKDIR /app

ENV NIX_CONFIG="sandbox = false"
ENV CARGO_INCREMENTAL=0
ENV CI=true
# Postgres-only (no SQLite build variant for this image).
ENV DATABASE=postgres

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

# Nix-linked ELFs use PT_INTERPRETER under /nix/store; Debian has no matching ld.so.
# Rebuild on Bookworm for /lib64/ld-linux-x86-64.so.2.
FROM rust:bookworm AS debian-chirpstack

WORKDIR /app
COPY --from=ui-build /app /app

# Must match Postgres-only base stage (DATABASE=postgres).
ENV DATABASE=postgres
ENV CI=true
ENV CARGO_INCREMENTAL=0 \
	LIBCLANG_PATH=/usr/lib/x86_64-linux-gnu

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
	binutils clang libclang-dev pkg-config protobuf-compiler libprotobuf-dev cmake \
	libssl-dev libpq-dev libsasl2-dev zlib1g-dev jq \
	&& rm -rf /var/lib/apt/lists/*

RUN export BINDGEN_EXTRA_CLANG_ARGS="-I`clang -print-resource-dir`/include" \
	&& cargo build --release --locked \
	--no-default-features \
	--features=postgres \
	-p chirpstack

RUN test -x /app/target/release/chirpstack

# Runnable image — binary only (no `dist`; does not execute Nix packaging stage).
FROM debian:bookworm-slim AS runtime-minimal

WORKDIR /app

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates libpq5 libssl3 \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=debian-chirpstack /app/target/release/chirpstack /usr/bin/chirpstack

RUN test -x /usr/bin/chirpstack

ENTRYPOINT ["/usr/bin/chirpstack"]
CMD ["--config", "/etc/chirpstack"]

# Runnable image — binary plus Nix-produced packages under /app/dist
FROM debian:bookworm-slim AS runtime

WORKDIR /app

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates libpq5 libssl3 \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=debian-chirpstack /app/target/release/chirpstack /usr/bin/chirpstack
COPY --from=dist /app/dist /app/dist

RUN test -x /usr/bin/chirpstack

ENTRYPOINT ["/usr/bin/chirpstack"]
CMD ["--config", "/etc/chirpstack"]
