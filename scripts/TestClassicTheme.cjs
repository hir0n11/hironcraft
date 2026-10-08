const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const toc = fs.readFileSync(path.join(root, 'HironCraft.toc'), 'utf8');
const files = toc.split(/\r?\n/).map(s => s.trim()).filter(s => s && !s.startsWith('#'));
for (const file of files) assert(fs.existsSync(path.join(root, file)), `Missing loaded file: ${file}`);
assert(!toc.includes('ProfitHub'), 'TOC still loads the legacy directory');
assert(files.indexOf('Workflow\\Core\\UI\\ClassicTheme.lua') < files.indexOf('Workflow\\Core\\UI\\Dropdown.lua'), 'theme is loaded too late');
assert(!fs.existsSync(path.join(root, 'ProfitHub')), 'legacy directory is still shipped');
let count = 0;
function audit(directory) {
    for (const entry of fs.readdirSync(directory, {withFileTypes:true})) {
        const file = path.join(directory, entry.name);
        if (entry.isDirectory()) { audit(file); continue; }
        if (!/\.(lua|xml)$/.test(entry.name)) continue;
        const text = fs.readFileSync(file, 'utf8');
        count++;
        assert(!text.includes('b19cd9') && !text.includes('0.694, 0.612, 0.851'), `Old purple accent: ${file}`);
        // The old asset root must remain solely to migrate saved custom fonts.
        const cleaned = file.endsWith(path.join('Core','UI','Fonts.lua'))
            ? text.replace('Interface\\\\AddOns\\\\HironCraft\\\\ProfitHub\\\\', '') : text;
        assert(!/profit.?hub|prohithub/i.test(cleaned), `Legacy branding: ${file}`);
        for (const match of text.matchAll(/Interface\\\\AddOns\\\\HironCraft\\\\([^"\r\n]+\.(?:ttf|tga|png))"/g)) {
            const asset = match[1].replaceAll('\\\\', '/');
            assert(fs.existsSync(path.join(root, asset)), `Missing asset: ${asset}`);
        }
    }
}
audit(path.join(root, 'Workflow'));
for (const name of ['logo.tga','logo_big.tga','logo.png','glow_ring.tga']) {
    assert(!fs.existsSync(path.join(root,'Workflow','Core','Media',name)), `Legacy artwork retained: ${name}`);
}
console.log(`Classic theme audit passed (${count} modules, TOC and asset paths).`);
