#!/bin/bash
# Start Jean's headless server on Railway. Runs as root only long enough to
# prepare the volume, then drops to the "jean" user (UID 1000) like upstream.
set -euo pipefail

log() { echo "[jean-railway] $*"; }
die() { echo "[jean-railway] ERROR: $*" >&2; exit 1; }

HOME_DIR=/home/jean
export HOME="$HOME_DIR" USER=jean LOGNAME=jean SHELL=/bin/bash

# --- Access token: required, never optional on a public URL -----------------
JEAN_TOKEN="${JEAN_TOKEN:-}"
[ -n "$JEAN_TOKEN" ] || die "JEAN_TOKEN is empty. Set it to a long random value (the template generates one)."
[ "${#JEAN_TOKEN}" -ge 24 ] || die "JEAN_TOKEN is shorter than 24 characters."
case "$JEAN_TOKEN" in *[!A-Za-z0-9._~-]*) die "JEAN_TOKEN may only contain letters, digits and . _ ~ - (it is used in URLs).";; esac
unset JEAN_NO_TOKEN JEAN_ALLOW_UNSAFE_NO_TOKEN
export JEAN_TOKEN

# --- Listener: Railway's PORT on all interfaces (IPv4 + IPv6 private network) -
export JEAN_PORT="${PORT:-3456}"
export JEAN_HOST="${JEAN_HOST:-::}"
export JEAN_HEADLESS=1

# --- Size thread pools and malloc to the service, not the host ---------------
# Railway shows every host CPU (32+) inside a 1 vCPU service.
cpus=2
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ] && [ "$period" -gt 0 ]; then
    cpus=$(( (quota + period - 1) / period ))
  fi
fi
[ "$cpus" -ge 2 ] || cpus=2
[ "$cpus" -le 8 ] || cpus=8
export TOKIO_WORKER_THREADS="${TOKIO_WORKER_THREADS:-$cpus}"
export RAYON_NUM_THREADS="${RAYON_NUM_THREADS:-$cpus}"
export MALLOC_ARENA_MAX="${MALLOC_ARENA_MAX:-2}"
export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-$cpus}"
export GOMAXPROCS="${GOMAXPROCS:-$cpus}"
log "using $cpus worker threads"

# --- Volume: Railway mounts it root-owned; Jean runs as UID 1000 -------------
mkdir -p "$HOME_DIR"
if [ "$(id -u)" = 0 ]; then
  if [ "$(stat -c %u "$HOME_DIR")" != 1000 ]; then
    log "preparing $HOME_DIR for the jean user"
    chown -R 1000:1000 "$HOME_DIR"
  fi
fi
run_as_jean() {
  if [ "$(id -u)" = 0 ]; then
    setpriv --reuid=1000 --regid=1000 --init-groups -- "$@"
  else
    "$@"
  fi
}
run_as_jean mkdir -p "$HOME_DIR/.cache" "$HOME_DIR/.config" "$HOME_DIR/.local/bin" \
  "$HOME_DIR/.local/share/com.jean.desktop" "$HOME_DIR/projects"
[ -f "$HOME_DIR/.bashrc" ] || run_as_jean cp /etc/skel/.bashrc "$HOME_DIR/.bashrc" 2>/dev/null || true
[ -f "$HOME_DIR/.profile" ] || run_as_jean cp /etc/skel/.profile "$HOME_DIR/.profile" 2>/dev/null || true

# Seed Jean's writable managed gh copy (same as upstream's entrypoint), so gh
# updates work without root. Keep an existing copy: it can be newer.
data_dir="${JEAN_DATA_DIR:-$HOME_DIR/.local/share/com.jean.desktop}"
managed_gh="$data_dir/gh-cli/gh"
if [ ! -x "$managed_gh" ]; then
  run_as_jean mkdir -p "$(dirname "$managed_gh")"
  run_as_jean install -m 0755 /usr/bin/gh "$managed_gh"
fi

cd "$HOME_DIR"
log "starting $(jean-server --version 2>/dev/null || echo jean-server) on [$JEAN_HOST]:$JEAN_PORT"
# exec keeps jean-server's exit status: any crash exits non-zero and Railway's
# ON_FAILURE restart policy brings it back.
if [ "$(id -u)" = 0 ]; then
  exec setpriv --reuid=1000 --regid=1000 --init-groups -- jean-server
fi
exec jean-server
