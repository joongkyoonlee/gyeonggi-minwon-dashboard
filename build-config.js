// 빌드 시 환경변수 → config.js 생성 (Vercel Build Command 에서 실행)
// 로컬에서 직접 만들려면: SUPABASE_URL=... SUPABASE_ANON_KEY=... node build-config.js
const fs = require('fs');

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_ANON_KEY;

if (!url || !key) {
  console.error('❌ 환경변수 SUPABASE_URL / SUPABASE_ANON_KEY 가 필요합니다.');
  process.exit(1);
}

const content =
  `// 자동 생성 파일 (build-config.js). 직접 수정하지 마세요.\n` +
  `window.SUPABASE_CONFIG = {\n` +
  `  url: ${JSON.stringify(url)},\n` +
  `  anonKey: ${JSON.stringify(key)}\n` +
  `};\n`;

fs.writeFileSync('config.js', content);
console.log('✅ config.js 생성 완료 (환경변수 기반)');
