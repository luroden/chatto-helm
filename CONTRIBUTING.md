# Contributing

Thanks for helping improve the Chatto Helm chart!

## Ground rules

- This chart is community-maintained and unofficial (see [NOTICE](NOTICE)).
- Read [AGENTS.md](AGENTS.md) — it captures the design constraints (stateless
  Chatto, NATS JetStream as the data store, `CHATTO_NATS_REPLICAS` semantics,
  health endpoints, secret handling) that changes must preserve.

## Local development

```sh
# Pull pinned dependencies
helm dependency build charts/chatto

# Lint
helm lint --strict charts/chatto --set chatto.url=https://chat.example.com

# Render the permutations you touched
helm template chatto charts/chatto --set chatto.url=https://chat.example.com
helm template chatto charts/chatto --set chatto.url=https://x --set nats.enabled=false --set externalNats.url=nats://n:4222
helm template chatto charts/chatto -f charts/chatto/ci/ct-values.yaml
helm template chatto charts/chatto -f charts/chatto/ci/gateway-values.yaml
```

Full lint + install on a throwaway cluster (mirrors CI). The Gateway API and
cert-manager CRDs are needed for `ci/gateway-values.yaml`; their controllers are
not, because nothing in the smoke test routes through them:

```sh
kind create cluster
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.crds.yaml
ct lint --config ct.yaml
ct install --config ct.yaml
```

## Pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit
  and PR titles (`feat(chart):`, `fix(nats):`, `docs:`; `!` for breaking value
  changes).
- **Bump `version` in `charts/chatto/Chart.yaml`** (SemVer) for any functional
  change — CI enforces version increments.
- Keep `values.yaml` comments and the README in sync with behavior.
- New configuration should map cleanly onto a documented `CHATTO_*` env var.

## Releasing

Maintainers publish by pushing a tag `chatto-v<chart version>` (e.g.
`chatto-v0.1.0`). The [release workflow](.github/workflows/release.yaml)
packages the chart and pushes it to `oci://ghcr.io/luroden/charts/chatto`.
