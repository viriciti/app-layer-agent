FROM viriciti/app-layer-base-image-armhf-alpine-node:10

RUN ["cross-build-start"]

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Build app
COPY build /app/build
COPY build/config /app/config
COPY node_modules /app/node_modules
COPY package.json /app

# Configure properties
ENV NODE_ENV production

CMD ["node", "/app/build/main.js"]

RUN ["cross-build-end"]
