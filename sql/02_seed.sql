-- ============================================================
-- 경기도청 민원 대시보드 - 가상 데이터 시드 (02)
-- Supabase > SQL Editor 에서 01_schema.sql 실행 후 이 파일을 실행하세요.
-- 서버에서 generate_series 로 약 4,000건을 생성합니다. (개인정보 없음)
--
-- ※ 한 번만 실행하세요. receipt_no 가 unique 이므로 재실행 시 충돌합니다.
--   다시 시드하려면 아래 주석을 해제해 먼저 비우세요:
-- delete from public.complaints where receipt_no like '2026-1%';
-- ============================================================

with cfg as (
  select
    array['도로/교통','환경','복지','행정','건축/주택','안전','문화/체육']::text[]              as cats,
    array['도로관리과','환경관리과','사회복지과','민원행정과','건축과','안전총괄과','문화체육과']::text[] as depts,
    array[7,9,6,3,12,8,5]::int[]                                                              as sla,   -- 유형별 처리기한(일)
    array['수원시','고양시','용인시','성남시','화성시','부천시','남양주시','안산시','평택시','안양시',
          '시흥시','파주시','김포시','의정부시','광주시','하남시','광명시','군포시','양주시','오산시',
          '이천시','안성시','구리시','의왕시','포천시','양평군','여주시','동두천시','과천시','가평군',
          '연천군']::text[]                                                                    as regions,
    array['김주무관','이주무관','박주무관','최주무관','정주무관','강주무관','조주무관','윤주무관']::text[] as staff,
    array[  -- 유형별 대표 제목 3개 (7 x 3)
      ['도로 파손 신고','불법 주정차 신고','신호등 고장 신고'],
      ['소음 공해 민원','쓰레기 무단투기','악취 발생 신고'],
      ['복지급여 문의','노인돌봄 신청','장애인 편의 요청'],
      ['증명서 발급 문의','행정서류 재발급','민원처리 지연 항의'],
      ['불법건축물 신고','건축허가 문의','주택 누수 하자'],
      ['재난위험시설 신고','노후축대 점검요청','화재위험 신고'],
      ['문화행사 문의','체육시설 예약','도서관 운영 건의']
    ]::text[]                                                                                  as titles
),
raw as (  -- 행별 난수 (generate_series 위에서 select 하므로 행마다 새로 계산됨)
  select g,
    random() r1, random() r2, random() r3, random() r4,
    random() r5, random() r6, random() r7, random() r8
  from generate_series(1,4000) g
),
pick as (
  select g, r8,
    case when r1<0.24 then 1 when r1<0.44 then 2 when r1<0.58 then 3 when r1<0.72 then 4
         when r1<0.84 then 5 when r1<0.93 then 6 else 7 end                      as cidx,
    1 + least(30, floor(power(r2,1.8)*31)::int)                                  as ridx,  -- 인구순 스큐
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
       then greatest(1, least(5, ceil(power(random(),0.5)*5)::int)) end,          -- 만족도(높은 쪽 편향)
  pick.received_at,
  pick.received_at + (cfg.sla[cidx] || ' days')::interval,                        -- due_at
  case when pick.status='완료'
       then least(now(), pick.received_at
            + ((1 + floor(random()*(cfg.sla[cidx]*2)))::text || ' days')::interval)
       end                                                                        -- completed_at
from pick, cfg;

-- 확인
-- select count(*) as 총건수 from public.complaints;
-- select status, count(*) from public.complaints group by status order by 2 desc;
