# gluetun

gluetun on the shared [alpine-base](https://github.com/Rake-Pro/alpine-base) image, built in-house from the upstream release.

```
ghcr.io/rake-pro/gluetun
```

## Tags / releases

| Tag | Meaning |
| --- | --- |
| `X.Y.Z` | Immutable release, built from git tag `vX.Y.Z` |
| `X.Y` | Latest patch of that minor |
| `latest` | Latest release |
| `<upstream-version>` | The exact upstream gluetun version baked into that release (currently `v3.41.3`) |
| `sha-<short>` | Commit the image was built from |

- `dev` is the integration branch (default); `ci.yml` builds, smoke-tests and Trivy-scans on every push and PR.
- `version-check.yml` polls upstream daily and opens a PR into `dev` bumping the pinned `VERSION` build arg.
- `sync-main.yml` opens a promotion PR from `dev` to `main`. Merging it (merge commit) mints the next patch tag and `release.yml` builds, scans and pushes the image. A fixable CRITICAL finding blocks the push.
- Label the promotion PR `release:minor` or `release:major` to change the bump.
- `trivy-rescan.yml` re-scans the released image weekly (CRITICAL+HIGH) so CVEs disclosed after release still surface.
- Dependabot bumps the base image digest and the GitHub Actions weekly.
- Pin `X.Y.Z` in deployments; `latest` is a convenience pointer.

## Image facts

| Item | Value |
| --- | --- |
| Base | `ghcr.io/rake-pro/alpine-base` (Alpine, patched weekly) |
| Init | `catatonit` as PID 1 |
| User | root (needs `NET_ADMIN`) |
| Data | `/gluetun` (servers.json, auth config) |
| Port | `8000` |
| Upstream | <https://github.com/qdm12/gluetun> |
| Upstream version | `v3.41.3` (build arg `VERSION`) |
| Platform | linux/amd64 |

## Run

```
docker run -d --name gluetun \
  --cap-add NET_ADMIN \
  -e VPN_SERVICE_PROVIDER=<provider> -e VPN_TYPE=wireguard \
  -e WIREGUARD_PRIVATE_KEY=<key> -e WIREGUARD_ADDRESSES=<addr> \
  ghcr.io/rake-pro/gluetun:latest
```

- Configuration is upstream's, verbatim: see the [gluetun wiki](https://github.com/qdm12/gluetun-wiki).

## Notes

- Runs as root with `NET_ADMIN`, as upstream requires for the tunnel and firewall.
- Built from the upstream release tag with the Go toolchain pinned in the Dockerfile; Dependabot bumps the Go image and the base digest weekly.
- The legacy OpenVPN 2.5 binary (Alpine 3.17 package upstream) is not included; `OPENVPN_VERSION=2.6` is the default and the only supported value here.
