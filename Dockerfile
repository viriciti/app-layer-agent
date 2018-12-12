FROM viriciti/app-layer-base-image-armhf-alpine-node

RUN [ "cross-build-start" ]

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Install dependencies
COPY package.json /app
COPY node_modules /app/node_modules
COPY build /app/build
COPY config /app/config

# Configure properties
ENV NODE_ENV production

CMD ["node", "/app/build/main.js"]

RUN [ "cross-build-end" ]
