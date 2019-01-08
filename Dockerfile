FROM viriciti/app-layer-base-image-armhf-alpine-node:10

RUN [ "cross-build-start" ]

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Build app
COPY src /app/src
COPY config /app/config
COPY package.json /app
RUN npm install --only dev
RUN npm run build

# Install production dependencies
RUN rm -rf node_modules && \
    npm install --production

# Configure properties
ENV NODE_ENV production

CMD ["node", "/app/build/main.js"]

RUN [ "cross-build-end" ]
