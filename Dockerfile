# Use Alpine Linux as base image for smaller size
FROM alpine:3.18

# Install required packages and build tools
RUN apk add --no-cache \
    fortune \
    netcat-openbsd \
    bash \
    make \
    gcc \
    musl-dev \
    perl \
    perl-dev \
    wget \
    unzip

# Install cowsay from source
RUN wget https://github.com/schacon/cowsay/archive/master.zip && \
    unzip master.zip && \
    cd cowsay-master && \
    ./install.sh /usr/local && \
    cd .. && \
    rm -rf cowsay-master master.zip

# Create app directory
WORKDIR /app

# Copy the wisecow script
COPY wisecow.sh .

# Make the script executable
RUN chmod +x wisecow.sh

# Create a non-root user for security
RUN adduser -D -s /bin/bash wisecow && chown -R wisecow:wisecow /app

# Switch to non-root user
USER wisecow

# Expose the port
EXPOSE 4499

# Health check to ensure the service is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost 4499 || exit 1

# Run the application
CMD ["/bin/bash", "./wisecow.sh"]
