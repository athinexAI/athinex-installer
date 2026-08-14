# Athinex Installer

The compiled Athinex installer — one binary that deploys and operates the whole
platform on a single Linux host: system packages, configuration, containers,
database migrations, the service unit, TLS certificates, and a health check that
proves the result actually works.

| | |
|---|---|
| **Version** | `v1.0.0` |
| **Built** | `2026-08-14T23:18:34Z` from `7602285` |
| **Platform** | linux/amd64 |
| **Download** | [`athinex-linux-amd64.gz`](athinex-linux-amd64.gz) (12.5 MB, 37.3 MB unpacked) |

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/athinexAI/athinex-installer/main/install.sh | sudo sh
```

This downloads the binary, verifies its checksum and installs it to
`/usr/local/bin/athinex`. Nothing is deployed yet.

<details>
<summary>Or install by hand</summary>

```sh
curl -fsSLO https://raw.githubusercontent.com/athinexAI/athinex-installer/main/athinex-linux-amd64.gz
curl -fsSLO https://raw.githubusercontent.com/athinexAI/athinex-installer/main/SHA256SUMS
sha256sum -c SHA256SUMS
gzip -d athinex-linux-amd64.gz
sudo install -m 0755 athinex-linux-amd64 /usr/local/bin/athinex
```

Checksums for this release:

```
130ecf719121171489588fb6835fdd0ecaf8e72b794966e1e2a7208da5c207b1  athinex-linux-amd64.gz
c2a382bc1f071a5452606b60575d02803dc139c6787a6a1f475f5177960fa707  athinex-linux-amd64
```

</details>

## Before you deploy

- **OS** — Ubuntu or Debian, linux/amd64.
- **Size** — 4 vCPU / 16 GB RAM (32 GB recommended) / 60 GB disk. Add ~4 GB RAM
  and 15 GB disk for the deep assessment add-on, ~500 MB disk for monitoring.
- **Network** — ports 80 and 443 open for a domain deployment, with the domain's
  `A` record already pointing at this host; ports 3000 and 8000 for an IP
  deployment.
- **Credentials** — your Athinex license key, client id, and a registry token
  for the private images. Docker itself is installed for you if missing.

## Deploy

Public server, reachable by domain name, with TLS issued automatically:

```sh
sudo athinex installer install --mode domain --host athinex.example.com
```

Private network, reachable by IP, no reverse proxy:

```sh
sudo athinex installer install --mode ip --host 10.0.0.5 --i-understand-no-tls
```

| | `--mode domain` | `--mode ip` |
|---|---|---|
| For | a public server | on-premise, trusted network |
| Reached at | `https://<domain>` | `http://<ip>:3000` |
| Reverse proxy | yes, TLS issued for you | none |
| API | loopback only, behind the proxy | `http://<ip>:8000` |

`--mode ip` serves the login form and every API token over plain HTTP, which is
why it requires `--i-understand-no-tls`. Use it only on a network you trust.

The installer prompts for the license key, client id, registry token and admin
account, then caches them in `/etc/athinex/state.json` (mode 0600) so a retry
after a failure does not ask again. Every step checks its own postcondition, so
re-running after an interruption resumes rather than starting over.

### Optional add-ons

```sh
sudo athinex installer install --mode domain --host athinex.example.com \
  --with-gvm \        # deep network and host assessment (needs ~4 GB RAM, 15 GB disk)
  --with-monitoring   # metrics and dashboards
```

### Unattended install

Every value has a flag, a `--*-file` sibling and an environment variable. Prefer
the last two — a secret passed on the command line is readable by every user on
the host through `ps`.

```sh
export ATHINEX_LICENSE_KEY=... ATHINEX_CLIENT_ID=... ATHINEX_DOCKER_PAT=...
sudo -E athinex installer install \
  --mode ip --host 10.0.0.5 --i-understand-no-tls \
  --admin-email you@example.com --admin-password-file /root/admin.pw \
  --non-interactive
```

## Operate

```sh
sudo athinex installer update              # apply only what changed
sudo athinex installer update --dry-run    # what would change, and why
sudo athinex installer health              # verify the deployment; --json to script it
sudo athinex installer status              # what is installed
sudo athinex installer restart             # --all also restarts the scanners
sudo athinex installer stop                # stop everything; data is kept
sudo athinex installer stop --disable      # ...and do not start at boot
sudo athinex installer start               # start again, in order
sudo athinex installer uninstall           # remove the deployment; data is kept
athinex installer maintenance              # print the maintenance units to add
```

`update` compares the rendered configuration against what it last wrote, and the
local images against what it last deployed, then restarts only what those
changes require.

### Upgrading

Re-run the bootstrapper to pick up a newer release, then apply it:

```sh
curl -fsSL https://raw.githubusercontent.com/athinexAI/athinex-installer/main/install.sh | sudo sh
sudo athinex installer update
```

### Not handled for you

Scheduled maintenance — scanner content refreshes, database backups and log
rotation — is not set up automatically. `athinex installer maintenance` prints
service and timer units you can install, and `health` reports their absence as a
warning on every run so it stays visible rather than being forgotten.

## Troubleshooting

| Symptom | What to do |
|---|---|
| Install stopped partway | Re-run the same command. Completed steps are skipped. |
| A required port is taken | Add `--fix` to let the installer stop whatever holds it. |
| TLS issuance failed | Confirm the `A` record and that ports 80/443 are reachable, then re-run. Add `--skip-tls` to deploy without it for now. |
| Config edited on the host | `--keep-edits` preserves your edits, `--force` overwrites them. |
| Anything else | `sudo athinex installer health --json` and `--verbose` on the failing command. |

## Verifying what you downloaded

Every release records its checksums in [`VERSION.json`](VERSION.json) and
[`SHA256SUMS`](SHA256SUMS), and the commit it was built from. The binary is
built reproducibly (`CGO_ENABLED=0`, `-trimpath`), so the same source always
produces the same bytes.

---

Athinex — <https://athinex.ai>
