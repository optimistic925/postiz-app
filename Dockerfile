FROM ghcr.io/gitroomhq/postiz-app:v2.11.3

RUN node - <<'NODE'
const fs = require('fs');
const path = require('path');
const roots = ['/app/apps/backend/dist', '/app/libraries'];
let removed = 0;

function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules') walk(file);
      continue;
    }
    if (!entry.isFile() || !file.endsWith('.js')) continue;
    const beforeText = fs.readFileSync(file, 'utf8');
    const before = (beforeText.match(/read_insights/g) || []).length;
    if (!before) continue;
    const afterText = beforeText.replace(/[\"']read_insights[\"'],?/g, '');
    const after = (afterText.match(/read_insights/g) || []).length;
    if (after < before) {
      removed += before - after;
      fs.writeFileSync(file, afterText);
      console.log(`patched ${file}: removed ${before - after}`);
    }
  }
}

for (const root of roots) walk(root);
if (removed < 1) throw new Error('Facebook OAuth patch failed: read_insights was not removed');

let remaining = [];
function verify(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules') verify(file);
      continue;
    }
    if (entry.isFile() && file.endsWith('.js')) {
      const text = fs.readFileSync(file, 'utf8');
      if (text.includes('read_insights')) remaining.push(file);
    }
  }
}
for (const root of roots) verify(root);
if (remaining.length) throw new Error(`Facebook OAuth patch verification failed: ${remaining.join(', ')}`);
console.log('facebook_oauth_patch=verified');
NODE

ENTRYPOINT []
CMD ["sh", "-c", "nginx && pnpm run pm2"]
