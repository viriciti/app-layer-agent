FROM viriciti/app-layer-base-image-armhf-alpine-node

RUN [ "cross-build-start" ]

# Create app directory
RUN mkdir -p /app
WORKDIR /app

# Install dependencies
COPY package.json /app
RUN npm install

COPY src /app/src
COPY config /app/config
RUN npm run build

CMD ["node", "/app/build/main.js"]

RUN [ "cross-build-end" ]
