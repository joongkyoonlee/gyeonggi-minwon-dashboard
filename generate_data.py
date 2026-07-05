# -*- coding: utf-8 -*-
"""
경기도청 민원 대시보드 - 가상 민원 데이터 생성기 (CSV)

- 외부 라이브러리 불필요 (Python 표준 라이브러리만 사용)
- Supabase `complaints` 테이블 스키마와 동일한 컬럼으로 출력
- 개인정보(citizen_name/contact) 미포함
- 출력: complaints.csv  (Supabase Table Editor > Import 로 적재 가능)

※ SQL 로 서버에서 바로 생성하려면 sql/02_seed.sql 을 사용하세요.
   이 스크립트는 CSV import 방식 또는 로컬 확인용입니다.

실행:
    python generate_data.py            # 기본 4000건
    python generate_data.py 6000       # 건수 지정
"""

import csv
import sys
import math
import random
from datetime import datetime, timedelta

random.seed(42)  # 재현 가능 (원하면 제거)

BASE_NOW = datetime(2026, 7, 5, 12, 0, 0)  # 기준일 (CLAUDE.md currentDate)

# 유형 → (담당부서, 발생 가중치, 처리기한 SLA일)  ─ CHECK 제약과 값 일치
CATEGORIES = [
    ("도로/교통",  "도로관리과",   24, 7),
    ("환경",      "환경관리과",   20, 9),
    ("복지",      "사회복지과",   14, 6),
    ("행정",      "민원행정과",   14, 3),
    ("건축/주택",  "건축과",       12, 12),
    ("안전",      "안전총괄과",    9, 8),
    ("문화/체육",  "문화체육과",    7, 5),
]

CHANNELS   = [("온라인", 40), ("전화", 22), ("방문", 20), ("이메일", 18)]
STATUSES   = [("완료", 62), ("처리중", 20), ("접수", 12), ("보류", 4), ("반려", 2)]
PRIORITIES = [("보통", 64), ("높음", 18), ("낮음", 18)]

STAFF = ["김주무관", "이주무관", "박주무관", "최주무관", "정주무관", "강주무관", "조주무관", "윤주무관"]

# 인구 규모순 31개 시·군 (앞쪽일수록 접수 많게 스큐)
REGIONS = [
    "수원시","고양시","용인시","성남시","화성시","부천시","남양주시","안산시","평택시","안양시",
    "시흥시","파주시","김포시","의정부시","광주시","하남시","광명시","군포시","양주시","오산시",
    "이천시","안성시","구리시","의왕시","포천시","양평군","여주시","동두천시","과천시","가평군","연천군",
]

TITLES = {
    "도로/교통":  ["도로 파손 신고", "불법 주정차 신고", "신호등 고장 신고"],
    "환경":      ["소음 공해 민원", "쓰레기 무단투기", "악취 발생 신고"],
    "복지":      ["복지급여 문의", "노인돌봄 신청", "장애인 편의 요청"],
    "행정":      ["증명서 발급 문의", "행정서류 재발급", "민원처리 지연 항의"],
    "건축/주택":  ["불법건축물 신고", "건축허가 문의", "주택 누수 하자"],
    "안전":      ["재난위험시설 신고", "노후축대 점검요청", "화재위험 신고"],
    "문화/체육":  ["문화행사 문의", "체육시설 예약", "도서관 운영 건의"],
}


def wchoice(pairs):
    return random.choices([p[0] for p in pairs], weights=[p[1] for p in pairs], k=1)[0]


def region_skewed():
    # power>1 → 앞쪽(대도시) 편향
    idx = min(30, int((random.random() ** 1.8) * 31))
    return REGIONS[idx]


def received_dt():
    dt = BASE_NOW - timedelta(days=random.randint(0, 364))
    # 주말 접수 감소
    if dt.weekday() >= 5 and random.random() < 0.7:
        dt -= timedelta(days=random.randint(1, 2))
    # 업무시간 편향 (11~13시 피크)
    hour = random.choices(range(24),
        weights=[1,1,1,1,1,1,2,4,7,10,12,15,15,12,11,10,9,7,4,3,2,2,1,1], k=1)[0]
    return dt.replace(hour=hour, minute=random.randint(0, 59), second=random.randint(0, 59))


def make_row(seq):
    cat, dept, _, sla = random.choices(CATEGORIES, weights=[c[2] for c in CATEGORIES], k=1)[0]
    status   = wchoice(STATUSES)
    priority = wchoice(PRIORITIES)
    channel  = wchoice(CHANNELS)
    recv     = received_dt()
    due      = recv + timedelta(days=sla)

    completed_at = ""
    satisfaction = ""
    if status == "완료":
        dur = 1 + int(random.random() * (sla * 2))
        comp = min(BASE_NOW, recv + timedelta(days=dur))
        completed_at = comp.strftime("%Y-%m-%d %H:%M:%S")
        if random.random() < 0.8:  # 완료 건의 80%만 만족도 응답, 높은 쪽 편향
            satisfaction = max(1, min(5, math.ceil((random.random() ** 0.5) * 5)))

    return {
        "receipt_no": f"2026-{100000 + seq:06d}",
        "title": random.choice(TITLES[cat]),
        "category": cat,
        "department": dept,
        "assignee": random.choice(STAFF),
        "status": status,
        "priority": priority,
        "channel": channel,
        "region": region_skewed(),
        "satisfaction": satisfaction,
        "received_at": recv.strftime("%Y-%m-%d %H:%M:%S"),
        "due_at": due.strftime("%Y-%m-%d %H:%M:%S"),
        "completed_at": completed_at,
    }


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
    rows = [make_row(i + 1) for i in range(n)]
    rows.sort(key=lambda r: r["received_at"])

    fields = ["receipt_no", "title", "category", "department", "assignee",
              "status", "priority", "channel", "region", "satisfaction",
              "received_at", "due_at", "completed_at"]

    out = "complaints.csv"
    with open(out, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    # 요약
    from collections import Counter
    print(f"[완료] {out} - 총 {len(rows):,}건 (개인정보 미포함)")
    for dim in ["status", "category", "channel", "priority"]:
        print(f"\n■ {dim}")
        for k, v in Counter(r[dim] for r in rows).most_common():
            print(f"   {k:8s} {v:5,} ({v/len(rows)*100:4.1f}%)")
    sats = [int(r["satisfaction"]) for r in rows if r["satisfaction"] != ""]
    if sats:
        print(f"\n■ 평균 만족도: {sum(sats)/len(sats):.2f}/5 (응답 {len(sats):,})")
    print(f"■ 기간: {rows[0]['received_at'][:10]} ~ {rows[-1]['received_at'][:10]}")


if __name__ == "__main__":
    main()
