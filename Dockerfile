FROM ubuntu:22.04

# Install Java 17, basic tools, and timezone data
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openjdk-17-jdk curl unzip tzdata && \
    # Set timezone to IST (Asia/Kolkata) for scheduler alignment
    ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    echo "Asia/Kolkata" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    echo "✅ Timezone set to IST (Asia/Kolkata)"

# Environment setup
ENV MULE_VERSION=4.10.0 \
    MULE_HOME=/opt/mule \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=$JAVA_HOME/bin:$PATH

# Copy the provided Mule EE standalone ZIP (download from Anypoint Platform)
COPY mule-ee-standalone-${MULE_VERSION}.zip /opt/mule.zip

# Install Mule runtime and configure for Docker
RUN mkdir -p /opt && \
    cd /opt && \
    echo "📦 Using provided Mule EE Runtime ${MULE_VERSION} ZIP..." && \
    unzip -q mule.zip && \
    # Detect the extracted folder name dynamically
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "mule*${MULE_VERSION}*" | head -n 1) && \
    echo "📦 Extracted folder: $EXTRACTED_DIR" && \
    mv "$EXTRACTED_DIR" "$MULE_HOME" && \
    rm mule.zip && \
    chmod +x ${MULE_HOME}/bin/mule && \
    # Disable console input to fix Docker stdin/pipe issues
    echo "wrapper.disable_console_input=TRUE" >> ${MULE_HOME}/conf/wrapper.conf && \
    # Create directories if they don't exist
    mkdir -p ${MULE_HOME}/logs ${MULE_HOME}/conf ${MULE_HOME}/apps && \
    echo "✅ Mule EE runtime installed successfully at ${MULE_HOME}"

# Copy your Mule app JAR
COPY ./target/job_mail-1.0.0-mule-application.jar ${MULE_HOME}/apps/

# (Optional) Copy EE license if required for production features
# COPY license.lic ${MULE_HOME}/conf/

# Set working directory
WORKDIR ${MULE_HOME}

# (Optional) Expose HTTP port if your app has HTTP listeners
# EXPOSE 8081

# Volumes for logs, config, and apps (persistent storage)
VOLUME ["${MULE_HOME}/logs", "${MULE_HOME}/conf", "${MULE_HOME}/apps"]

# Health check to ensure Mule is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "org.mule" > /dev/null || exit 1

# Start Mule runtime
ENTRYPOINT ["./bin/mule"]
CMD ["-M-Dmule.verbose.exceptions=true"]