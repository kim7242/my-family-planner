import json
import os
import sys
from datetime import datetime, timedelta, timezone

import firebase_admin
from firebase_admin import credentials, messaging
from korean_lunar_calendar import KoreanLunarCalendar
import requests

DB_URL = "https://familyplanners-a98b5-default-rtdb.firebaseio.com"
KST = timezone(timedelta(hours=9))


def init_firebase():
    sa_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if not sa_json:
        print("FIREBASE_SERVICE_ACCOUNT_JSON 환경 변수가 설정되지 않았습니다.")
        sys.exit(1)
    cred_dict = json.loads(sa_json)
    cred = credentials.Certificate(cred_dict)
    firebase_admin.initialize_app(cred)


def fetch_json(path: str):
    res = requests.get(f"{DB_URL}/{path}.json", timeout=15)
    res.raise_for_status()
    return res.json()


def get_today_anniversaries(today_kst: datetime, anniversaries: list) -> list[str]:
    solar_md = today_kst.strftime("%m-%d")
    cal = KoreanLunarCalendar()
    cal.setSolarDate(today_kst.year, today_kst.month, today_kst.day)
    lunar_md = f"{cal.lunarMonth:02d}-{cal.lunarDay:02d}"

    results = []
    for anniv in anniversaries or []:
        if not isinstance(anniv, dict):
            continue
        name = str(anniv.get("name", "")).strip()
        a_date = str(anniv.get("date", "")).strip()
        is_lunar = bool(anniv.get("isLunar", False))
        if not name:
            continue
        if not is_lunar and a_date == solar_md:
            results.append(name)
        elif is_lunar and a_date == lunar_md:
            results.append(f"{name}(음력)")
    return results


def get_today_recurring(today_kst: datetime, recurring_tasks: list, done_map: dict) -> list[str]:
    # Python weekday(): Mon=0..Sun=6 -> Dart weekday: Mon=1..Sun=7
    dart_weekday = today_kst.weekday() + 1
    next_month = (today_kst.replace(day=28) + timedelta(days=4)).replace(day=1)
    last_day = (next_month - timedelta(days=1)).day

    results = []
    for rec in recurring_tasks or []:
        if not isinstance(rec, dict):
            continue
        rec_id = str(rec.get("id", ""))
        if done_map.get(rec_id) is True:
            continue
        r_type = rec.get("type", "weekly")
        matched = False
        if r_type == "daily":
            matched = True
        elif r_type == "weekly":
            weekdays = rec.get("weekdays") or []
            matched = dart_weekday in weekdays
        elif r_type == "monthly":
            target = int(rec.get("dayOfMonth", 1))
            effective = min(target, last_day)
            matched = today_kst.day == effective
        if matched:
            text = str(rec.get("text", "")).strip()
            if text:
                results.append(text)
    return results


def should_send_now(push_settings: dict, now_kst: datetime, force: bool) -> bool:
    if force:
        return True
    if not push_settings or not push_settings.get("enabled"):
        print("푸시 알림이 비활성화되어 있습니다.")
        return False

    today_str = now_kst.strftime("%Y-%m-%d")
    if push_settings.get("lastSentDate") == today_str:
        print(f"오늘({today_str}) 알림은 이미 발송되었습니다.")
        return False

    target_time = str(push_settings.get("time", "08:00"))
    try:
        hour, minute = map(int, target_time.split(":"))
    except ValueError:
        hour, minute = 8, 0

    now_minutes = now_kst.hour * 60 + now_kst.minute
    target_minutes = hour * 60 + minute
    # 설정 시각 이후 ~ 59분 이내에 실행되면 발송 (GitHub Actions cron 지연 대응)
    if target_minutes <= now_minutes < target_minutes + 60:
        return True

    print(f"아직 발송 시각이 아닙니다. (현재 KST {now_kst.strftime('%H:%M')}, 설정 {target_time})")
    return False


def collect_unfinished_todos(target_dt: datetime, tasks: list, recurring_tasks: list, done_map: dict) -> list[str]:
    items = []
    for t in tasks or []:
        if isinstance(t, dict) and not t.get("done"):
            text = str(t.get("text", "")).strip()
            if text:
                items.append(text)
    items.extend(get_today_recurring(target_dt, recurring_tasks, done_map or {}))
    return items


def collect_unfinished_supplies(supplies) -> tuple[int, list[str]]:
    supply_count = 0
    supply_cats = []
    if isinstance(supplies, dict):
        for cat, items in supplies.items():
            if not isinstance(items, list):
                continue
            rem = [i for i in items if isinstance(i, dict) and not i.get("done")]
            if rem:
                supply_count += len(rem)
                supply_cats.append(str(cat))
    return supply_count, supply_cats


def format_preview(items: list[str], limit: int = 3) -> str:
    preview = ", ".join(items[:limit])
    extra = f" 외 {len(items) - limit}건" if len(items) > limit else ""
    return f"{preview}{extra}"


def main():
    force = os.environ.get("FORCE_SEND", "").lower() in ("1", "true", "yes")
    now_kst = datetime.now(KST)
    today_str = now_kst.strftime("%Y-%m-%d")
    yesterday_kst = now_kst - timedelta(days=1)
    yesterday_str = yesterday_kst.strftime("%Y-%m-%d")

    push_settings = fetch_json("push_settings") or {}
    if not should_send_now(push_settings, now_kst, force):
        return

    tokens_map = fetch_json("push_tokens") or {}
    if not tokens_map:
        print("등록된 푸시 기기 토큰이 없습니다.")
        return

    tasks = fetch_json(f"tasks/{today_str}") or []
    supplies = fetch_json(f"supplies/{today_str}") or {}
    anniversaries = fetch_json("anniversaries") or []
    recurring_tasks = fetch_json("recurring_tasks") or []
    recurring_done = fetch_json(f"recurring_done/{today_str}") or {}

    y_tasks = fetch_json(f"tasks/{yesterday_str}") or []
    y_supplies = fetch_json(f"supplies/{yesterday_str}") or {}
    y_recurring_done = fetch_json(f"recurring_done/{yesterday_str}") or {}

    todo_items = collect_unfinished_todos(now_kst, tasks, recurring_tasks, recurring_done)
    supply_count, supply_cats = collect_unfinished_supplies(supplies)
    today_annivs = get_today_anniversaries(now_kst, anniversaries)

    y_todo_items = collect_unfinished_todos(yesterday_kst, y_tasks, recurring_tasks, y_recurring_done)
    y_supply_count, y_supply_cats = collect_unfinished_supplies(y_supplies)

    has_today = bool(todo_items or supply_count > 0 or today_annivs)
    has_yesterday = bool(y_todo_items or y_supply_count > 0)

    if not has_today and not has_yesterday:
        if not force:
            print("오늘 일정 및 어제 미완료 일정이 없어 알림을 건너뜁니다.")
            return
        body = "테스트 발송: 오늘·어제 미완료 일정은 없지만 푸시 연동이 정상입니다! 🎉"
    else:
        lines = []
        if today_annivs:
            lines.append(f"🎂 {', '.join(today_annivs)}")
        if todo_items:
            lines.append(f"✅ 오늘 할일 {len(todo_items)}건 ({format_preview(todo_items)})")
        if supply_count > 0:
            lines.append(f"🎒 오늘 준비물 {supply_count}개 ({', '.join(supply_cats[:2])})")

        if has_yesterday:
            y_parts = []
            if y_todo_items:
                y_parts.append(f"할일 {len(y_todo_items)}건 ({format_preview(y_todo_items)})")
            if y_supply_count > 0:
                y_parts.append(f"준비물 {y_supply_count}개 ({', '.join(y_supply_cats[:2])})")
            lines.append(f"⏪ 어제 미완료: {' · '.join(y_parts)}")

        body = "\n".join(lines)

    title = f"🐤 {now_kst.strftime('%m월 %d일')} 가족 플래너"

    init_firebase()

    sent = 0
    for token_key, info in list(tokens_map.items()):
        token = info.get("token") if isinstance(info, dict) else None
        if not token:
            continue
        msg = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            webpush=messaging.WebpushConfig(
                notification=messaging.WebpushNotification(
                    title=title,
                    body=body,
                    icon="https://familyplanners-a98b5.web.app/icons/Icon-192.png",
                ),
                fcm_options=messaging.WebpushFCMOptions(
                    link="https://familyplanners-a98b5.web.app/"
                ),
            ),
            token=token,
        )
        try:
            messaging.send(msg)
            sent += 1
            print(f"발송 성공: {token_key}")
        except messaging.UnregisteredError:
            print(f"만료된 토큰 삭제: {token_key}")
            requests.delete(f"{DB_URL}/push_tokens/{token_key}.json", timeout=10)
        except Exception as e:
            print(f"발송 실패 ({token_key}): {e}")

    if sent > 0 and not force:
        requests.patch(
            f"{DB_URL}/push_settings.json",
            json={"lastSentDate": today_str},
            timeout=10,
        )
    print(f"완료: 총 {sent}대 기기에 발송됨.")


if __name__ == "__main__":
    main()
