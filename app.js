/* 경기도청 민원 대시보드 - 앱 로직
   - Supabase 에서 데이터 조회(페이지네이션) → 메모리 보관
   - 필터는 메모리에서 재계산(추가 요청 없음)
   - Realtime 로 신규 민원 즉시 반영
*/

// ── 0. Supabase 클라이언트 ─────────────────────────────
const { url, anonKey } = window.SUPABASE_CONFIG;
const sb = supabase.createClient(url, anonKey);

const CATCOL = ['#1a56db','#12b76a','#f79009','#7a5af8','#06aed4','#f04438','#8098a8'];
const STATUS_ORDER = ['접수','처리중','완료','보류','반려'];
const STATUS_COL = {'완료':'#12b76a','처리중':'#2f6fed','접수':'#f79009','보류':'#f04438','반려':'#8098a8'};

Chart.defaults.font.family = "'Malgun Gothic','맑은 고딕',sans-serif";
Chart.defaults.color = '#6b7684';

let ALL = [];              // 전체 민원 (메모리)
const charts = {};         // Chart 인스턴스 캐시

// ── 1. 데이터 로드 (1000행씩 페이지네이션) ──────────────
async function loadAll() {
  const page = 1000;
  let from = 0, rows = [];
  while (true) {
    const { data, error } = await sb
      .from('complaints')
      .select('receipt_no,title,category,department,assignee,status,priority,channel,region,satisfaction,received_at,due_at,completed_at')
      .order('received_at', { ascending: true })
      .range(from, from + page - 1);
    if (error) throw error;
    rows = rows.concat(data);
    if (data.length < page) break;
    from += page;
  }
  return rows;
}

// ── 2. 유틸 ────────────────────────────────────────────
const daysBetween = (a, b) => (new Date(b) - new Date(a)) / 86400000;
const fmtDate = s => { const d = new Date(s); const p = n => String(n).padStart(2,'0');
  return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`; };
const countBy = (arr, key) => arr.reduce((m, r) => (m[r[key]] = (m[r[key]]||0)+1, m), {});

// ── 3. 필터 적용 ───────────────────────────────────────
function applyFilters() {
  const period = document.getElementById('fPeriod').value;
  const region = document.getElementById('fRegion').value;
  const category = document.getElementById('fCategory').value;
  const status = document.getElementById('fStatus').value;

  let cutoff = null;
  if (period === '3m' || period === '1m') {
    cutoff = new Date(); cutoff.setMonth(cutoff.getMonth() - (period === '3m' ? 3 : 1));
  }
  return ALL.filter(r =>
    (!cutoff || new Date(r.received_at) >= cutoff) &&
    (region === 'all' || r.region === region) &&
    (category === 'all' || r.category === category) &&
    (status === 'all' || r.status === status)
  );
}

// ── 4. 렌더링 ──────────────────────────────────────────
function render(rows) {
  renderKPIs(rows);
  renderTrend(rows);
  renderCategory(rows);
  renderRegion(rows);
  renderDept(rows);
  renderChannel(rows);
  renderDays(rows);
  renderSatisfaction(rows);
  renderInsights(rows);
  renderRecent(rows);
  document.getElementById('lastUpdated').textContent =
    '⟳ ' + fmtDate(new Date().toISOString()) + ' 갱신';
}

function renderKPIs(rows) {
  const total = rows.length;
  const done = rows.filter(r => r.status === '완료');
  const doneRate = total ? (done.length / total * 100) : 0;

  const durs = done.filter(r => r.completed_at).map(r => daysBetween(r.received_at, r.completed_at));
  const avgDays = durs.length ? durs.reduce((a,b)=>a+b,0)/durs.length : 0;

  const sats = rows.filter(r => r.satisfaction != null).map(r => r.satisfaction);
  const avgSat = sats.length ? sats.reduce((a,b)=>a+b,0)/sats.length : 0;

  const pending = rows.filter(r => ['접수','처리중','보류'].includes(r.status)).length;

  document.getElementById('kTotal').innerHTML = `${total.toLocaleString()}<small> 건</small>`;
  document.getElementById('kDoneRate').innerHTML = `${doneRate.toFixed(1)}<small>%</small>`;
  document.getElementById('kAvgDays').innerHTML = `${avgDays.toFixed(1)}<small> 일</small>`;
  document.getElementById('kAvgSat').innerHTML = `${avgSat.toFixed(2)}<small> /5</small>`;
  document.getElementById('kPending').innerHTML = `${pending.toLocaleString()}<small> 건</small>`;
}

// 공통: 차트 생성/갱신
function upsert(id, config) {
  if (charts[id]) { charts[id].destroy(); }
  charts[id] = new Chart(document.getElementById(id), config);
}

function renderTrend(rows) {
  const by = {};
  rows.forEach(r => { const d = new Date(r.received_at); const k = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}`;
    by[k] = (by[k]||0)+1; });
  const labels = Object.keys(by).sort();
  upsert('c_trend', {
    type:'line',
    data:{labels, datasets:[{label:'접수', data:labels.map(k=>by[k]),
      borderColor:'#1a56db', backgroundColor:'rgba(26,86,219,.08)', fill:true, tension:.35, pointRadius:2}]},
    options:{maintainAspectRatio:false, plugins:{legend:{display:false}}, scales:{y:{beginAtZero:true}}}
  });
}

function renderCategory(rows) {
  const c = countBy(rows, 'category');
  const labels = Object.keys(c).sort((a,b)=>c[b]-c[a]);
  upsert('c_cat', {
    type:'doughnut',
    data:{labels, datasets:[{data:labels.map(l=>c[l]), backgroundColor:CATCOL, borderWidth:2, borderColor:'#fff'}]},
    options:{maintainAspectRatio:false, cutout:'58%',
      plugins:{legend:{position:'right', labels:{boxWidth:12, padding:10, font:{size:11}}}}}
  });
}

function renderRegion(rows) {
  const c = countBy(rows, 'region');
  const labels = Object.keys(c).sort((a,b)=>c[b]-c[a]).slice(0,10);
  upsert('c_region', {
    type:'bar',
    data:{labels, datasets:[{data:labels.map(l=>c[l]), backgroundColor:'#2f6fed', borderRadius:4}]},
    options:{indexAxis:'y', maintainAspectRatio:false, plugins:{legend:{display:false}}, scales:{x:{beginAtZero:true}}}
  });
}

function renderDept(rows) {
  const depts = [...new Set(rows.map(r=>r.department).filter(Boolean))];
  // 부서를 총건수 순으로 정렬
  const total = countBy(rows, 'department');
  depts.sort((a,b)=>total[b]-total[a]);
  const datasets = STATUS_ORDER.map(st => ({
    label:st, backgroundColor:STATUS_COL[st],
    data:depts.map(d => rows.filter(r=>r.department===d && r.status===st).length)
  }));
  upsert('c_dept', {
    type:'bar',
    data:{labels:depts, datasets},
    options:{maintainAspectRatio:false, plugins:{legend:{position:'bottom', labels:{boxWidth:12, font:{size:11}}}},
      scales:{x:{stacked:true}, y:{stacked:true, beginAtZero:true}}}
  });
}

function renderChannel(rows) {
  const c = countBy(rows, 'channel');
  const labels = Object.keys(c).sort((a,b)=>c[b]-c[a]);
  upsert('c_chan', {
    type:'pie',
    data:{labels, datasets:[{data:labels.map(l=>c[l]),
      backgroundColor:['#1a56db','#12b76a','#f79009','#8098a8'], borderWidth:2, borderColor:'#fff'}]},
    options:{maintainAspectRatio:false, plugins:{legend:{position:'bottom', labels:{boxWidth:11, font:{size:10.5}}}}}
  });
}

function renderDays(rows) {
  const buckets = {'0-2':0,'3-5':0,'6-9':0,'10-14':0,'15+':0};
  rows.filter(r=>r.status==='완료' && r.completed_at).forEach(r => {
    const d = daysBetween(r.received_at, r.completed_at);
    if (d<=2) buckets['0-2']++; else if (d<=5) buckets['3-5']++;
    else if (d<=9) buckets['6-9']++; else if (d<=14) buckets['10-14']++; else buckets['15+']++;
  });
  upsert('c_days', {
    type:'bar',
    data:{labels:Object.keys(buckets), datasets:[{data:Object.values(buckets), backgroundColor:'#7a5af8', borderRadius:4}]},
    options:{maintainAspectRatio:false, plugins:{legend:{display:false}}, scales:{y:{beginAtZero:true}}}
  });
}

function avgSatByCategory(rows) {
  const m = {};
  rows.filter(r=>r.satisfaction!=null).forEach(r => {
    (m[r.category] ??= []).push(r.satisfaction);
  });
  const out = {};
  Object.keys(m).forEach(k => out[k] = m[k].reduce((a,b)=>a+b,0)/m[k].length);
  return out;
}

function renderSatisfaction(rows) {
  const m = avgSatByCategory(rows);
  const labels = Object.keys(m).sort((a,b)=>m[b]-m[a]);
  upsert('c_sat', {
    type:'bar',
    data:{labels, datasets:[{data:labels.map(l=>+m[l].toFixed(2)), backgroundColor:CATCOL, borderRadius:4}]},
    options:{maintainAspectRatio:false, plugins:{legend:{display:false}}, scales:{y:{min:3, max:5}}}
  });
}

function renderInsights(rows) {
  const ul = document.getElementById('insights');
  const items = [];

  // 1) 최다 유형
  const cat = countBy(rows, 'category');
  const topCat = Object.keys(cat).sort((a,b)=>cat[b]-cat[a])[0];
  if (topCat) items.push(['i-info','i',
    `가장 많은 민원 유형은 <b>${topCat}</b> (${cat[topCat].toLocaleString()}건, 전체의 ${(cat[topCat]/rows.length*100).toFixed(0)}%).`]);

  // 2) 처리기간 최장 부서
  const deptDur = {};
  rows.filter(r=>r.status==='완료'&&r.completed_at).forEach(r=>{
    (deptDur[r.department] ??= []).push(daysBetween(r.received_at, r.completed_at)); });
  const deptAvg = Object.keys(deptDur).map(d=>[d, deptDur[d].reduce((a,b)=>a+b,0)/deptDur[d].length]);
  if (deptAvg.length) {
    const [d, v] = deptAvg.sort((a,b)=>b[1]-a[1])[0];
    items.push(['i-warn','!', `<b>${d}</b> 평균 처리기간 <b>${v.toFixed(1)}일</b>로 가장 김 — 처리 지연 점검 필요.`]);
  }

  // 3) 만족도 하위 유형
  const sat = avgSatByCategory(rows);
  const low = Object.keys(sat).sort((a,b)=>sat[a]-sat[b]).slice(0,2);
  if (low.length) items.push(['i-up','▲',
    `만족도 하위 유형: ${low.map(k=>`<b>${k}(${sat[k].toFixed(1)})</b>`).join(', ')} — 개선 검토.`]);

  // 4) 미처리 비중
  const pending = rows.filter(r=>['접수','처리중','보류'].includes(r.status)).length;
  items.push(['i-info','i', `현재 미처리 <b>${pending.toLocaleString()}건</b> (전체의 ${(pending/rows.length*100).toFixed(0)}%).`]);

  ul.innerHTML = items.map(([cls,ic,txt]) =>
    `<li><span class="ico ${cls}">${ic}</span><div>${txt}</div></li>`).join('');
}

function statusBadge(s) {
  const map = {'완료':'b-done','처리중':'b-ing','접수':'b-new','보류':'b-hold','반려':'b-reject'};
  return `<span class="badge ${map[s]||''}">${s}</span>`;
}
function renderRecent(rows) {
  const recent = [...rows].sort((a,b)=>new Date(b.received_at)-new Date(a.received_at)).slice(0,8);
  document.getElementById('recentBody').innerHTML = recent.map(r => `
    <tr>
      <td>${r.receipt_no||'-'}</td>
      <td>${fmtDate(r.received_at)}</td>
      <td>${r.region||'-'}</td>
      <td>${r.department||'-'}</td>
      <td>${r.category||'-'}</td>
      <td>${r.channel||'-'}</td>
      <td>${r.priority==='높음' ? '<span class="badge b-urgent">높음</span>' : (r.priority||'-')}</td>
      <td>${statusBadge(r.status)}</td>
    </tr>`).join('');
}

// ── 5. 필터·버튼 이벤트 ────────────────────────────────
function refresh() { render(applyFilters()); }

function initFilters() {
  const regions = [...new Set(ALL.map(r=>r.region).filter(Boolean))].sort();
  const cats = [...new Set(ALL.map(r=>r.category).filter(Boolean))].sort();
  document.getElementById('fRegion').insertAdjacentHTML('beforeend',
    regions.map(r=>`<option>${r}</option>`).join(''));
  document.getElementById('fCategory').insertAdjacentHTML('beforeend',
    cats.map(c=>`<option>${c}</option>`).join(''));
  ['fPeriod','fRegion','fCategory','fStatus'].forEach(id =>
    document.getElementById(id).addEventListener('change', refresh));
  document.getElementById('btnReset').addEventListener('click', () => {
    ['fPeriod','fRegion','fCategory','fStatus'].forEach(id => document.getElementById(id).value = 'all');
    refresh();
  });
  document.getElementById('btnDemo').addEventListener('click', insertDemo);
}

// ── 6. 실시간 구독 ─────────────────────────────────────
function subscribeRealtime() {
  sb.channel('complaints-rt')
    .on('postgres_changes', { event:'INSERT', schema:'public', table:'complaints' }, payload => {
      ALL.push(payload.new);
      refresh();
      const live = document.getElementById('live');
      live.classList.add('flash'); setTimeout(()=>live.classList.remove('flash'), 900);
    })
    .subscribe(status => {
      const live = document.getElementById('live');
      const txt = document.getElementById('liveText');
      if (status === 'SUBSCRIBED') { live.classList.add('on'); txt.textContent = '실시간 연결됨'; }
      else { live.classList.remove('on'); txt.textContent = '연결 대기'; }
    });
}

// ── 7. 시연용 신규 민원 INSERT ─────────────────────────
async function insertDemo() {
  const regions=['수원시','성남시','고양시','용인시','부천시'];
  const cats=[['도로/교통','도로관리과'],['환경','환경관리과'],['복지','사회복지과'],['안전','안전총괄과']];
  const [cat,dept]=cats[Math.floor(Math.random()*cats.length)];
  const now = new Date();
  const row = {
    receipt_no: 'DEMO-'+now.getTime(),
    title: '[시연] '+cat+' 신규 민원',
    category: cat, department: dept, assignee: '김주무관',
    status: '접수', priority: '높음', channel: '온라인',
    region: regions[Math.floor(Math.random()*regions.length)],
    received_at: now.toISOString(),
    due_at: new Date(now.getTime()+7*86400000).toISOString()
  };
  const { error } = await sb.from('complaints').insert(row);
  if (error) showError('시연 민원 추가 실패: ' + error.message);
}

// ── 8. 시작 ────────────────────────────────────────────
function showError(msg) {
  const e = document.getElementById('err');
  e.style.display = 'block'; e.textContent = '⚠ ' + msg;
}

(async function main() {
  try {
    if (!window.SUPABASE_CONFIG || url.includes('<')) {
      throw new Error('config.js 에 Supabase URL/anonKey 를 설정하세요.');
    }
    ALL = await loadAll();
    document.getElementById('loading').style.display = 'none';
    if (!ALL.length) { showError('데이터가 없습니다. setup_all.sql 을 먼저 실행하세요.'); return; }
    initFilters();
    refresh();
    subscribeRealtime();
  } catch (e) {
    document.getElementById('loading').style.display = 'none';
    showError(e.message || String(e));
    console.error(e);
  }
})();
