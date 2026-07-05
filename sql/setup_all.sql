-- ============================================================
-- 경기도청 민원 대시보드 - 통합 설치 SQL (스키마 + 데이터 4,000건)
-- Supabase > SQL Editor 에 전체 복사 → 붙여넣기 → Run (한 번만 실행)
-- 개인정보 미포함. 멱등 스키마 + 시드.
-- ============================================================

-- 1) 테이블 -------------------------------------------------
create table if not exists public.complaints (
    id             uuid primary key default gen_random_uuid(),
    receipt_no     text unique,
    title          text,
    content        text,
    category       text,
    department     text,
    assignee       text,
    status         text not null default '접수',
    priority       text not null default '보통',
    channel        text,
    region         text,
    satisfaction   int,
    received_at    timestamptz not null default now(),
    due_at         timestamptz,
    completed_at   timestamptz,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

-- 기존 테이블에 누락 컬럼만 보강
alter table public.complaints add column if not exists region       text;
alter table public.complaints add column if not exists satisfaction int;

-- 2) 값 제약(CHECK) ----------------------------------------
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

-- 3) 인덱스 -------------------------------------------------
create index if not exists idx_complaints_received_at on public.complaints (received_at);
create index if not exists idx_complaints_region      on public.complaints (region);
create index if not exists idx_complaints_category    on public.complaints (category);
create index if not exists idx_complaints_status      on public.complaints (status);
create index if not exists idx_complaints_department  on public.complaints (department);

-- 4) 실시간(Realtime) ---------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='complaints'
  ) then
    alter publication supabase_realtime add table public.complaints;
  end if;
end $$;

-- 5) 읽기 권한(RLS) -----------------------------------------
alter table public.complaints enable row level security;

drop policy if exists "anon read" on public.complaints;
create policy "anon read" on public.complaints
  for select to anon using (true);

drop policy if exists "anon insert (demo only)" on public.complaints;
create policy "anon insert (demo only)" on public.complaints
  for insert to anon with check (true);

-- 6) 가상 데이터 4,000건 생성 (서버 side, 개인정보 없음) ------
with cfg as (
  select
    array['도로/교통','환경','복지','행정','건축/주택','안전','문화/체육']::text[]              as cats,
    array['도로관리과','환경관리과','사회복지과','민원행정과','건축과','안전총괄과','문화체육과']::text[] as depts,
    array[7,9,6,3,12,8,5]::int[]                                                              as sla,
    array['수원시','고양시','용인시','성남시','화성시','부천시','남양주시','안산시','평택시','안양시',
          '시흥시','파주시','김포시','의정부시','광주시','하남시','광명시','군포시','양주시','오산시',
          '이천시','안성시','구리시','의왕시','포천시','양평군','여주시','동두천시','과천시','가평군',
          '연천군']::text[]                                                                    as regions,
    array['김주무관','이주무관','박주무관','최주무관','정주무관','강주무관','조주무관','윤주무관']::text[] as staff,
    array[
      ['도로 파손 신고','불법 주정차 신고','신호등 고장 신고'],
      ['소음 공해 민원','쓰레기 무단투기','악취 발생 신고'],
      ['복지급여 문의','노인돌봄 신청','장애인 편의 요청'],
      ['증명서 발급 문의','행정서류 재발급','민원처리 지연 항의'],
      ['불법건축물 신고','건축허가 문의','주택 누수 하자'],
      ['재난위험시설 신고','노후축대 점검요청','화재위험 신고'],
      ['문화행사 문의','체육시설 예약','도서관 운영 건의']
    ]::text[]                                                                                  as titles
),
raw as (
  select g,
    random() r1, random() r2, random() r3, random() r4,
    random() r5, random() r6, random() r7
  from generate_series(1,4000) g
),
pick as (
  select g,
    case when r1<0.24 then 1 when r1<0.44 then 2 when r1<0.58 then 3 when r1<0.72 then 4
         when r1<0.84 then 5 when r1<0.93 then 6 else 7 end                      as cidx,
    1 + least(30, floor(power(r2,1.8)*31)::int)                                  as ridx,
    case when r3<0.62 then '완료' when r3<0.82 then '처리중' when r3<0.94 then '접수'
         when r3<0.98 then '보류' else '반려' end                                as status,
    case when r4<0.18 then '높음' when r4<0.82 then '보통' else '낮음' end        as priority,
    case when r5<0.40 then '온라인' when r5<0.62 then '전화'
         when r5<0.82 then '방문' else '이메일' end                              as channel,
    now() - ((floor(r6*365))::text || ' days')::interval
          - ((floor(r7*10)+8)::text || ' hours')::interval                       as received_at
  from raw
)
insert into public.complaints
  (receipt_no, title, category, department, assignee,
   status, priority, channel, region, satisfaction,
   received_at, due_at, completed_at)
select
  '2026-' || lpad((100000 + g)::text, 6, '0'),
  cfg.titles[cidx][1 + floor(random()*3)::int],
  cfg.cats[cidx],
  cfg.depts[cidx],
  cfg.staff[1 + floor(random()*array_length(cfg.staff,1))::int],
  pick.status, pick.priority, pick.channel,
  cfg.regions[ridx],
  case when pick.status='완료' and random() < 0.8
       then greatest(1, least(5, ceil(power(random(),0.5)*5)::int)) end,
  pick.received_at,
  pick.received_at + (cfg.sla[cidx] || ' days')::interval,
  case when pick.status='완료'
       then least(now(), pick.received_at
            + ((1 + floor(random()*(cfg.sla[cidx]*2)))::text || ' days')::interval)
       end
from pick, cfg;

-- 확인
select count(*) as 총건수 from public.complaints;
