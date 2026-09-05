#!/usr/bin/env bash

set -u

if ! command -v gcalcli >/dev/null 2>&1; then
  printf '{"text":"GCal 미연결","tooltip":"gcalcli 설치 후: gcalcli agenda"}\n'
  exit 0
fi

start="$(date '+%Y-%m-%d %H:%M')"
end="$(date -d '+2 days' '+%Y-%m-%d %H:%M')"

raw="$(gcalcli --nocolor agenda "$start" "$end" 2>/dev/null || true)"
if [[ -z "$raw" ]]; then
  printf '{"text":"GCal 없음","tooltip":"로그인/권한 확인: gcalcli agenda"}\n'
  exit 0
fi

if printf '%s' "$raw" | grep -qi "Not yet authenticated"; then
  printf '{"text":"GCal 인증필요","tooltip":"터미널에서 실행: gcalcli init"}\n'
  exit 0
fi

events="$(printf '%s\n' "$raw" | sed '/^[[:space:]]*$/d' | sed 's/[[:space:]]\+$//' | head -n 4)"
title="$(printf '%s\n' "$events" | head -n 1 | sed 's/"/\\"/g')"
tip="$(printf '%s\n' "$events" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')"

if [[ -z "$title" ]]; then
  printf '{"text":"GCal 일정 없음","tooltip":"다음 2일 내 일정 없음"}\n'
  exit 0
fi

printf '{"text":"%s","tooltip":"%s"}\n' "$title" "$tip"
