// Preview actual frame geometry from the Lua smoke test. Native textures are
// approximated here; this is a layout preview, not an in-game screenshot.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const sharp = require(process.env.HIRON_SHARP_PATH || 'sharp');
const lua = path.resolve(root, '../test-tools/fengari-node_modules/fengari-node-cli/src/lua-cli.js');
const escape = s => String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
async function render(tab) {
    const result = spawnSync(process.execPath, [lua,'scripts/TestClassicOrdersUI.lua','--scene','ru',tab], {cwd:root, encoding:'utf8'});
    if (result.status || result.stderr || !result.stdout.includes('Classic orders UI tests passed.')) throw new Error(result.stderr || result.stdout);
    const scene = result.stdout.split(/\r?\n/).filter(l=>l.startsWith('UI ')).map(l=>JSON.parse(l.slice(3)));
    let content = `<svg xmlns="http://www.w3.org/2000/svg" width="1330" height="740"><defs>
    <linearGradient id="panel" x2="0" y2="1"><stop stop-color="#332c23"/><stop offset="1" stop-color="#171512"/></linearGradient>
    <linearGradient id="button" x2="0" y2="1"><stop stop-color="#9b231c"/><stop offset=".45" stop-color="#671410"/><stop offset="1" stop-color="#3e0b09"/></linearGradient></defs>
    <rect width="1330" height="740" fill="#121110"/><rect x="10" y="12" width="1044" height="692" rx="6" fill="url(#panel)" stroke="#9b8a67" stroke-width="3"/>
    <text x="550" y="36" text-anchor="middle" fill="#ffd100" font-family="Arial" font-size="16">HironCraft · Заказы на изготовление</text>
    <text x="550" y="726" text-anchor="middle" fill="#a19b90" font-family="Arial" font-size="12">Предпросмотр компоновки • В игре используются текстуры и кнопки Blizzard</text>
    <rect x="24" y="70" width="220" height="590" rx="3" fill="#171512" stroke="#6d6049"/>
    <text x="40" y="98" fill="#ffd100" font-family="Arial" font-size="13">Рецепты профессии</text>`;
    for(let i=0;i<9;i++) content+=`<text x="42" y="${139+i*32}" fill="${i%3===0?'#e1bd65':'#b4aa99'}" font-family="Arial" font-size="12">${['Избранное','Наручи','Перчатки','Реагенты','Кожа','Чешуя','Кожаные доспехи','Кольчужные доспехи','Расходуемые предметы'][i]}</text>`;
    for(let i=0;i<4;i++) content+=`<rect x="${262+i*194}" y="43" width="185" height="26" rx="3" fill="${i===3?'#645020':'#29251e'}" stroke="#897957"/><text x="${354+i*194}" y="61" text-anchor="middle" fill="#ffd100" font-family="Arial" font-size="12">${['Общие','Гильдия','Покровители','Персональные (3)'][i]}</text>`;
    for (const [i,f] of scene.entries()) {
        if (f.x < 250) continue;
        if(f.skin) content+=`<rect x="${f.x}" y="${f.y}" width="${f.w}" height="${f.h}" rx="${f.skin==='button'?3:4}" fill="url(#${f.skin==='button'?'button':'panel'})" stroke="#827052" stroke-width="1"/>`;
        if(f.kind==='EditBox') content+=`<rect x="${f.x+4}" y="${f.y+3}" width="${f.w-8}" height="${f.h-6}" fill="#13110f" stroke="#766143"/>`;
        if(f.kind==='FontString' && f.text) {
            const cx = f.justify==='CENTER' ? f.x+f.w/2 : f.x;
            content+=`<defs><clipPath id="t${i}"><rect x="${f.x}" y="${f.y}" width="${f.w}" height="${f.h+6}"/></clipPath></defs><text clip-path="url(#t${i})" x="${cx}" y="${f.y+Math.min(f.h,14)}" text-anchor="${f.justify==='CENTER'?'middle':'start'}" font-family="Arial" font-size="${f.size}" fill="#e5cd8a">${escape(f.text)}</text>`;
        }
    }
    content+='</svg>';
    const out=path.join(root,'artwork',`classic-orders-${tab}.png`);
    fs.mkdirSync(path.dirname(out),{recursive:true});
    await sharp(Buffer.from(content)).png().toFile(out);
    console.log(out);
}
render('craft').then(()=>render('queue')).catch(e=>{console.error(e);process.exitCode=1;});
