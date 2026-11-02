#!/usr/bin/env bash
# Tap "Wait" on an ANR dialog so we keep the Flutter VM attached.
# NEVER tap "Close app" while flutter run is attached.
set -euo pipefail
export PATH="${ANDROID_HOME:-/home/box/Android/Sdk}/platform-tools:${PATH:-}"
DUMP=/sdcard/_anr_ui.xml
adb shell uiautomator dump "$DUMP" >/dev/null
adb pull "$DUMP" /tmp/_anr_ui.xml >/dev/null
python3 - <<'PY'
import re, subprocess
xml=open('/tmp/_anr_ui.xml').read()
# Prefer exact Wait button
m=re.search(r'text="Wait"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml)
if not m:
    m=re.search(r'text="等待"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml)
if not m:
    raise SystemExit('no Wait button found')
x1,y1,x2,y2=map(int,m.groups())
x,y=(x1+x2)//2,(y1+y2)//2
print(f'tapping Wait at {x},{y}')
subprocess.check_call(['adb','shell','input','tap',str(x),str(y)])
PY
