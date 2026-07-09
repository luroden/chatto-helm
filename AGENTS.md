# Instructions for Agents

Read this file first. It contains repo-wide rules for working on the Chatto
Helm chart. This repository packages a Kubernetes deployment for
[Chatto](https://github.com/chattocorp/chatto); it does **not** contain the
Chatto application source.

## Where Context Lives

- [README.md](README.md) — user-facing install/usage guide.
- [charts/chatto/values.yaml](charts/chatto/values.yaml) — the full configuration
  surface. Every knob maps to a `CHATTO_*` env var; keep the comments accurate.
- [charts/chatto/templates](charts/chatto/templates) — the manifests. Helpers
  (NATS URL/replica/secret resolution, labels) live in `_helpers.tpl`.
- Upstream Chatto docs — the source of truth for behavior:
  - Env vars: https://docs.chatto.run/reference/environment-variables/
  - Kubernetes: https://docs.chatto.run/guides/deployment/kubernetes/
  - High availability: https://docs.chatto.run/guides/infrastructure/high-availability/
  - Chatto's own `examples/k8s` raw manifests were the reference for this chart.

## Project Status

- Community-maintained and unofficial. This is not a Chatto release artifact
  (see [NOTICE](NOTICE)). Do not present it as official or use Chatto branding
  as if it were.
- The chart is licensed Apache-2.0, matching Chatto's example/integration
  licensing boundary. The Chatto server image it deploys is AGPL-3.0-or-later.
- Chatto is pre-1.0 and self-hosters track `:latest` or upgrade quickly. Prefer
  additive, backwards-compatible changes to values; renaming or removing a value
  is a breaking chart change.

## What You Must Know About Chatto

These facts drive the chart's design — do not regress them:

- **Chatto replicas are stateless.** All durable state lives in NATS JetStream.
  Never introduce per-replica local state, `ReadWriteOnce` PVCs on the Chatto
  Deployment, or session affinity. Scale the Deployment freely.
- **NATS JetStream is the primary data store.** It is a hard dependency, bundled
  as an optional subchart (`nats.enabled`) or supplied externally
  (`externalNats.*`). Do not reimplement a NATS chart here.
- **`CHATTO_NATS_REPLICAS` must be odd (1, 3, 5) and match the NATS cluster
  size.** The chart derives it in `_helpers.tpl` (`chatto.natsReplicas`); keep
  that logic correct when touching NATS values.
- **JetStream needs BOTH a file store and a memory store.** Chatto creates a
  memory-backed `MEMORY_CACHE` KV bucket (presence, 60s TTL) at startup. The
  upstream NATS subchart ships `memoryStore.enabled: false`, so the chart must
  turn it on; otherwise Chatto crash-loops with `insufficient memory resources
  available` and no amount of PVC sizing helps.
- **Health endpoints:** `/readyz` (startup + readiness) and `/healthz`
  (liveness) on the web server port. Probes must use these.
- **Config is env-var driven** (`CHATTO_{SECTION}_{KEY}`), split into a
  ConfigMap (non-sensitive) and a Secret (sensitive), consumed via `envFrom`.
- **The image runs as non-root (uid 1000)** and writes a NATS CLI context under
  `$HOME`; do not default `readOnlyRootFilesystem: true` without mounting the
  writable paths.
- **Chatto's WebSockets outlive any finite proxy timeout.** Ingress needs the
  nginx `proxy-read-timeout`/`proxy-send-timeout` annotations; Gateway API needs
  `httpRoute.timeouts` set to `0s`, which is the chart default. Do not
  "helpfully" give `httpRoute.timeouts` a finite default.

## Prime Directives

- Prefer simple, clear templates over clever helper gymnastics.
- Any change must keep these green (see Tooling):
  `helm lint --strict` and `helm template` across the default, external-NATS,
  HA, and all-features value permutations.
- Keep `values.yaml` the single source of documentation for options; comment
  new values and note whether they are sensitive.
- Never hardcode or auto-log secrets. Auto-generated keys must stay stable
  across upgrades (the `lookup`-based reuse in `secret.yaml`).
- Do not reimplement subordinate services (NATS, LiveKit). Wire to their
  upstream charts as optional dependencies and pin versions in `Chart.yaml`.
- The chart never creates cluster-scoped prerequisites it does not own: no CRDs,
  no GatewayClass, no cert-manager Issuer/ClusterIssuer. It references them, and
  `fail`s with a clear message when a required reference is missing — see
  `gateway.yaml`, `httproute.yaml`, `certificate.yaml`.
- Bump `version` in `Chart.yaml` (SemVer) on every functional chart change.
  Bump `appVersion` and `image.tag` together when tracking a new Chatto release.

## Tooling

```sh
# Resolve pinned dependencies (writes charts/*.tgz from Chart.lock)
helm dependency build charts/chatto

# Lint
helm lint --strict charts/chatto --set chatto.url=https://chat.example.com

# Render and eyeball key permutations
helm template chatto charts/chatto --set chatto.url=https://chat.example.com
helm template chatto charts/chatto -f charts/chatto/ci/ct-values.yaml
helm template chatto charts/chatto -f charts/chatto/ci/gateway-values.yaml

# NOTES.txt only renders on install, not template
helm install chatto charts/chatto --dry-run=client --set chatto.url=https://x

# Full CI-equivalent lint + install on kind. The gateway ci case needs the
# Gateway API and cert-manager CRDs present (no controllers required).
ct lint --config ct.yaml
ct install --config ct.yaml   # requires a kind cluster
```

When changing NATS wiring, always render and confirm: `CHATTO_NATS_CLIENT_URL`,
`CHATTO_NATS_REPLICAS`, the auth method, and that the shared token resolves from
the `natsAuth` Secret in both the NATS pod and the Chatto pod.

The `ci/*.yaml` files are the test suite: `ct install` installs each one onto a
kind cluster. Every new templated resource should be reachable from at least one
of them. `examples/*.yaml` are documentation, validated by rendering only.

## Conventions

- Conventional Commits (e.g. `feat(chart): ...`, `fix(nats): ...`,
  `docs: ...`). Mark breaking value changes with `!`.
- Keep the chart README's values table in sync with `values.yaml`.
- New optional dependencies get a `condition:` and default to disabled unless
  they are required for a working install.
