# Pin matches docker-compose.yml / deploy/env.production.example (POSTGRES_IMAGE).
# CI: docker build -t $ECR/postgres:18-alpine --build-arg BASE_IMAGE=... deploy/docker/postgres
ARG BASE_IMAGE=docker.io/library/postgres:18-alpine
FROM ${BASE_IMAGE}
