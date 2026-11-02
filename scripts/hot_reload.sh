#!/usr/bin/env bash
# One-shot hot reload / hot restart for the box flutter session.
#
# Usage:
#   scripts/hot_reload.sh          # hot reload (USR1) — default
#   scripts/hot_reload.sh reload   # same
#   scripts/hot_reload.sh restart  # hot restart (USR2)
#
# Requires: flutter run started with --pid-file (see scripts/dev_box.sh).
# NEVER use `adb shell am force-stop` while flutter is attached — that kills
# the Dart VM and causes "Lost connection to device". Prefer this script,
# or type `r` / `R` in the flutter run TTY.
set -euo pipefail

PID_FILE="${FLUTTER_PID_FILE:-/tmp/howtocook_flutter.pid}"
LOG_FILE="${FLUTTER_RUN_LOG:-/tmp/howtocook_flutter_run.log}"
MODE="${1:-reload}"

if [ ! -f "$PID_FILE" ]; then
  echo "[hot_reload] missing pid file: $PID_FILE" >&2
  echo "[hot_reload] start a session first: scripts/dev_box.sh" >&2
  exit 1
fi

PID="$(tr -d '[:space:]' < "$PID_FILE")"
if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
  echo "[hot_reload] flutter pid '$PID' is not running (Lost connection?)." >&2
  echo "[hot_reload] restart flutter only (keep emulator): scripts/dev_box.sh --flutter-only" >&2
  exit 1
fi

case "$MODE" in
  reload|r|hot-reload)
    SIG=USR1
    EXPECT='Reloaded'
    LABEL='hot reload'
    ;;
  restart|R|hot-restart)
    SIG=USR2
    EXPECT='Restarted'
    LABEL='hot restart'
    ;;
  *)
    echo "usage: $0 [reload|restart]" >&2
    exit 2
    ;;
esac

# Mark log position so we wait for a NEW match, not a stale one.
MARK="$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)"
echo "[hot_reload] sending SIG$SIG → pid $PID ($LABEL)"
kill -"$SIG" "$PID"

# Wait up to ~3 min (TCG reassemble can be slow).
for i in $(seq 1 90); do
  if [ -f "$LOG_FILE" ]; then
    NEW="$(tail -c +"$((MARK + 1))" "$LOG_FILE" 2>/dev/null || true)"
    if printf '%s' "$NEW" | grep -q "$EXPECT"; then
      printf '%s\n' "$NEW" | grep -E "$EXPECT|Lost connection|Error" | tail -5
      echo "[hot_reload] ok ($LABEL) after ~$((i * 2))s"
      exit 0
    fi
    if printf '%s' "$NEW" | grep -qi 'Lost connection'; then
      echo "[hot_reload] Lost connection — do NOT force-stop; run: scripts/dev_box.sh --flutter-only" >&2
      exit 1
    fi
  fi
  sleep 2
done

echo "[hot_reload] timed out waiting for '$EXPECT' in $LOG_FILE" >&2
tail -40 "$LOG_FILE" 2>/dev/null || true
exit 1
