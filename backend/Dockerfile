FROM python:3.11.9-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

RUN python -m venv /opt/planit-venv
ENV PATH="/opt/planit-venv/bin:$PATH"

COPY pyproject.toml ./
COPY app ./app
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir .

FROM python:3.11.9-slim-bookworm AS runtime

ARG PLANIT_BUILD_VERSION=development
ARG PLANIT_BUILD_REVISION=unknown

LABEL org.opencontainers.image.title="PlanIT API" \
      org.opencontainers.image.description="PlanIT personal-finance API" \
      org.opencontainers.image.version="${PLANIT_BUILD_VERSION}" \
      org.opencontainers.image.revision="${PLANIT_BUILD_REVISION}" \
      org.opencontainers.image.source="https://github.com/abrghaze/PlanIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/planit-venv/bin:$PATH" \
    PYTHONPATH=/app

RUN groupadd --system --gid 10001 planit \
    && useradd --system --uid 10001 --gid planit --home-dir /nonexistent planit

WORKDIR /app

COPY --from=builder /opt/planit-venv /opt/planit-venv
COPY alembic.ini ./
COPY alembic ./alembic

USER planit
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/api/v1/ready', timeout=2)"]

STOPSIGNAL SIGTERM

CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
