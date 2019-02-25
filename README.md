## App Layer Agent

App Layer Agent is an application management tool that is used to replicate an environment shared with other devices.  
The environment is configured and pushed by the [App Layer Control](https://github.com/viriciti/app-layer-control).

> #### ⚠️ Before running it locally
>
> App Layer Agent is rather aggressive in keeping your environment in sync with how App Layer Control wants the environment to be. If you run this on your local machine, note that it will start removing containers (applications) **immediatly**. To prevent this, create a local configuration file (in `./config`) and disable removal like so:
>
> ```
> {
>  "docker": {
>    "container": {
>      "allowRemoval": false
>    }
>  }
> }
> ```

## Compatibility

- NodeJS v10

## Dependencies

- Balena Engine (or Docker with the environment variable `USE_DOCKER` set)
- MQTT

## Getting started

### Before running it locally

App Layer Agent is rather aggressive in keeping your environment in sync with how App Layer Control wants the environment to be. If you run this on your local machine, note that it will start removing containers (applications) **immediatly**. To prevent this, create a local configuration file (in `./config`) and disable removal like so:

```
{
  "docker": {
    "container": {
      "allowRemoval": false
    }
  }
}
```

Alternatively, you can keep the configuration as is, and configure the containers you want to keep regardless of what App Layer Agent wants:

```
{
  "docker": {
    "container": {
      "allowRemoval": true,
      "whitelist": ["app-layer-agent", "device-manager"]
    }
  }
}
```

### Development

1. Fork the project
2. Run `npm install` to install the npm modules
3. Run `npm start` to start developing

## Configuration

The following properties can be configured (environment variables)

- `MQTT_ENDPOINT`: Endpoint of the MQTT broker. Default: localhost
- `MQTT_PORT`: Port for the endpoint. Default: 1883
- `TLS_KEY`: TLS key file location. Default: _empty_
- `TLS_CERT`: TLS certificate file location. Default: _empty_
- `TLS_CA`: CA certificate file location. Default: _empty_
- `USE_DOCKER`: Use [Docker](https://docs.docker.com/engine/) instead of [Balena Engine](https://www.balena.io/engine/) (only affects socket path). Default: false
- `GITLAB_USERNAME`: GitLab username. Default: _empty_
- `GITLAB_ACCESS_TOKEN`: GitLab password or access token (recommended to use the latter). Default: _empty_

**Note**: MQTT endpoint protocol is determined based on the presence of `TLS_KEY`, `TLS_CERT` and `TLS_CA`.
