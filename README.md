# Athinex Installer

The compiled Athinex installer — one binary that deploys and operates the whole
platform on a single Linux host: system packages, configuration, containers,
database migrations, the service unit, TLS certificates, and a health check that
proves the result actually works.

| | |
|---|---|
| **Version** | `v2.1.1` |
| **Built** | `2026-10-06T12:56:47Z` from `57194ff` |
| **Platform** | linux/amd64 |
| **Download** | [`athinex-linux-amd64.gz`](athinex-linux-amd64.gz) (12.5 MB, 37.2 MB unpacked) |



## Install

Four steps, the same on every host. Steps 2 and 3 only apply the first time
you install from a root login. Skip them when you already work from a non-root
account with sudo.

### 1. Download the installer

```sh
curl -fsSL https://raw.githubusercontent.com/athinexAI/athinex-installer/main/install.sh | sudo sh
```

This downloads the binary, verifies its checksum and installs it to
`/usr/local/bin/athinex`. Nothing is deployed yet. From a root login, drop the
`sudo`.

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
c49a45123945ea7648024458f2c5d71a930f965a45d30791d1d8c60f7801bd5a  athinex-linux-amd64.gz
59df119c36dab53a997235452e8e7a1b0a185c8331861604a2460fbd94fd4a89  athinex-linux-amd64
```

</details>

### 2. Create the operator account (root login only)

Athinex is deployed by a non-root account through sudo, never by root itself.
On a fresh server where you are logged in as `root`, run:

```sh
athinex installer install
```

It creates an `athinex` account with sudo rights, prints its password **once**,
then stops without deploying anything:

```
Created sudo user athinex.
  Password: k7mq-3vxp-9tdr-h2wn
  Save this password; it will not be shown again.
```

Save the password: `sudo` asks for it in step 4. If it is lost, set a new one as
root with `passwd athinex`. To use an existing account instead, pass
`--user <name>` (it must be a non-root account that already exists).

### 3. Log in as that account

```sh
su - athinex
```

### 4. Deploy

Choose **how this host is reached** (`--mode`) and **where its certificate comes
from** (`--tls`). Leave them out and the installer asks.

Public server with a domain name, TLS issued automatically:

```sh
sudo athinex installer install --mode domain --host athinex.example.com
```

Server reached by IP address, over HTTPS (the usual choice without a domain):

```sh
sudo athinex installer install --mode ip --host 203.0.113.10 --tls selfsigned
```

Private network, no TLS at all:

```sh
sudo athinex installer install --mode ip --host 10.0.0.5 --tls none --i-understand-no-tls
```

The installer then asks for:

- your **license key** and **client id**, verified online straight away
- the **registry token**, fetched for you from your license (only asked if that fails)
- the **first admin account**: email and password

It checks the host, shows the plan and waits for your confirmation before it
changes anything. Add `--dry-run` to see the plan without changing anything.

The installer caches your answers in `/etc/athinex/state.json` (mode 0600) so a retry
after a failure does not ask again. Every step checks its own postcondition, so
re-running after an interruption resumes rather than starting over.

When it finishes, open `https://<host>` (or `http://<host>:3000` with
`--tls none`) and sign in with the admin account. Then confirm everything is
healthy:

```sh
sudo athinex installer health
```

## Before you deploy

- **OS**: Ubuntu or Debian, linux/amd64.
- **Size**: 4 vCPU / 6 GB RAM (32 GB recommended) / 60 GB disk. The
  vulnerability assessment product adds ~4 GB RAM and ~15 GB disk for its
  scanner; monitoring adds ~500 MB disk.
- **Network**: outbound HTTPS to apt repositories, the Athinex registry
  (`registry.athinex.net`), Docker Hub and its CDN, and the Athinex licensing
  service, for both install and update. The Athinex images are pulled with
  your license: no registry account or token is needed. Ports 80 and 443 must be free
  wherever there is a certificate; ports 3000 and 8000 for a deployment with no
  TLS. Only a Let's Encrypt certificate additionally needs 80/443 reachable
  *from the internet*, with the domain's `A` record already pointing at this host.
- **Credentials**: your Athinex license key and client id. Docker itself is
  installed for you if missing.

## Licensing and products

Installation requires a valid, active license. Invalid credentials, an expired
or inactive license and an unreachable licensing service all stop the install;
there is no bypass.

The installer deploys **only the products your license includes**, and only
the services they need: the assessment scanner, for example, is installed only
when the vulnerability assessment product is licensed. It prints what it found
before planning:

```
products: asm, darkweb, webscan (from the licensing cloud); ...
```

- **Adding a product later**: an admin activates it from the web interface. The
  activation agent (`athinex-agent.service`, installed for you) runs the update
  on the host and streams its output back to the page; nothing to run by hand.
  `sudo athinex installer update` does the same from the shell.
- **A host that cannot reach the licensing service** can be given a signed
  license file instead: `--license-file /path/to/license`.
- **A different licensing environment** (for example a staging one) is set with
  `--license-guard-url https://...`. The default is `https://app.athinex.net`.

## Deploy options

| `--tls` | Certificate from | Requires | In the browser |
|---|---|---|---|
| `letsencrypt` | a public authority | a domain pointing here, 80+443 reachable from the internet | trusted straight away |
| `selfsigned` | an authority created on this host | no public DNS or Let's Encrypt access | trusted once you install the authority (below) |
| `none` | | | plain HTTP |

Omit `--tls` and it follows the mode: `domain` gets `letsencrypt`, `ip` gets
`none`. The one combination that cannot work is an IP address with
`letsencrypt`, since no public authority issues a certificate for an address.

`--tls none` serves the login form and every API token over plain HTTP, which is
why it requires `--i-understand-no-tls`. Use it only on a network you trust.

Wherever there is a certificate, everything is reached on one address,
`https://<host>`, with the API on `/api` behind the proxy. Only `--tls none`
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

### Optional monitoring

```sh
sudo athinex installer install --mode domain --host athinex.example.com \
  --with-monitoring
```

Adds metrics and dashboards. Grafana listens on `127.0.0.1:3002` only; reach it
over an SSH tunnel (`ssh -L 3002:127.0.0.1:3002 <user>@<host>`).

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
sudo athinex installer health --fix        # repair what it can, then re-check
sudo athinex installer status              # what is installed
sudo athinex installer ssl status           # TLS source and served certificate
sudo athinex installer ssl renew            # renew only when due (within 30 days)
sudo athinex installer ssl renew --force    # explicitly reissue now
sudo athinex installer logs                # recent logs; -f to follow, --since 30m
sudo athinex installer logs api            # one service only
sudo athinex installer restart             # restart every service
sudo athinex installer stop                # stop everything; data is kept
sudo athinex installer stop --disable      # ...and do not start at boot
sudo athinex installer start               # start again, in order
sudo athinex installer uninstall           # remove the deployment; data is kept
sudo athinex installer reset               # DELETE all Athinex data, ready to reinstall
sudo athinex installer refresh-templates   # refresh the vulnerability scan templates
athinex installer maintenance              # print the maintenance units to add
```

`update` compares the rendered configuration against what it last wrote, and the
local images against what it last deployed, then restarts only what those
changes require.

If an update fails or is interrupted, re-run the same command (including options
such as `--keep-edits`). Unfinished actions are retried automatically, and the
update is only complete after configuration and health checks succeed. Even an
update with no changes checks health before reporting that it is up to date.
After a successful image update, superseded Athinex image IDs are removed to
reclaim disk space. Cleanup is exact and non-forced: unrelated images and any
image still used by another container remain untouched. The cleanup section
lists each old container and image that was removed, and identifies any image
Docker retained because it is still in use.

To reapply services and extract the host binary after a failure from an older
installer that did not record unfinished actions, run
`sudo athinex installer update --keep-edits --restart-all`.

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
| Install stops right away saying a sudo user was created or already exists | You ran it as root. Run `su - athinex`, then repeat the install with `sudo`. See [step 2](#2-create-the-operator-account-root-login-only). |
| Lost the `athinex` password | As root: `passwd athinex`. |
| "The license service does not recognise this key and client id" | Check both values. With a non-default licensing environment, check `--license-guard-url`. |
| `products: no product license` | The license lists no products for this installation. Contact Athinex support; the platform installs without products until it does. |
| A required port is taken | Add `--fix` to let the installer stop whatever holds it. |
| TLS issuance failed | Confirm the `A` record and that ports 80/443 are reachable, then re-run. Or use `--tls selfsigned`, which avoids public DNS and Let's Encrypt only; install/update still need outbound package and Docker-registry access. Add `--skip-tls` to deploy without a certificate for now. |
| Browser warns about the certificate | Expected with `--tls selfsigned` until the authority is installed — see [Installing the certificate authority](#installing-the-certificate-authority). If it persists afterwards, check you reached the host by the same name or address it was installed with; the certificate names exactly one. |
| Config edited on the host | `--keep-edits` preserves your edits, `--force` overwrites them. |
| Anything else | `sudo athinex installer health --json`, `sudo athinex installer logs`, and `--verbose` on the failing command. |

## Verifying what you downloaded

Every release records its checksums in [`VERSION.json`](VERSION.json) and
[`SHA256SUMS`](SHA256SUMS), and the commit it was built from. The binary is
built reproducibly (`CGO_ENABLED=0`, `-trimpath`), so the same source always
produces the same bytes.

---

Athinex — <https://athinex.net>
