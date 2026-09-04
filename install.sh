#!/bin/sh
#
# Athinex installer bootstrapper.
#
#   curl -fsSL https://raw.githubusercontent.com/athinexAI/athinex-installer/main/install.sh | sudo sh
#
# Downloads the compiled athinex binary, verifies its checksum and puts it in
# /usr/local/bin. It does not deploy anything — run `athinex installer install`
# afterwards, which the script prints for you.
#
# Environment:
#   DEST=/usr/local/bin/athinex   where to install
#   REF=main                      branch or tag to install from
#
set -eu

REF=${REF:-main}
BASE=${BASE:-https://raw.githubusercontent.com/athinexAI/athinex-installer/$REF}
ASSET=athinex-linux-amd64
DEST=${DEST:-/usr/local/bin/athinex}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Linux" ] || die "Athinex runs on Linux (found $(uname -s))"
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) die "only linux/amd64 is published (found $(uname -m))" ;;
esac
[ "$(id -u)" = "0" ] || die "run as root: curl -fsSL $BASE/install.sh | sudo sh"

# Show the downloader's own progress bar when stderr is a terminal — which it
# still is under `curl ... | sudo sh` — and stay silent into logs and CI.
# wget's --show-progress is GNU-only, hence the probe before trusting it.
if command -v curl >/dev/null 2>&1; then
  if [ -t 2 ]; then
    fetch() { curl -fL --progress-bar "$1" -o "$2"; }
  else
    fetch() { curl -fsSL "$1" -o "$2"; }
  fi
elif command -v wget >/dev/null 2>&1; then
  if [ -t 2 ] && wget --help 2>&1 | grep -q -- --show-progress; then
    fetch() { wget -q --show-progress -O "$2" "$1"; }
  else
    fetch() { wget -qO "$2" "$1"; }
  fi
else
  die "need curl or wget"
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  die "need sha256sum or shasum"
fi

command -v gzip >/dev/null 2>&1 || die "need gzip"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

printf 'Downloading %s (%s)...\n' "$ASSET" "$REF"
fetch "$BASE/VERSION.json" "$TMP/VERSION.json" || die "cannot reach $BASE"
fetch "$BASE/$ASSET.gz" "$TMP/$ASSET.gz" || die "cannot download $ASSET.gz"

field() { sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$TMP/VERSION.json"; }
VERSION=$(field version)
WANT_GZ=$(field sha256_gz)
WANT_BIN=$(field sha256_bin)
[ -n "$WANT_GZ" ] && [ -n "$WANT_BIN" ] || die "VERSION.json is missing checksums"

# Verified twice on purpose: the archive proves the download arrived intact, the
# binary proves decompression produced what was actually built and signed off.
GOT_GZ=$(sha256 "$TMP/$ASSET.gz")
[ "$GOT_GZ" = "$WANT_GZ" ] || die "checksum mismatch on $ASSET.gz (got $GOT_GZ, want $WANT_GZ)"

gzip -dc "$TMP/$ASSET.gz" > "$TMP/$ASSET" || die "cannot decompress $ASSET.gz"
GOT_BIN=$(sha256 "$TMP/$ASSET")
[ "$GOT_BIN" = "$WANT_BIN" ] || die "checksum mismatch on $ASSET (got $GOT_BIN, want $WANT_BIN)"

install -m 0755 "$TMP/$ASSET" "$DEST" || die "cannot write $DEST"

cat <<EOF

Installed athinex $VERSION to $DEST

Next, deploy the platform. On a public server with a domain:

  sudo athinex installer install --mode domain --host athinex.example.com

On a private network without public DNS or inbound internet, over HTTPS
(the host still needs outbound package and Docker-registry access):

  sudo athinex installer install --mode ip --host 10.0.0.5 --tls selfsigned

You will be asked for your license key, client id, registry token and the first
admin account. Full documentation:

  https://github.com/athinexAI/athinex-installer

After deployment, inspect or renew TLS with:

  sudo athinex installer ssl status
  sudo athinex installer ssl renew
EOF
