# Example values files

Six worked configurations, ordered roughly by ambition. Each renders cleanly
(`helm template`) and validates against the Kubernetes API schemas — including
the Gateway API and cert-manager CRD schemas; CI checks this on every change, so
they cannot silently rot as the chart evolves.

Pick the closest one, copy it, and edit. They are meant to be read as much as
executed — the comments explain the *why* behind each non-default value.

| File | Use it when | NATS | Availability |
| --- | --- | --- | --- |
| [`minimal.yaml`](minimal.yaml) | You want a supportable install with the fewest knobs turned. | Bundled, 3-node | 2 replicas, PDB |
| [`single-node.yaml`](single-node.yaml) | Homelab, dev cluster, or a small team. | Bundled, 1 node | Single replica, downtime on reboot |
| [`external-nats.yaml`](external-nats.yaml) | You already run NATS JetStream and Chatto should just connect to it. | External | 2 replicas, PDB |
| [`gateway-route-only.yaml`](gateway-route-only.yaml) | Your cluster has a Gateway API controller and a shared Gateway to attach to. | Bundled, 3-node | 2 replicas, PDB |
| [`gateway-full.yaml`](gateway-full.yaml) | Gateway API, and Chatto should own its Gateway plus a cert-manager Certificate. | Bundled, 3-node | 2 replicas, PDB |
| [`full.yaml`](full.yaml) | Reference for every optional subsystem: S3 assets, SMTP, Web Push, LiveKit calls, OIDC, metrics, autoscaling, NetworkPolicy. | Bundled, 3-node | 3–20 replicas, HPA |

```sh
helm install chatto oci://ghcr.io/luroden/charts/chatto \
  -n chatto --create-namespace \
  -f examples/minimal.yaml
```

## Things every example takes a position on

**WebSocket timeouts.** Chatto holds connections open for the life of a
session. An nginx ingress will sever them after 60 seconds unless
`proxy-read-timeout` and `proxy-send-timeout` are raised. Every ingress example
sets both. Under Gateway API the same hazard lives in `httpRoute.timeouts`,
which the chart defaults to `0s` (no timeout); the gateway examples spell it out
rather than lean on the default.

**Ingress or Gateway API, not both.** `ingress.enabled` and `httpRoute.enabled`
each create an independent path to the Service. The chart does not stop you from
turning on both — which is what a cutover needs — but steady state should have
exactly one.

**`CHATTO_NATS_REPLICAS` must match the cluster.** The chart derives it from
`nats.config.cluster.replicas` when NATS is bundled, and from
`externalNats.replicas` otherwise. Set it higher than the number of NATS nodes
and JetStream stream creation fails at startup. It must be odd.

**Secrets are never written into these files.** The paths that accept a
pre-existing Secret — `chatto.assets.s3.existingSecret`,
`chatto.smtp.existingSecret`, `chatto.push.existingSecret`,
`chatto.livekit.existingSecret`, `externalNats.auth.existingSecret` — are used
wherever one exists. The remaining few (`chatto.auth.providers[].clientSecret`,
`livekit.livekit.keys`) are passed at install time with `--set`.

## Known sharp edges these examples work around

- **`secrets.existingSecret` is currently unusable.** Setting it makes the chart
  render its own Secret *under your Secret's name*, so `helm install` fails on
  the ownership conflict. `full.yaml` therefore leaves the four crypto keys
  auto-generated.
- **Auto-generated crypto keys and GitOps don't mix.** The keys are reused
  across upgrades via a cluster `lookup`, which returns nothing when rendering
  without cluster access (Argo CD's default, `helm diff`). Every render then
  invents new keys and logs all users out.
- **`updateStrategy` deep-merges.** Switching to `type: Recreate` requires
  `rollingUpdate: null`, or the API server rejects the Deployment. See
  `single-node.yaml`.
- **The default `topologySpreadConstraints` selector is hardcoded** to
  `app.kubernetes.io/name: chatto` with no instance label. It matches nothing
  under `nameOverride`, and two releases in one namespace spread against each
  other. `full.yaml` spells the selector out.
- **`natsAuth.secretName` is not release-scoped.** Subchart values cannot be
  templated, so the NATS token Secret name is the literal `chatto-nats-auth` in
  two places that must be changed together. Two Chatto releases in one namespace
  will collide.
