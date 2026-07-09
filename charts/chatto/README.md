# chatto

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square)
![AppVersion: 0.4.2](https://img.shields.io/badge/AppVersion-0.4.2-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

A Helm chart for [Chatto](https://github.com/chattocorp/chatto), a self-hosted
chat application backed by NATS JetStream.

> Community-maintained and unofficial. Apache-2.0. See the
> [repository README](https://github.com/luroden/chatto-helm) for full docs.

## Install

```sh
helm install chatto oci://ghcr.io/luroden/charts/chatto \
  --namespace chatto --create-namespace \
  --set chatto.url=https://chat.example.com \
  --set service.type=LoadBalancer
```

## Requirements

| Repository | Name | Version |
| --- | --- | --- |
| https://nats-io.github.io/k8s/helm/charts/ | nats | 2.14.2 |
| https://helm.livekit.io | livekit-server (alias: livekit) | 1.9.0 |

Kubernetes 1.23+, Helm 3.8+, a default StorageClass, and a way to expose the
Service (a LoadBalancer, Ingress, or Gateway API controller).

## Key values

| Key | Default | Description |
| --- | --- | --- |
| `chatto.url` | `""` | **Required.** Public HTTPS origin (`CHATTO_WEBSERVER_URL`). |
| `replicaCount` | `2` | Stateless Chatto replicas. |
| `image.repository` | `ghcr.io/chattocorp/chatto` | Chatto image. |
| `image.tag` | `""` | Defaults to chart `appVersion`. |
| `service.type` | `ClusterIP` | Set `LoadBalancer` to expose directly. |
| `service.port` | `80` | Service port (maps to the container http port). |
| `ingress.enabled` | `false` | Create an Ingress. Mutually exclusive with `httpRoute`. |
| `httpRoute.enabled` | `false` | Create a Gateway API HTTPRoute. |
| `httpRoute.parentRefs` | `[]` | Gateways to attach to. Required unless `gateway.enabled`. |
| `httpRoute.hostnames` | `[]` | Defaults to the host in `chatto.url`. |
| `gateway.enabled` | `false` | Also create a Gateway owned by this release. |
| `gateway.gatewayClassName` | `""` | **Required** when `gateway.enabled`. |
| `gateway.tls.certificate.enabled` | `false` | Create a cert-manager Certificate for the listener. |
| `gateway.tls.certificate.issuerRef.name` | `""` | An Issuer/ClusterIssuer you already run; the chart creates none. |
| `nats.enabled` | `true` | Deploy bundled NATS JetStream. Disable for external NATS. |
| `nats.config.cluster.replicas` | `3` | NATS cluster size (odd). Drives `CHATTO_NATS_REPLICAS`. |
| `nats.config.jetstream.fileStore.pvc.size` | `10Gi` | JetStream PVC per node. |
| `nats.config.jetstream.memoryStore.maxSize` | `256Mi` | JetStream memory store. Required — Chatto's `MEMORY_CACHE` bucket needs it. |
| `externalNats.url` | `""` | External NATS URL(s), used when `nats.enabled=false`. |
| `chatto.assets.storageBackend` | `nats` | `nats` or `s3`. |
| `chatto.smtp.enabled` | `false` | Email via SMTP. Required for browser registration. |
| `chatto.operatorApi.enabled` | `false` | Root-equivalent Unix socket for `chatto operator`. The only way to create the first user without SMTP. |
| `chatto.push.enabled` | `false` | Web Push notifications. |
| `chatto.livekit.enabled` | `false` | Voice/video via LiveKit. |
| `chatto.metrics.enabled` | `false` | Prometheus metrics endpoint. |
| `serviceMonitor.enabled` | `false` | Create a Prometheus Operator ServiceMonitor. |
| `autoscaling.enabled` | `false` | Horizontal Pod Autoscaler. |
| `secrets.existingSecret` | `""` | Bring-your-own Secret for crypto keys. |

See [`values.yaml`](values.yaml) for the complete, commented configuration
surface. Every option maps to a
[`CHATTO_*` environment variable](https://docs.chatto.run/reference/environment-variables/).

## Examples

Six worked values files live in [`examples/`](examples/), each rendered and
schema-validated in CI. Start from the closest one rather than from scratch.

| File | Use it when |
| --- | --- |
| [`minimal.yaml`](examples/minimal.yaml) | Smallest supportable production install, behind an ingress. |
| [`single-node.yaml`](examples/single-node.yaml) | Homelab or dev cluster; one replica, one NATS node. |
| [`external-nats.yaml`](examples/external-nats.yaml) | You already run NATS JetStream. |
| [`gateway-route-only.yaml`](examples/gateway-route-only.yaml) | Gateway API, attaching to a Gateway the platform owns. |
| [`gateway-full.yaml`](examples/gateway-full.yaml) | Gateway API, with the chart owning the Gateway and its cert-manager Certificate. |
| [`full.yaml`](examples/full.yaml) | Reference for every subsystem: S3, SMTP, Push, LiveKit, OIDC, metrics, HPA. |

```sh
helm install chatto oci://ghcr.io/luroden/charts/chatto \
  -n chatto --create-namespace -f examples/minimal.yaml
```

[`examples/README.md`](examples/README.md) explains the cross-cutting decisions
(WebSocket timeouts, `CHATTO_NATS_REPLICAS`, secret handling) and documents the
sharp edges the examples steer around.
