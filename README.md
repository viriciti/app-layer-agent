## App Layer Agent

The App Layer Agent is the application responsible for installing, updating and removing applications, as configured by the [App Layer Control](https://github.com/viriciti/app-layer-control).

## Compatibility Check

- NodeJS v10

## Dependencies

- Docker or Balena with the environment variable `USE_BALENA` set
- MQTT

## Getting started

1. Fork the project
2. Run `npm install` to install the npm modules
3. Run `npm start` to start developing

## Configuration

The following properties can be configured (environment variables)

- `MQTT_ENDPOINT`: Endpoint of the MQTT broker. Protocol is determined based on the presence of `TLS_KEY`, `TLS_CERT` and `TLS_CA`. Default: localhost
- `MQTT_PORT`: Port for the endpoint. Default: 1883
- `TLS_KEY`: TLS key file location. Default: _empty_
- `TLS_CERT`: TLS certificate file location. Default: _empty_
- `TLS_CA`: CA certificate file location. Default: _empty_
- `USE_BALENA`: Use [Balena](https://www.balena.io/engine/) instead of [Docker](https://docs.docker.com/engine/) (only affects socket path). Default: false
- `GITLAB_USER_NAME`: GitLab username. Default: _empty_
- `GITLAB_USER_ACCESS_TOKEN`: GitLab password or access token (recommended to use the latter). Default: _empty_
