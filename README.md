# docker-taiga
[![](https://images.microbadger.com/badges/image/galexrt/taigaio.svg)](https://microbadger.com/images/galexrt/taigaio "Get your own image badge on microbadger.com")

[![Docker Repository on Quay.io](https://quay.io/repository/galexrt/taigaio/status "Docker Repository on Quay.io")](https://quay.io/repository/galexrt/zulip)

Image available from:
* [**Quay.io**](https://quay.io/repository/galexrt/taigaio)
* [**Docker Hub**](https://hub.docker.com/r/galexrt/taigaio)

[Taiga.Io](https://taiga.io/) in a Docker Image.

## Usage
### Pulling the image
From quay.io:
```
docker pull quay.io/galexrt/taigaio:latest
```
Or from Docker Hub:
```
docker pull galexrt/taigaio:latest
```

### Configuring
To set a Taiga.Io setting variable, prefix it with `SETTING_`.
Examples:
* For the variable GITHUB_API_CLIENT_ID
```
SETTING_GITHUB_API_CLIENT_ID
```
* And so on

For available setting variables, please refer to the Taiga.Io docs.

### Running the image
Use `docker-compose` command to start the container.
Check the `docker-compose.yml` for an example configuration.
Edit the configuration to suit your needs.

## License
The code in this repository is licensed like the taiga code under AGPL v3.0.

Please read the license carefully and ask us if you have any questions.
