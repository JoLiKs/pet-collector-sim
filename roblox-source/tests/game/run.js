'use strict';
// Игровой интеграционный тест: запускает проект игры в эмуляторе roblox2web вместе с Driver.server.lua.
const fs = require('fs'), path = require('path');
const R2W = process.env.R2W_DIR || '/workspace/roblox2web';
const { runProject } = require(path.join(R2W, 'rbx/headless'));
const GAME = path.resolve(__dirname, '../..');
function walk(d, base, out) {
  for (const f of fs.readdirSync(d)) {
    if (['.git', 'tools_dl', 'dist', 'node_modules', 'docs', 'build', 'tests'].includes(f)) continue;
    const p = path.join(d, f); const st = fs.statSync(p);
    if (st.isDirectory()) walk(p, base, out); else out[path.relative(base, p).replace(/\\/g, '/')] = fs.readFileSync(p);
  }
  return out;
}
const files = walk(GAME, GAME, {});
files['src/ServerScriptService/Driver.server.lua'] = fs.readFileSync(path.join(__dirname, 'Driver.server.lua'));
const { ENV, logs } = runProject(files, { echo: false, seed: 7 });
const secs = +process.argv[2] || 260;
ENV.simulate(secs);
let ok = 0, fail = 0, done = false;
for (const l of logs) {
  const t = l.text;
  if (/^OK /.test(t)) ok++;
  else if (/^FAIL /.test(t)) { fail++; console.log('  ' + t); }
  else if (/^DONE/.test(t)) done = true;
  else if (/^INFO/.test(t)) console.log('  '+t);
  else if (l.level === 'err' || l.level === 'warn') { if (!/EXPECTED/.test(t)) console.log(`  [${l.who}] ${l.level}: ${t}`.slice(0, 400)); }
}
console.log(`game flow: ${ok} ok, ${fail} failed${done ? '' : '  (NO DONE — scenario did not finish)'}; runtime errors: ${ENV.errorCount}`);
process.exit(fail || !done || ENV.errorCount ? 1 : 0);
