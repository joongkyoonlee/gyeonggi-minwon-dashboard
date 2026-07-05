# 경기도청 민원 대시보드

Supabase + 바닐라 JS + Chart.js 로 만든 민원 현황 실시간 대시보드.
(경기도청 바이브AI 동아리 실습 예제 · 가상 데이터, 개인정보 없음)

## 구성 파일

| 파일 | 설명 |
|---|---|
| `index.html` | 대시보드 화면 (KPI·차트·필터·실시간·테이블) |
| `app.js` | Supabase 조회·집계·차트·실시간 로직 |
| `config.js` | Supabase 연결 정보 — **빌드 시 환경변수로 자동 생성**(repo 미포함) |
| `config.example.js` | config.js 작성용 예시 |
| `build-config.js` | 환경변수 → `config.js` 생성 스크립트 (Vercel 빌드) |
| `vercel.json` / `package.json` | Vercel 빌드 설정 |
| `sql/setup_all.sql` | **스키마+데이터 4,000건** 한 번에 설치 (SQL Editor 실행) |
| `sql/01_schema.sql` / `02_seed.sql` | 스키마·시드 분리 버전 |
| `sql/03_maintenance.sql` | 롤백·개인정보 삭제·시연 INSERT (참고용) |
| `generate_data.py` / `complaints.csv` | CSV Import 방식용 가상 데이터 |
| `mockup.html` | 초기 화면 설계 목업 (참고용) |

## 설치 순서

### 1) DB 준비 (Supabase)
Supabase 대시보드 → **SQL Editor** → `sql/setup_all.sql` 전체 복사 → **Run** (한 번만).
→ `complaints` 테이블 생성 + 가상 민원 4,000건 적재 + RLS·Realtime 설정 완료.

> CSV로 넣고 싶으면: Table Editor → complaints → Insert → *Import data from CSV* → `complaints.csv`

### 2) 로컬 연결 정보 (config.js)
`config.js` 는 저장소에 없으므로 로컬에서 한 번 생성합니다:
```bash
SUPABASE_URL="https://<ref>.supabase.co" SUPABASE_ANON_KEY="eyJ..." node build-config.js
```
(또는 `config.example.js` 를 복사해 `config.js` 로 만들고 값 입력)

### 3) 실행 (로컬)
`file://` 직접 열기는 CORS 로 막히므로 간단한 로컬 서버로 실행:
```bash
python -m http.server 8777
```
브라우저에서 http://127.0.0.1:8777/index.html 접속.

### 4) 배포 (Vercel · 환경변수 방식)
1. vercel.com → **Add New → Project** → 이 저장소 **Import**
2. **Environment Variables** 에 추가:
   - `SUPABASE_URL` = `https://<ref>.supabase.co`
   - `SUPABASE_ANON_KEY` = `eyJ...` (anon 공개키)
3. Build/Output 은 `vercel.json` 이 자동 설정 (Build: `node build-config.js`, Output: `.`)
4. **Deploy** → 빌드 시 환경변수로 `config.js` 가 생성되어 배포됨

## 기능
- **KPI**: 총 민원·완료율·평균 처리기간·평균 만족도·미처리 건수
- **차트 7종**: 월별 추이 · 유형별 · 시군별 TOP10 · 부서별 처리상태 · 채널 · 처리기간 · 유형별 만족도
- **자동 인사이트**: 최다 유형·최장 처리부서·만족도 하위·미처리 비중 (데이터 기반 자동 계산)
- **필터**: 기간·시군·유형·상태 (메모리에서 즉시 재계산)
- **실시간**: 신규 민원 INSERT 시 새로고침 없이 자동 반영 (Supabase Realtime)
- **시연 버튼**: "＋ 시연 민원 추가" 로 실시간 동작 시연

## 데이터 스키마 (`complaints`)
`receipt_no, title, category, department, assignee, status, priority, channel, region, satisfaction, received_at, due_at, completed_at` (+ id, created_at, updated_at)

- status: 접수/처리중/완료/보류/반려 · priority: 높음/보통/낮음 · channel: 온라인/전화/방문/이메일
- region: 경기 31개 시·군 · satisfaction: 1~5 (완료 건 일부)

## 주의
- `config.js` 의 anon 키는 공개돼도 되는 키지만, 접근 통제는 **RLS 정책**에 의존합니다.
- 현재 RLS 는 데모용(익명 읽기·쓰기 허용). 실운영 시 정책 강화 필요.
