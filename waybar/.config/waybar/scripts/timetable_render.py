#!/usr/bin/env python3
import datetime as dt
import json
import sys


DAYS = ["mon", "tue", "wed", "thu", "fri"]
KOR = {"mon": "월", "tue": "화", "wed": "수", "thu": "목", "fri": "금"}
DAY_INDEX = {d: i for i, d in enumerate(DAYS)}

# timetablefinal1.pdf 기준 정리
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


def truncate(text: str, n: int = 12) -> str:
    if len(text) <= n:
        return text
    return text[: n - 1] + "…"


PARSED = [(d, t2m(s), t2m(e), title) for d, s, e, title in EVENTS]


def events_for(day: str):
    result = [(s, e, t) for d, s, e, t in PARSED if d == day]
    result.sort(key=lambda x: x[0])
    return result


def is_now(start: int, end: int, now_min: int) -> bool:
    return start <= now_min < end


def render_day(day: str):
    now = dt.datetime.now()
    now_min = now.hour * 60 + now.minute
    today = DAYS[now.weekday()] if now.weekday() < 5 else None

    day_events = events_for(day)
    lines = [f"<b>{KOR[day]}요일</b>"]
    has_now = False

    if not day_events:
        lines.append("<span alpha='75%'>수업 없음</span>")
    else:
        for s, e, title in day_events:
            slot = f"{s//60:02d}:{s%60:02d}-{e//60:02d}:{e%60:02d}"
            text = f"{slot} {truncate(title, 11)}"
            if day == today and is_now(s, e, now_min):
                lines.append(f"<span foreground='#ffd166'><b>▶ {text}</b></span>")
                has_now = True
            else:
                lines.append(text)

    css_classes = [day]
    if day == today:
        css_classes.append("today")
    if has_now:
        css_classes.append("has-now")

    tooltip = "\n".join(
        f"{s//60:02d}:{s%60:02d}-{e//60:02d}:{e%60:02d} {t}" for s, e, t in day_events
    ) or "수업 없음"

    payload = {"text": "\n".join(lines), "tooltip": tooltip, "class": css_classes}
    print(json.dumps(payload, ensure_ascii=False))


def render_now():
    now = dt.datetime.now()
    now_min = now.hour * 60 + now.minute
    today = DAYS[now.weekday()] if now.weekday() < 5 else None

    if today is None:
        text = "<b>NOW</b>\n주말"
        tooltip = "월~금 수업만 추적"
        print(json.dumps({"text": text, "tooltip": tooltip, "class": ["nowbox"]}, ensure_ascii=False))
        return

    evs = events_for(today)
    current = None
    nxt = None
    for s, e, t in evs:
        if s <= now_min < e:
            current = (s, e, t)
            break
        if now_min < s and nxt is None:
            nxt = (s, e, t)

    day_ko = KOR[today]
    if current:
        s, e, t = current
        left = e - now_min
        text = f"<b>NOW {day_ko}</b>\n<span foreground='#ffd166'><b>{truncate(t, 10)}</b></span> {left}분 남음"
    elif nxt:
        s, _, t = nxt
        left = s - now_min
        text = f"<b>NOW {day_ko}</b>\n{left}분 후 {truncate(t, 10)}"
    else:
        text = f"<b>NOW {day_ko}</b>\n오늘 수업 종료"

    tooltip = "\n".join(
        f"{s//60:02d}:{s%60:02d}-{e//60:02d}:{e%60:02d} {t}" for s, e, t in evs
    ) or "수업 없음"
    print(json.dumps({"text": text, "tooltip": tooltip, "class": ["nowbox"]}, ensure_ascii=False))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "now"
    if mode == "now":
        render_now()
        return
    if mode in DAY_INDEX:
        render_day(mode)
        return
    print(json.dumps({"text": "시간표 모드 오류", "tooltip": mode}))


if __name__ == "__main__":
    main()
