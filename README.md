# Athinex Installer

The compiled Athinex installer — one binary that deploys and operates the whole
platform on a single Linux host: system packages, configuration, containers,
database migrations, the service unit, TLS certificates, and a health check that
proves the result actually works.

| | |
|---|---|
| **Version** | `v2.0.0` |
| **Built** | `2026-09-04T11:30:13Z` from `f6a642b` |
| **Platform** | linux/amd64 |
| **Download** | [`athinex-linux-amd64.gz`](athinex-linux-amd64.gz) (12.8 MB, 38.4 MB unpacked) |

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
30802c9021ea796cb91936a40302ba5ff0e2ac36f4e0b174f0624c73d468d7cf  athinex-linux-amd64.gz
43efcd3db9e24f3d370e85978e78fc51b326ff22492cb08a1b04f0ad1f184b3b  athinex-linux-amd64
```

</details>

## Before you deploy

- **OS** — Ubuntu or Debian, linux/amd64.
- **Size** — 4 vCPU / 16 GB RAM (32 GB recommended) / 60 GB disk. Add ~4 GB RAM
  and 15 GB disk for the deep assessment add-on, ~500 MB disk for monitoring.
- **Network** — outbound access to apt package repositories and the Docker
  registry is required for install and update. Ports 80 and 443 must be free wherever there is a certificate; ports
  3000 and 8000 for a deployment with no TLS. Only a Let's Encrypt certificate
  additionally needs 80/443 reachable *from the internet*, with the domain's `A`
  record already pointing at this host.
- **Credentials** — your Athinex license key, client id, and a registry token
  for the private images. Docker itself is installed for you if missing.

## Deploy

There are two separate choices: **how this host is reached** (`--mode`) and
**where its certificate comes from** (`--tls`). Run the installer without them
and it asks both.

Public server, reachable by domain name, with TLS issued automatically:

```sh
sudo athinex installer install --mode domain --host athinex.example.com
```

Private network without public DNS or inbound internet, reachable at `https://10.0.0.5` (the host still needs outbound package and Docker-registry access):

```sh
sudo athinex installer install --mode ip --host 10.0.0.5 --tls selfsigned
```

Private network, no TLS at all:

```sh
sudo athinex installer install --mode ip --host 10.0.0.5 --tls none --i-understand-no-tls
```

| `--tls` | Certificate from | Requires | In the browser |
|---|---|---|---|
| `letsencrypt` | a public authority | a domain pointing here, 80+443 reachable from the internet | trusted straight away |
| `selfsigned` | an authority created on this host | no public DNS or Let's Encrypt access | trusted once you install the authority (below) |
| `none` | — | — | plain HTTP |

Omit `--tls` and it follows the mode: `domain` gets `letsencrypt`, `ip` gets
`none`. The one combination that cannot work is an IP address with
`letsencrypt` — no public authority will issue a certificate for an address.

`--tls none` serves the login form and every API token over plain HTTP, which is
why it requires `--i-understand-no-tls`. Use it only on a network you trust.

Wherever there is a certificate, everything is reached on one address —
`https://<host>` — with the API on `/api` behind the proxy. Only `--tls none`
puts the interface on `:3000` and the API on `:8000`.

### Installing the certificate authority

With `--tls selfsigned` the installer creates a certificate authority in
`/etc/ssl/athinex/ca.crt` and signs this host's certificate with it. Browsers
will warn until that authority is installed on each machine that uses Athinex.
Copy it off the server, or download it from `http://<host>/athinex-ca.crt`, then:

```sh
# Linux
sudo cp ca.crt /usr/local/share/ca-certificates/athinex.crt && sudo update-ca-certificates

# macOS
sudo security add-trusted-cert -d -k /Library/Keychains/System.keychain ca.crt

# Windows, as Administrator
certutil -addstore -f Root ca.crt
```

Firefox keeps its own store: **Settings → Privacy & Security → Certificates →
View Certificates → Import**.

This is a one-time step per machine. The host's certificate is renewed by
`athinex installer update`, and because the same authority signs each renewal,
nobody has to import anything again.

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
  --mode ip --host 10.0.0.5 --tls selfsigned \
  --admin-email you@example.com --admin-password-file /root/admin.pw \
  --non-interactive
```

## Operate

```sh
sudo athinex installer update              # apply only what changed
sudo athinex installer update --dry-run    # what would change, and why
sudo athinex installer health              # verify the deployment; --json to script it
sudo athinex installer status              # what is installed
sudo athinex installer ssl status           # TLS source and served certificate
sudo athinex installer ssl renew            # renew only when due (within 30 days)
sudo athinex installer ssl renew --force    # explicitly reissue now
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

### SSL lifecycle

The SSL command operates on an installed deployment without pulling images:

```sh
sudo athinex installer ssl status
sudo athinex installer ssl status --json
sudo athinex installer ssl configure --tls selfsigned
sudo athinex installer ssl configure --tls letsencrypt
sudo athinex installer ssl configure --tls none --i-understand-no-tls
```

`ssl status` shows the configured and served certificate, including its issuer,
names and expiry. `ssl configure` changes only the certificate source; use
`installer install --reconfigure` to change the hostname or deployment mode.

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
| TLS issuance failed | Confirm the `A` record and that ports 80/443 are reachable, then re-run. Or use `--tls selfsigned`, which avoids public DNS and Let's Encrypt only; install/update still need outbound package and Docker-registry access. Add `--skip-tls` to deploy without a certificate for now. |
| Browser warns about the certificate | Expected with `--tls selfsigned` until the authority is installed — see [Installing the certificate authority](#installing-the-certificate-authority). If it persists afterwards, check you reached the host by the same name or address it was installed with; the certificate names exactly one. |
| Config edited on the host | `--keep-edits` preserves your edits, `--force` overwrites them. |
| Anything else | `sudo athinex installer health --json` and `--verbose` on the failing command. |

## Verifying what you downloaded

Every release records its checksums in [`VERSION.json`](VERSION.json) and
[`SHA256SUMS`](SHA256SUMS), and the commit it was built from. The binary is
built reproducibly (`CGO_ENABLED=0`, `-trimpath`), so the same source always
produces the same bytes.

---

Athinex — <https://athinex.net>
