-- ============================================================
-- 경기도청 민원 대시보드 - 스키마 (01)
-- Supabase > SQL Editor 에 붙여넣고 실행하세요.
-- 멱등(idempotent): 여러 번 실행해도 안전. 기존 ggi.complaints 에도 그대로 적용됨.
-- ============================================================

-- 1) 테이블 (없으면 생성 · 있으면 유지) ------------------------
create table if not exists public.complaints (
    id             uuid primary key default gen_random_uuid(),
    receipt_no     text unique,                       -- 접수번호 (예: 2026-000101)
    title          text,                              -- 민원 제목
    content        text,                              -- 상세 내용 (선택)
    category       text,                              -- 민원 유형
    department     text,                              -- 담당부서
    assignee       text,                              -- 담당자
    status         text not null default '접수',
    priority       text not null default '보통',
    channel        text,                              -- 접수채널
    region         text,                              -- 시·군 (지역별 시각화)
    satisfaction   int,                               -- 만족도 1~5 (완료 건 일부)
    received_at    timestamptz not null default now(),-- 접수일시
    due_at         timestamptz,                       -- 처리기한(SLA)
    completed_at   timestamptz,                       -- 완료일시
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

-- 2) 기존 테이블 확장용 (ggi 처럼 이미 있는 경우 누락 컬럼만 추가) --
alter table public.complaints add column if not exists region       text;
alter table public.complaints add column if not exists satisfaction int;

-- 3) 값 제약(CHECK) ------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conname='complaints_status_chk') then
    alter table public.complaints add constraint complaints_status_chk
      check (status in ('접수','처리중','완료','보류','반려'));
  end if;
  if not exists (select 1 from pg_constraint where conname='complaints_priority_chk') then
    alter table public.complaints add constraint complaints_priority_chk
      check (priority in ('높음','보통','낮음'));
  end if;
  if not exists (select 1 from pg_constraint where conname='complaints_channel_chk') then
    alter table public.complaints add constraint complaints_channel_chk
      check (channel is null or channel in ('온라인','전화','방문','이메일'));
  end if;
  if not exists (select 1 from pg_constraint where conname='complaints_satisfaction_chk') then
    alter table public.complaints add constraint complaints_satisfaction_chk
      check (satisfaction is null or satisfaction between 1 and 5);
  end if;
end $$;

-- 4) 인덱스 (대시보드 필터/집계 성능) --------------------------
create index if not exists idx_complaints_received_at on public.complaints (received_at);
create index if not exists idx_complaints_region      on public.complaints (region);
create index if not exists idx_complaints_category    on public.complaints (category);
create index if not exists idx_complaints_status      on public.complaints (status);
create index if not exists idx_complaints_department  on public.complaints (department);

-- 5) 실시간(Realtime) 활성화 --------------------------------
-- 신규 민원 INSERT 를 대시보드가 실시간 수신하려면 publication 에 테이블 추가.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='complaints'
  ) then
    alter publication supabase_realtime add table public.complaints;
  end if;
end $$;

-- 6) 읽기 권한(RLS) -----------------------------------------
-- 데모: 익명(anon) 사용자에게 읽기 허용. 대시보드가 anon key 로 조회함.
alter table public.complaints enable row level security;

drop policy if exists "anon read" on public.complaints;
create policy "anon read"
  on public.complaints for select
  to anon
  using (true);

-- (선택) 시연용 INSERT 버튼을 쓰려면 익명 쓰기도 허용 — 데모 한정, 운영 시 제거
drop policy if exists "anon insert (demo only)" on public.complaints;
create policy "anon insert (demo only)"
  on public.complaints for insert
  to anon
  with check (true);
