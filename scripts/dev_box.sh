#!/usr/bin/env bash
# HowToCook-mobile box/dev loop: AVD (TCG) + flutter run with hot reload.
#
# Nested KVM on this host triggers a kernel BUG — keep -accel off (TCG).
#
# Usage:
#   scripts/dev_box.sh                 # start AVD if needed + flutter run
#   scripts/dev_box.sh --flutter-only  # only (re)start flutter; keep emulator
#   scripts/hot_reload.sh              # hot reload attached session (USR1)
#   scripts/hot_reload.sh restart      # hot restart (USR2)
#
# Hot reload rules (IMPORTANT):
#   - Prefer: scripts/hot_reload.sh  OR type `r`/`R` in the flutter TTY
#   - Prefer: kill -USR1 "$(cat /tmp/howtocook_flutter.pid)"  (reload)
#             kill -USR2 "$(cat /tmp/howtocook_flutter.pid)"  (restart)
#   - NEVER:  adb shell am force-stop com.howtocook.how_to_cook
#             (force-stop kills the Dart VM → "Lost connection to device")
#   - If Lost connection: restart flutter only (--flutter-only). Do not kill
#     the emulator unless it is wedged; reinstall only when needed — prefer
#     already-installed debug APK + hot restart.
#
# Env knobs:
#   AVD_NAME, EMU_ACCEL (default off), EMU_GPU, EMU_MEMORY (default 3072),
#   EMU_CORES (default 4), EMU_WINDOW=1, EMU_EXTRA_ARGS, EMU_LOG,
#   FLUTTER_PID_FILE, FLUTTER_RUN_LOG
set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/home/box/development/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-/home/box/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$JAVA_HOME/bin:/home/box/development/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:/home/box/bin:${PATH:-}"

AVD_NAME="${AVD_NAME:-howtocook_api34}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Nested KVM is broken on this host (dmesg: kvm_spurious_fault). Prefer TCG.
EMU_ACCEL="${EMU_ACCEL:-off}"
EMU_GPU="${EMU_GPU:-swiftshader_indirect}"
# Guest RAM/cores: raise from the old 1536/2 defaults to cut TCG ANRs.
# Host must have headroom (TCG RSS ≈ guest + overhead). Override if tight.
EMU_MEMORY="${EMU_MEMORY:-3072}"
EMU_CORES="${EMU_CORES:-4}"
EMU_LOG="${EMU_LOG:-/tmp/howtocook-emulator.log}"
# Headless by default; set EMU_WINDOW=1 to show UI when DISPLAY works
EMU_WINDOW="${EMU_WINDOW:-0}"
FLUTTER_PID_FILE="${FLUTTER_PID_FILE:-/tmp/howtocook_flutter.pid}"
FLUTTER_RUN_LOG="${FLUTTER_RUN_LOG:-/tmp/howtocook_flutter_run.log}"
PACKAGE_ID="${PACKAGE_ID:-com.howtocook.how_to_cook}"

FLUTTER_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --flutter-only|-f) FLUTTER_ONLY=1 ;;
    -h|--help)
      sed -n '2,35p' "$0"
      exit 0
      ;;
  esac
done

if [ -e /dev/kvm ] && [ ! -w /dev/kvm ]; then
  sudo -n chmod 666 /dev/kvm 2>/dev/null || true
fi

have_emulator_device() {
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/' | grep -q .
}

boot_completed() {
  local s
  s="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  [ "$s" = "1" ]
}

tune_device() {
  # Keep screen on, kill animations (TCG + animations = ANR soup).
  adb shell svc power stayon true >/dev/null 2>&1 || true
  adb shell settings put global window_animation_scale 0 >/dev/null 2>&1 || true
  adb shell settings put global transition_animation_scale 0 >/dev/null 2>&1 || true
  adb shell settings put global animator_duration_scale 0 >/dev/null 2>&1 || true
  adb shell settings put system screen_off_timeout 1800000 >/dev/null 2>&1 || true
  echo "[dev_box] device tuned: stayon + animations=0"
}

start_emulator() {
  echo "[dev_box] Starting AVD: $AVD_NAME (accel=$EMU_ACCEL gpu=$EMU_GPU memory=$EMU_MEMORY cores=$EMU_CORES)"
  WINDOW_ARGS=(-no-window)
  if [ "$EMU_WINDOW" = "1" ] && [ -n "${DISPLAY:-}" ]; then
    WINDOW_ARGS=()
  fi
  # shellcheck disable=SC2086
  nohup emulator -avd "$AVD_NAME" \
    -accel "$EMU_ACCEL" \
    -gpu "$EMU_GPU" \
    -memory "$EMU_MEMORY" \
    -cores "$EMU_CORES" \
    -no-snapshot \
    -no-boot-anim \
    -no-audio \
    "${WINDOW_ARGS[@]}" \
    ${EMU_EXTRA_ARGS:-} \
    >"$EMU_LOG" 2>&1 &
  echo $! > /tmp/howtocook-emulator.pid
  echo "[dev_box] emulator pid=$(cat /tmp/howtocook-emulator.pid), log=$EMU_LOG"
}

wait_boot() {
  echo "[dev_box] Waiting for adb device (TCG first boot can take ~10 min)..."
  adb wait-for-device
  echo "[dev_box] Waiting for boot completed..."
  for i in $(seq 1 240); do
    if boot_completed; then
      echo "[dev_box] Boot completed"
      return 0
    fi
    if [ -f /tmp/howtocook-emulator.pid ] && ! kill -0 "$(cat /tmp/howtocook-emulator.pid)" 2>/dev/null; then
      if ! pgrep -f "qemu-system.*${AVD_NAME}|qemu-system-x86_64" >/dev/null; then
        echo "[dev_box] Emulator process exited early; last log:"
        tail -50 "$EMU_LOG" || true
        exit 1
      fi
    fi
    if [ $((i % 12)) -eq 0 ]; then
      echo "[dev_box] still booting... (${i}/240) adb=$(adb devices | awk '/emulator-/{print $2}')"
    fi
    sleep 5
    if [ "$i" -eq 240 ]; then
      echo "[dev_box] Timeout waiting for boot; adb devices:"
      adb devices -l || true
      tail -80 "$EMU_LOG" || true
      exit 1
    fi
  done
}

stop_flutter_session() {
  # Soft-stop previous flutter run so we can reattach. Do NOT force-stop the app.
  if [ -f "$FLUTTER_PID_FILE" ]; then
    local old
    old="$(tr -d '[:space:]' < "$FLUTTER_PID_FILE" || true)"
    if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
      echo "[dev_box] stopping previous flutter run pid=$old (SIGTERM; app left running)"
      kill -TERM "$old" 2>/dev/null || true
      for _ in $(seq 1 20); do
        kill -0 "$old" 2>/dev/null || break
        sleep 0.5
      done
      kill -KILL "$old" 2>/dev/null || true
    fi
  fi
}

run_flutter() {
  cd "$REPO_DIR"
  echo "[dev_box] flutter pub get..."
  flutter pub get
  echo "[dev_box] flutter devices:"
  flutter devices
  # Prefer already-installed debug package when present (faster on TCG).
  if adb shell pm path "$PACKAGE_ID" >/dev/null 2>&1; then
    echo "[dev_box] $PACKAGE_ID already installed — flutter run will reuse/update as needed"
  fi
  echo "[dev_box] flutter run (debug). Hot reload: scripts/hot_reload.sh  or  kill -USR1 \$(cat $FLUTTER_PID_FILE)"
  echo "[dev_box] NEVER am force-stop $PACKAGE_ID while attached."
  # pid-file enables headless USR1/USR2 (see scripts/hot_reload.sh).
  # Caller may redirect stdout/stderr to $FLUTTER_RUN_LOG; we also append a
  # small banner so the log path stays discoverable when run under nohup.
  echo "[dev_box] logging hint: redirect to $FLUTTER_RUN_LOG when headless" | tee -a "$FLUTTER_RUN_LOG"
  # Prefer a stable serial when present; fall back to flutter's default.
  DEVICE_ARG=()
  if adb devices 2>/dev/null | awk 'NR>1 && $2=="device" && $1=="emulator-5554"' | grep -q .; then
    DEVICE_ARG=(-d emulator-5554)
  fi
  exec flutter run --debug "${DEVICE_ARG[@]}" --pid-file "$FLUTTER_PID_FILE"
}

# --- main ---
if [ "$FLUTTER_ONLY" = "1" ]; then
  if ! have_emulator_device || ! boot_completed; then
    echo "[dev_box] --flutter-only requires a booted emulator; starting AVD first..."
    if ! have_emulator_device; then
      start_emulator
    fi
    wait_boot
  fi
  tune_device
  stop_flutter_session
  # Clear stale "Lost connection" noise by rotating the log marker.
  : >> "$FLUTTER_RUN_LOG"
  run_flutter
fi

if ! have_emulator_device; then
  start_emulator
fi
wait_boot
tune_device
stop_flutter_session
run_flutter
