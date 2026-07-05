-- ============================================================
-- 경기도청 민원 대시보드 - 유지보수/선택 SQL (03)
-- 필요한 블록만 골라서 실행하세요. (기본은 아무것도 실행 안 함 — 참고용)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- [A] 기존 5행(2026-000101~105) 정리: 지역 채우고 개인정보 제거
--     ggi 에 원래 있던 5건에는 region 이 없고 citizen 정보가 있음.
-- ────────────────────────────────────────────────────────────
-- update public.complaints set
--   region = case receipt_no
--     when '2026-000101' then '수원시'
--     when '2026-000102' then '고양시'
--     when '2026-000103' then '용인시'
--     when '2026-000104' then '성남시'
--     when '2026-000105' then '부천시' end,
--   citizen_name = null,
--   citizen_contact = null
-- where receipt_no in ('2026-000101','2026-000102','2026-000103','2026-000104','2026-000105');


-- ────────────────────────────────────────────────────────────
-- [B] (선택) 개인정보 컬럼 자체를 삭제 — 교육상 '가명·샘플 원칙' 강조 시
--     ※ 되돌릴 수 없음. 컬럼과 그 안의 데이터가 사라집니다.
-- ────────────────────────────────────────────────────────────
-- alter table public.complaints drop column if exists citizen_name;
-- alter table public.complaints drop column if exists citizen_contact;


-- ────────────────────────────────────────────────────────────
-- [C] 롤백 — 시드 데이터/추가 컬럼 되돌리기
-- ────────────────────────────────────────────────────────────
-- 1) 이 프로젝트가 시드한 4,000건만 삭제 (기존 5건은 유지)
-- delete from public.complaints where receipt_no like '2026-1%';

-- 2) 추가했던 컬럼 제거 (원래 ggi 스키마로 복귀)
-- alter table public.complaints drop constraint if exists complaints_satisfaction_chk;
-- alter table public.complaints drop column if exists satisfaction;
-- alter table public.complaints drop column if exists region;


-- ────────────────────────────────────────────────────────────
-- [D] 시연용 — 신규 민원 1건 즉시 INSERT (실시간 반영 데모)
--     대시보드가 켜진 상태에서 실행하면 새로고침 없이 화면에 나타남.
-- ────────────────────────────────────────────────────────────
-- insert into public.complaints
--   (receipt_no, title, category, department, assignee, status, priority, channel, region, received_at, due_at)
-- values
--   ('2026-999001','[시연] 도로 포트홀 신고','도로/교통','도로관리과','김주무관',
--    '접수','높음','온라인','수원시', now(), now() + interval '7 days');
