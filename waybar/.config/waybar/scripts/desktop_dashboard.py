#!/usr/bin/env python3
import datetime as dt
import json
import subprocess
from pathlib import Path

DAYS = ["mon", "tue", "wed", "thu", "fri"]
KOR = {"mon": "월", "tue": "화", "wed": "수", "thu": "목", "fri": "금"}

EVENTS = [
    ("mon", "09:00", "10:50", "프로그래밍기초1"),
    ("tue", "09:00", "10:15", "이산수학"),
    ("tue", "15:00", "16:15", "대학기초영어"),
    ("tue", "18:00", "19:15", "음향의이해와활용"),
    ("wed", "09:00", "09:50", "비판적사고와학술적글쓰기"),
    ("wed", "10:00", "10:50", "비판적사고와학술적글쓰기"),
    ("wed", "11:00", "11:50", "컴퓨팅적사고와활용"),
    ("wed", "12:00", "12:50", "컴퓨팅적사고와활용"),
    ("wed", "13:30", "14:20", "비전채플"),
    ("wed", "15:00", "15:50", "프로그래밍기초1"),
    ("wed", "16:00", "16:50", "프로그래밍기초1"),
    ("thu", "09:00", "10:15", "이산수학"),
    ("thu", "15:00", "16:15", "대학기초영어"),
    ("thu", "18:00", "19:15", "음향의이해와활용"),
    ("fri", "09:00", "10:15", "기초AI수학"),
    ("fri", "10:30", "11:45", "기초AI수학"),
    ("fri", "12:00", "13:50", "AI미래사회와인문학"),
]


def t2m(s: str) -> int:
    h, m = s.split(":")
    return int(h) * 60 + int(m)


def trunc(text: str, n: int = 8) -> str:
    return text if len(text) <= n else text[: n - 1] + "…"


PARSED = [(d, t2m(s), t2m(e), title) for d, s, e, title in EVENTS]


def day_events(day: str):
    rows = [(s, e, t) for d, s, e, t in PARSED if d == day]
    rows.sort(key=lambda x: x[0])
    return rows


def day_badge(day: str, is_today: bool) -> str:
    if is_today:
        return f"<span foreground='#7cd6ff'><b>[{KOR[day]}]</b></span>"
    return f"<span foreground='#e8f4ff'><b>[{KOR[day]}]</b></span>"


def day_lines(day: str, is_today: bool):
    rows = day_events(day)
    badge = day_badge(day, is_today)
    if not rows:
        return [f"{badge}  <span alpha='78%'>수업 없음</span>"]

    items = []
    for s, _, title in rows:
        items.append(f"<span alpha='88%'>{s//60:02d}:{s%60:02d}</span> {trunc(title, 12)}")

    # Keep each day readable by splitting long event lists into chunks.
    chunks = [items[i : i + 3] for i in range(0, len(items), 3)]
    lines = []
    for idx, chunk in enumerate(chunks):
        prefix = badge if idx == 0 else "      "
        lines.append(f"{prefix}  {'  ·  '.join(chunk)}")
    return lines


def boxed(line: str) -> str:
    return f"<span background='#182338' foreground='#eef6ff'> {line} </span>"


def now_line(now: dt.datetime) -> str:
    now_min = now.hour * 60 + now.minute
    if now.weekday() > 4:
        return "<span foreground='#ffd479'><b>NOW</b></span>  <span alpha='85%'>주말 · 다음 수업 월요일</span>"

    day = DAYS[now.weekday()]
    rows = day_events(day)

    for s, e, t in rows:
        if s <= now_min < e:
            left = e - now_min
            return (
                "<span foreground='#ffd479'><b>NOW</b></span>  "
                f"{KOR[day]}요일 {trunc(t, 12)} <span foreground='#ffd479'><b>{left}분 남음</b></span>"
            )

    for s, _, t in rows:
        if now_min < s:
            wait = s - now_min
            return (
                "<span foreground='#7cd6ff'><b>NEXT</b></span>  "
                f"{wait}분 후 {trunc(t, 12)}"
            )

    return f"<span foreground='#9eb1c8'><b>DONE</b></span>  <span alpha='85%'>{KOR[day]}요일 수업 종료</span>"


def safe_cmd(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True, timeout=2).strip()
    except Exception:
        return ""


def meta_line() -> str:
    scripts_dir = Path(__file__).resolve().parent
    aq = safe_cmd([str(scripts_dir / "air_quality_seoul.sh")])
    gcal_raw = safe_cmd([str(scripts_dir / "gcal_next.sh")])
    gcal = ""
    if gcal_raw:
        try:
            gcal = json.loads(gcal_raw).get("text", "")
        except Exception:
            gcal = gcal_raw

    parts = []
    if aq:
        parts.append(f"󰔏 {aq}")
    if gcal:
        parts.append(f"󰃭 {gcal}")
    if not parts:
        return ""
    return "<span alpha='73%'>" + "   |   ".join(parts) + "</span>"


def main():
    now = dt.datetime.now()
    today_idx = now.weekday() if now.weekday() < 5 else -1

    lines = [
        f"<span size='48000' weight='800'>{now.strftime('%H:%M')}</span>  <span size='15000' alpha='82%'>{now.strftime('%Y.%m.%d %a')}</span>",
        "",
        boxed(now_line(now)),
        "",
    ]
    for idx, day in enumerate(DAYS):
        lines.extend(boxed(x) for x in day_lines(day, today_idx == idx))

    meta = meta_line()
    if meta:
        lines.extend(["", boxed(meta)])

    tooltip = []
    for day in DAYS:
        tooltip.append(f"[{KOR[day]}요일]")
        rows = day_events(day)
        if not rows:
            tooltip.append("- 수업 없음")
        else:
            for s, e, t in rows:
                tooltip.append(f"- {s//60:02d}:{s%60:02d}-{e//60:02d}:{e%60:02d} {t}")

    print(json.dumps({"text": "\n".join(lines), "tooltip": "\n".join(tooltip), "class": ["dashboard"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
