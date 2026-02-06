# Dawarich

Self-hosted alternative to Google Location History

**This chart is not maintained by the upstream project and any issues with the chart should be raised
[here](https://github.com/Cogitri/charts/issues/new)**

## Source Code

* <https://github.com/Freika/dawarich>

## Dependencies

| Repository | Name     |
|----|----------|
| <https://dandydeveloper.github.io/charts> | redis-ha |

Additionally, you have to supply your own postgresql, for example by using https://cloudnative-pg.io .

## Installing the Chart

To install the chart with the release name `dawarich`

### OCI (Recommended)

```console
helm install dawarich oci://ghcr.io/cogitri/charts/dawarich
```

### Traditional

```console
helm repo add cogitri https://charts.cogitri.dev
helm repo update
helm install dawarich cogitri/dawarich
```

## Values

Some of the most important values are documented below. Checkout the [values.yaml](./values.yaml) file for the complete documentation.

| Key                 | Type | Default | Description                                                                                                                                                                                                |
|---------------------|------|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| env                 | object | See [values.yaml](./values.yaml) | Environment variables used for configuration of Dawarich                                                                                                                                                   |
| dawarich            | object | See [values.yaml](./values.yaml) | Pod configuration for the Dawarich deployment                                                                                                                                                              |
| sidekiq             | object | See [values.yaml](./values.yaml) | Pod configuration for the Sidekiq deployment                                                                                                                                                               |
| image.pullPolicy    | string | `"IfNotPresent"` | Image pull policy                                                                                                                                                                                          |
| image.repository    | string | `"docker.io/freikin/dawarich"` | Image repository                                                                                                                                                                                           |
| ingress             | object | See [values.yaml](./values.yaml) | Enable and configure ingress settings for the chart under this key.                                                                                                                                        |
| persistence.export  | object | See [values.yaml](./values.yaml) | Configure watched volume settings for the chart under this key.                                                                                                                                            |
| persistence.public  | object | See [values.yaml](./values.yaml) | Configure public volume settings for the chart under this key.                                                                                                                                             |
| persistence.storage | object | See [values.yaml](./values.yaml) | Configure main storage volume settings for the chart under this key.                                                                                                                                       |
| postgresql          | object | See [values.yaml](./values.yaml) | Configure postgresql database subchart under this key. Dawarich will automatically be configured to use the credentials supplied to postgresql.                                                            |
| redis               | object | See [values.yaml](./values.yaml) | Configure redis subchart under this key. Dawarich will automatically be configured to use the credentials supplied to redis. [[ref]](https://github.com/DandyDeveloper/charts/tree/master/charts/redis-ha) |

To use an external Redis instance, set `.enabled: false` with the external host and port. E.g. for external Redis;

```yaml
redis:
  enabled: false
  host: my.redis.cluster
  port: 6379

  # existingSecret: provide your own secret
  redisPassword: changeme
```

## Secrets

Certain keys can be either specified directly in the values or as a `secretKeyRef`.

Example as a value:

```yaml
postgresql:
  auth:
    username: test
```

Example as a `secretKeyRef`:

```yaml
postgresql:
  auth:
    username:
      name: test-secret
      key: test-key
```

List of values with `secretKeyRef` support:

* `keyBase`
* `postgresql.host`
* `postgresql.port`
* `postgresql.auth.database`
* `postgresql.auth.username`
* `postgresql.auth.password`