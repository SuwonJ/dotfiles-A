#!/usr/bin/env bash

set -u

API_URL="http://openapi.seoul.go.kr:8088/sample/xml/RealtimeCityAir/1/5/%20/%EA%B4%80%EC%95%85%EA%B5%AC/"

xml="$(curl -fsS --max-time 5 "$API_URL" 2>/dev/null || true)"
if [[ -z "$xml" ]]; then
  echo "AQI 연결실패"
  exit 0
fi

pm10="$(printf '%s' "$xml" | xmllint --xpath 'string(//row/PM)' - 2>/dev/null || true)"
pm25="$(printf '%s' "$xml" | xmllint --xpath 'string(//row/FPM)' - 2>/dev/null || true)"
grade="$(printf '%s' "$xml" | xmllint --xpath 'string(//row/CAI_GRD)' - 2>/dev/null || true)"

if [[ -z "$pm10" || -z "$pm25" || -z "$grade" ]]; then
  echo "AQI 데이터없음"
  exit 0
fi

echo "관악 $grade · PM10 $pm10 · PM2.5 $pm25"
