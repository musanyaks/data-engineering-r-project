# Multi-stage build for minimal image size
# Optimized for 4GB RAM / 20GB SSD constraint

FROM rocker/r-ver:4.3.1 AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsqlite3-dev \
    libgit2-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install renv and restore packages
RUN R -e "install.packages('renv')"

WORKDIR /app
COPY renv.lock .
COPY .Rprofile .

# Restore packages in isolated library
RUN R -e "renv::restore(repos = c(CRAN = 'https://cloud.r-project.org'))"

# Production stage
FROM rocker/r-ver:4.3.1

# Runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsqlite3-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy renv library from builder
COPY --from=builder /app/renv/library renv/library
COPY --from=builder /app/renv/settings.json renv/settings.json

# Copy project files
COPY R/ R/
COPY config/ config/
COPY sql/ sql/
COPY tests/ tests/
COPY Makefile .

# Create data directories
RUN mkdir -p data/raw data/processed data/archive logs reports

# Set resource limits via environment
ENV R_CONFIG_PROFILE=prod
ENV RENV_PATHS_LIBRARY=renv/library
ENV OMP_NUM_THREADS=2

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD Rscript -e "cat('OK\n')" || exit 1

ENTRYPOINT ["make"]
CMD ["pipeline"]