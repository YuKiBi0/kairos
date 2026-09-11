#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: bash build-ubuntu.sh [--build-only] [--skip-tests]

Builds the Kairos server and CLI into ../kairos-build. By default it then
installs/updates the server systemd service and installs the CLI system-wide.

Options:
  --build-only  Build artifacts without changing the system installation.
  --skip-tests  Skip Go tests before building.
  -h, --help    Show this help.
EOF
}

BUILD_ONLY=false
SKIP_TESTS=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only) BUILD_ONLY=true; shift ;;
    --skip-tests) SKIP_TESTS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

command -v go >/dev/null 2>&1 || { echo "Go is required" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 1; }

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the operating system; Ubuntu is required" >&2
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
if [[ ${ID:-} != "ubuntu" && " ${ID_LIKE:-} " != *" ubuntu "* ]]; then
  echo "This script supports Ubuntu only (detected: ${PRETTY_NAME:-unknown})" >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
REPO_ROOT=$SCRIPT_DIR
REPO_PARENT=$(cd -- "$REPO_ROOT/.." && pwd -P)
BUILD_ROOT=$REPO_PARENT/kairos-build
if [[ -L $BUILD_ROOT ]]; then
  echo "Refusing symlinked build directory: $BUILD_ROOT" >&2
  exit 1
fi
if [[ ! -f $REPO_ROOT/server/go.mod || ! -f $REPO_ROOT/cli/go.mod ||
      ! -f $REPO_ROOT/deploy/install.sh || ! -f $REPO_ROOT/deploy/update.sh ]]; then
  echo "build-ubuntu.sh must remain in the Kairos repository root" >&2
  exit 1
fi

case "$(uname -m)" in
  x86_64) GOARCH=amd64 ;;
  aarch64|arm64) GOARCH=arm64 ;;
  *) echo "Unsupported Ubuntu architecture: $(uname -m)" >&2; exit 1 ;;
esac

SERVER_ARTIFACT_DIR=$BUILD_ROOT/server
CLI_ARTIFACT_DIR=$BUILD_ROOT/cli
MIGRATIONS_ARTIFACT_DIR=$SERVER_ARTIFACT_DIR/migrations
SERVER_BINARY=$SERVER_ARTIFACT_DIR/kairos-server
CLI_BINARY=$CLI_ARTIFACT_DIR/kairos
ENV_FILE=$BUILD_ROOT/kairos.env
CHECKSUM_FILE=$BUILD_ROOT/SHA256SUMS

mkdir -p "$SERVER_ARTIFACT_DIR" "$CLI_ARTIFACT_DIR" "$MIGRATIONS_ARTIFACT_DIR"
chmod 0700 "$BUILD_ROOT"

replace_env_value() {
  local key=$1
  local value=$2
  local temporary
  temporary=$(mktemp "$BUILD_ROOT/.env.XXXXXX")
  awk -v key="$key" -v value="$value" '
    BEGIN { replaced = 0 }
    index($0, key "=") == 1 { print key "=" value; replaced = 1; next }
    { print }
    END { if (!replaced) print key "=" value }
  ' "$ENV_FILE" >"$temporary"
  chmod 0600 "$temporary"
  mv -f "$temporary" "$ENV_FILE"
}

generate_secret() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
  fi
}

ENV_CREATED=false
if [[ ! -f $ENV_FILE ]]; then
  if [[ -f /etc/kairos/kairos.env ]]; then
    if [[ $BUILD_ONLY == true ]]; then
      echo "Existing system environment found at /etc/kairos/kairos.env." >&2
      echo "Run without --build-only once to copy it into $ENV_FILE, or copy it manually." >&2
      exit 1
    fi
    command -v sudo >/dev/null 2>&1 || { echo "sudo is required" >&2; exit 1; }
    sudo install -m 0600 -o "$(id -u)" -g "$(id -g)" /etc/kairos/kairos.env "$ENV_FILE"
    echo "Copied the installed environment to $ENV_FILE"
  else
    install -m 0600 "$REPO_ROOT/server/.env.example" "$ENV_FILE"
    replace_env_value KAIROS_ENV production
    replace_env_value KAIROS_MIGRATIONS_DIR /opt/kairos/migrations
    replace_env_value KAIROS_SESSION_SECRET "$(generate_secret)"
    ENV_CREATED=true
  fi
fi
chmod 0600 "$ENV_FILE"

env_value() {
  local key=$1
  sed -n "s/^${key}=//p" "$ENV_FILE" | tail -n 1
}

DATABASE_URL=$(env_value KAIROS_DATABASE_URL)
SESSION_SECRET=$(env_value KAIROS_SESSION_SECRET)
ENV_INVALID=false
if [[ -z $DATABASE_URL || $DATABASE_URL == *"change-me"* || $DATABASE_URL == *"replace-with"* ]]; then
  echo "Set a production KAIROS_DATABASE_URL in $ENV_FILE" >&2
  ENV_INVALID=true
fi
if (( ${#SESSION_SECRET} < 32 )) || [[ $SESSION_SECRET == *"replace-with"* ]]; then
  echo "Set KAIROS_SESSION_SECRET to at least 32 characters in $ENV_FILE" >&2
  ENV_INVALID=true
fi
if [[ $ENV_CREATED == true ]]; then
  echo "Created $ENV_FILE"
fi
if [[ $ENV_INVALID == true ]]; then
  echo "Environment initialization is incomplete. Edit the file and rerun this command." >&2
  exit 2
fi

if [[ $SKIP_TESTS == false ]]; then
  echo "Running CLI tests..."
  (cd "$REPO_ROOT/cli" && go test ./...)
  echo "Running server tests..."
  (cd "$REPO_ROOT/server" && go test ./...)
fi

STAGE_DIR=$(mktemp -d "$BUILD_ROOT/.stage.XXXXXX")
cleanup() {
  case "$STAGE_DIR" in
    "$BUILD_ROOT"/.stage.*) rm -rf -- "$STAGE_DIR" ;;
  esac
}
trap cleanup EXIT

echo "Building linux/$GOARCH server..."
(
  cd "$REPO_ROOT/server"
  CGO_ENABLED=0 GOOS=linux GOARCH=$GOARCH \
    go build -trimpath -ldflags='-s -w' -o "$STAGE_DIR/kairos-server" ./cmd/kairos-server
)
echo "Building linux/$GOARCH CLI..."
(
  cd "$REPO_ROOT/cli"
  CGO_ENABLED=0 GOOS=linux GOARCH=$GOARCH \
    go build -trimpath -ldflags='-s -w' -o "$STAGE_DIR/kairos" ./cmd/kairos
)

install -m 0755 "$STAGE_DIR/kairos-server" "$SERVER_BINARY"
install -m 0755 "$STAGE_DIR/kairos" "$CLI_BINARY"
find "$REPO_ROOT/server/migrations" -maxdepth 1 -type f -name '*.sql' -exec \
  install -m 0644 {} "$MIGRATIONS_ARTIFACT_DIR/" \;
(
  cd "$BUILD_ROOT"
  sha256sum server/kairos-server cli/kairos >"$CHECKSUM_FILE"
)

echo "Artifacts ready in $BUILD_ROOT"
echo "  server: $SERVER_BINARY"
echo "  CLI:    $CLI_BINARY"
echo "  env:    $ENV_FILE"

if [[ $BUILD_ONLY == true ]]; then
  exit 0
fi

command -v sudo >/dev/null 2>&1 || { echo "sudo is required for system installation" >&2; exit 1; }
command -v systemctl >/dev/null 2>&1 || { echo "systemd is required for system installation" >&2; exit 1; }
sudo -v

if sudo test -x /opt/kairos/bin/kairos-server && \
   sudo test -f /etc/kairos/kairos.env && \
   sudo test -f /etc/systemd/system/kairos-server.service; then
  echo "Updating the installed Kairos server..."
  sudo "$REPO_ROOT/deploy/update.sh" \
    --binary "$SERVER_BINARY" \
    --env-file "$ENV_FILE" \
    --migrations "$MIGRATIONS_ARTIFACT_DIR"
else
  echo "Installing the Kairos server..."
  sudo "$REPO_ROOT/deploy/install.sh" \
    --binary "$SERVER_BINARY" \
    --env-file "$ENV_FILE" \
    --migrations "$MIGRATIONS_ARTIFACT_DIR"
fi

sudo install -m 0755 -o root -g root "$CLI_BINARY" /usr/local/bin/kairos
sudo systemctl daemon-reload
sudo systemctl enable --now kairos-server.service
sudo systemctl --quiet is-active kairos-server.service

echo "System installation updated successfully."
echo "  service: $(sudo systemctl is-active kairos-server.service)"
echo "  CLI:     /usr/local/bin/kairos"
echo "  health:  curl --fail http://127.0.0.1:8080/readyz"
