// Render the real widget model's positions. Native textures are approximated;
// this is a layout preview, not an in-game screenshot.
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const sharp = require(process.env.HIRON_SHARP_PATH || 'sharp');
const root = path.resolve(__dirname,'..');
const lua = process.env.HIRON_LUA_CLI || path.resolve(root,'../test-tools/fengari-node_modules/fengari-node-cli/src/lua-cli.js');
const result = spawnSync(process.execPath,[lua,'scripts/TestClassicOverviewUI.lua','--scene','ru'],{cwd:root,encoding:'utf8'});
if (result.status || !result.stdout.includes('Classic overview UI tests passed')) throw new Error(result.stderr || result.stdout);
const scene = result.stdout.split(/\r?\n/).filter(l=>l.startsWith('UI ')).map(l=>JSON.parse(l.slice(3)));
const esc = s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const rgb = c=>`rgb(${c.slice(0,3).map(v=>Math.round(v*255)).join(',')})`;
let svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1240" height="620"><defs>
<linearGradient id="panel" x2="0" y2="1"><stop stop-color="#373028"/><stop offset="1" stop-color="#171512"/></linearGradient>
<linearGradient id="button" x2="0" y2="1"><stop stop-color="#902017"/><stop offset="1" stop-color="#390904"/></linearGradient>
</defs><rect width="1240" height="620" fill="#11100e"/>`;
for (const f of scene) {
    if (f.x<20 || f.y<20 || f.x+f.w>1221 || f.y+f.h>581) continue;
    if (f.skin) svg+=`<rect x="${f.x}" y="${f.y}" width="${f.w}" height="${f.h}" rx="4" fill="url(#${f.skin==='button'||f.skin==='close'?'button':'panel'})" stroke="#9c8a68"/>`;
    if (f.kind==='Texture' && f.color[3]>0) svg+=`<rect x="${f.x}" y="${f.y}" width="${f.w}" height="${f.h}" fill="${rgb(f.color)}" fill-opacity="${f.color[3]}"/>`;
    if (f.texture.includes('UI-DialogBox-Background-Dark')) svg+=`<rect x="${f.x}" y="${f.y}" width="${f.w}" height="${f.h}" fill="#1b1712"/>`;
    if (f.kind==='CheckButton') svg+=`<rect x="${f.x+2}" y="${f.y+2}" width="14" height="14" fill="#15130f" stroke="#9c8a68"/><text x="${f.x+3}" y="${f.y+14}" fill="#ffd200" font-size="14">${f.checked?'✓':''}</text>`;
    if (f.kind==='FontString' || f.skin==='button' || f.skin==='close') {
        const text=f.skin==='close'?'×':f.text;
        const center=f.skin==='button'||f.skin==='close'||f.justify==='CENTER';
        const color=f.kind==='FontString' && f.color[3]>0?rgb(f.color):'#ffd200';
        svg+=`<text x="${center?f.x+f.w/2:f.x}" y="${f.y+Math.min(f.h,16)}" text-anchor="${center?'middle':'start'}" font-family="Arial" font-size="${f.size}" fill="${color}">${esc(text.replace(/\|c[0-9a-f]{8}|\|r/gi,''))}</text>`;
    }
    if (f.texture.includes('help-i')) svg+=`<text x="${f.x+5}" y="${f.y+15}" fill="#dfbd68" font-family="Arial" font-size="12">ⓘ</text>`;
    if (f.texture.includes('settings')) svg+=`<text x="${f.x}" y="${f.y+18}" fill="#ffd200" font-size="20">⚙</text>`;
}
svg+='<text x="620" y="604" text-anchor="middle" fill="#9a9488" font-family="Arial" font-size="12">Предпросмотр компоновки · В игре используются рамки и текстуры Blizzard</text></svg>';
const out=path.join(root,'artwork','classic-overview.png');
fs.mkdirSync(path.dirname(out),{recursive:true});
sharp(Buffer.from(svg)).png().toFile(out).then(()=>console.log(out)).catch(e=>{console.error(e);process.exitCode=1;});
