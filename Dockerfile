ARG SPARKPLUG_VERSION=3.0.0
ARG EXTENSION_VERSION=4.29.0

FROM alpine AS git
RUN apk fix && apk --no-cache add git

FROM git as git-extension
ARG EXTENSION_VERSION
RUN git clone --branch "${EXTENSION_VERSION}" https://github.com/hivemq/hivemq-sparkplug-aware-extension.git /hivemq-sparkplug-aware-extension

FROM gradle:jdk11-alpine AS build-extension
ARG EXTENSION_VERSION
USER gradle
COPY --from=git-extension --chown=gradle:gradle /hivemq-sparkplug-aware-extension/ /hivemq-sparkplug-aware-extension/
WORKDIR /hivemq-sparkplug-aware-extension
RUN gradle build
RUN unzip build/hivemq-extension/hivemq-sparkplug-aware-extension-${EXTENSION_VERSION}.zip -d build/hivemq-extension/

FROM git AS git-sparkplug
ARG SPARKPLUG_VERSION
RUN git clone --branch "v${SPARKPLUG_VERSION}" https://github.com/eclipse-sparkplug/sparkplug.git /sparkplug

FROM gradle:jdk11-alpine AS build-tck
ARG SPARKPLUG_VERSION
USER gradle
COPY --from=git-sparkplug --chown=gradle:gradle /sparkplug/ /sparkplug/
WORKDIR /sparkplug/tck
RUN gradle build
RUN unzip build/hivemq-extension/sparkplug-tck-${SPARKPLUG_VERSION}.zip -d build/hivemq-extension/

FROM hivemq/hivemq-ce AS hivemq
COPY --from=git-sparkplug /sparkplug/tck/hivemq-configuration/config.xml config/config.xml
COPY --from=build-extension /hivemq-sparkplug-aware-extension/build/hivemq-extension/hivemq-sparkplug-aware-extension/ extensions/hivemq-sparkplug-aware-extension/
COPY --from=build-tck /sparkplug/tck/build/hivemq-extension/sparkplug-tck/ extensions/sparkplug-tck/

FROM node:19.1.0-alpine AS webconsole
ENV NODE_OPTIONS=--openssl-legacy-provider
COPY --from=git-sparkplug /sparkplug/tck/webconsole /sparkplug/tck/webconsole
WORKDIR /sparkplug/tck/webconsole
RUN corepack enable
RUN yarn set version 1.22.19
RUN yarn install
RUN yarn run build
ENV HOST=0
CMD ["yarn", "start"]
