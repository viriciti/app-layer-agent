FROM viriciti/app-layer-base-image-armhf-alpine-node:10

RUN [ "cross-build-start" ]

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Build app
COPY build /app/build
COPY build/config /app/config
COPY package.json /app

COPY src /app/src
COPY config /app/config
COPY package.json /app

# Configure properties
ENV NODE_ENV production

CMD ["node", "/app/build/main.js"]

RUN ["cross-build-end"]
