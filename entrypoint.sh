#!/bin/bash

COUNTER=0
while true; do
  ((COUNTER+=1))

  echo "Count $COUNTER: Looking up listener host $APP_LAYER_MQTT_ENDPOINT with nslookup"
  nslookup $APP_LAYER_MQTT_ENDPOINT

  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ]; then
    echo "Count $COUNTER: Domain $APP_LAYER_MQTT_ENDPOINT resolvable! Exit code was $EXIT_CODE. Starting application..."
    break
  else
    echo "Count $COUNTER: Domain $APP_LAYER_MQTT_ENDPOINT NOT resolvable: exit code was $EXIT_CODE. Waiting 10 seconds..."
    sleep 10

    if [[ $COUNTER -gt 6 ]]; then
      echo "Count $COUNTER: Tried nslookup 7 times. No luck giving up!"
      exit 0
    fi
  fi
done

/usr/local/bin/node /app/build/main.js
