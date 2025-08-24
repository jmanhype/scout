# Scout Production Docker Image
FROM elixir:1.17-otp-27-alpine

# Install system dependencies
RUN apk add --no-cache git build-base postgresql-client curl

# Create app directory
WORKDIR /app

# Set production environment
ENV MIX_ENV=prod

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files and get dependencies
COPY mix.exs mix.lock ./
COPY config ./config
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy source code
COPY lib ./lib
COPY priv ./priv

# Compile the application
RUN mix compile

# Create non-root user
RUN adduser -D scout
RUN chown -R scout:scout /app
USER scout

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-4050}/health || exit 1

# Expose port
EXPOSE 4050

# Start the application
CMD ["mix", "run", "--no-halt"]