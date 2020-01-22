# STAGE 1
FROM viriciti/app-layer-base-image-armhf-alpine-node:10 as builder
RUN ["cross-build-start"]

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Build app
COPY src /app/src
COPY config /app/config
COPY package.json /app
COPY entrypoint.sh /app

RUN npm install --only dev
RUN npm run build

RUN rm -r node_modules && \
    npm install --production

RUN ["cross-build-end"]

# STAGE 2
FROM viriciti/app-layer-base-image-armhf-alpine-node:10

# Configure environment
ENV NODE_CONFIG_DIR=/app/config
ENV NODE_ENV=production

# Install production dependencies
# RUN ls /app
COPY --from=builder /app/build /app/build
COPY --from=builder /app/build/config /app/config
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/package.json /app/package.json
COPY --from=builder /app/entrypoint.sh /app/entrypoint.sh

WORKDIR /app

CMD [ "/app/entrypoint.sh" ]
