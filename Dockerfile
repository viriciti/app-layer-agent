FROM viriciti/app-layer-base-image-armhf-alpine-node:10

RUN [ "cross-build-start" ]

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Build app
COPY build /app/build
COPY build/config /app/config

# Install production dependencies
COPY package.json /app
RUN rm -rf node_modules && \
    npm install --production

# Configure properties
ENV NODE_ENV production
ENV USE_DOCKER true

CMD ["node", "/app/build/main.js"]

RUN [ "cross-build-end" ]
