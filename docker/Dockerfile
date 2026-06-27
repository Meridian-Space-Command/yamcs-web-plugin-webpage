# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: build everything with Maven.
# The plugin module uses frontend-maven-plugin to download Node and build the
# TypeScript web extension, so a single `mvn package` produces both the plugin
# jar and the bundled demo Yamcs distribution. No separate Node stage needed.
# ---------------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /src

# Resolve dependencies first for better layer caching.
COPY pom.xml ./
COPY plugin/pom.xml plugin/pom.xml
COPY demo/pom.xml demo/pom.xml
RUN mvn -q -B -ntp -pl plugin,demo -am dependency:go-offline || true

# Build.
COPY . .
RUN mvn -q -B -ntp -DskipTests package

# Unpack the bundled Yamcs distribution produced by the yamcs-maven-plugin.
RUN mkdir -p /opt && \
    tar -xzf demo/target/estrack-demo-*.tar.gz -C /opt && \
    mv /opt/estrack-demo-* /opt/yamcs

# ---------------------------------------------------------------------------
# Stage 2: lightweight runtime image.
# ---------------------------------------------------------------------------
FROM eclipse-temurin:17-jre

ENV YAMCS_HOME=/opt/yamcs
WORKDIR /opt/yamcs

COPY --from=build /opt/yamcs /opt/yamcs

EXPOSE 8090

# bin/yamcsd is the foreground launcher created by the Yamcs bundle.
CMD ["bin/yamcsd", "--log", "2"]
