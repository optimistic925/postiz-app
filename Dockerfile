FROM ghcr.io/gitroomhq/postiz-app:v2.11.3

RUN node - <<'NODE'
const fs = require('fs');
const path = require('path');
const roots = ['/app/apps/backend/dist', '/app/libraries'];
const obsoleteScopes = ['read_insights', 'instagram_manage_insights'];
const removed = Object.fromEntries(obsoleteScopes.map((s) => [s, 0]));

function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules') walk(file);
      continue;
    }
    if (!entry.isFile() || !file.endsWith('.js')) continue;

    let text = fs.readFileSync(file, 'utf8');
    let changed = false;
    for (const scope of obsoleteScopes) {
      const before = (text.match(new RegExp(scope, 'g')) || []).length;
      if (!before) continue;
      text = text.replace(new RegExp(`[\\"']${scope}[\\"'],?`, 'g'), '');
      const after = (text.match(new RegExp(scope, 'g')) || []).length;
      if (after < before) {
        removed[scope] += before - after;
        changed = true;
        console.log(`patched ${file}: removed ${scope} x${before - after}`);
      }
    }
    if (changed) fs.writeFileSync(file, text);
  }
}

for (const root of roots) walk(root);

for (const scope of obsoleteScopes) {
  if (removed[scope] < 1) throw new Error(`OAuth patch failed: ${scope} was not removed`);
}

let remaining = [];
function verify(dir) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules') verify(file);
      continue;
    }
    if (!entry.isFile() || !file.endsWith('.js')) continue;
    const text = fs.readFileSync(file, 'utf8');
    for (const scope of obsoleteScopes) {
      if (text.includes(scope)) remaining.push(`${scope}:${file}`);
    }
  }
}
for (const root of roots) verify(root);
if (remaining.length) throw new Error(`OAuth patch verification failed: ${remaining.join(', ')}`);
console.log(`oauth_patch=verified ${JSON.stringify(removed)}`);
NODE

ENTRYPOINT []
CMD ["sh", "-c", "nginx && pnpm run pm2"]
