#!/bin/bash

echo "Looking up listener host $APP_LAYER_MQTT_ENDPOINT with nslookup"
nslookup $APP_LAYER_MQTT_ENDPOINT

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "Domain $APP_LAYER_MQTT_ENDPOINT resolvable! Exit code was $EXIT_CODE. Starting application..."
  /usr/local/bin/node /app/build/main.js
else
  echo "Domain $APP_LAYER_MQTT_ENDPOINT NOT resolvable: exit code was $EXIT_CODE. Exiting application..."
fi
