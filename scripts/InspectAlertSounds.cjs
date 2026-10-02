// Read the installed SharedMedia catalogue without executing addon code.
// Usage: node scripts/InspectAlertSounds.cjs <WeakAuras_SharedMedia directory>
const fs = require('fs');
const path = require('path');
function Duration(b, file) {
  let duration = 0;
  if (file.toLowerCase().endsWith('.ogg')) {
    const v = b.indexOf(Buffer.from([1, 118, 111, 114, 98, 105, 115]));
    if (v < 0) throw new Error('Missing Vorbis header: ' + file);
    const rate = b.readUInt32LE(v + 12);
    let at = 0;
    while ((at = b.indexOf('OggS', at)) >= 0) {
      const granule = b.readBigUInt64LE(at + 6);
      if (granule < 1000000000n) duration = Math.max(duration, Number(granule) / rate);
      at += 4;
    }
  } else {
    let at = 0;
    if (b.toString('ascii', 0, 3) === 'ID3') {
      at = 10 + ((b[6] & 127) << 21) + ((b[7] & 127) << 14) + ((b[8] & 127) << 7) + (b[9] & 127);
    }
    while (at + 4 < b.length) {
      const h = b.readUInt32BE(at);
      const ver = (h >>> 19) & 3, layer = (h >>> 17) & 3, bi = (h >>> 12) & 15, ri = (h >>> 10) & 3;
      if ((h >>> 21) !== 2047 || ver === 1 || layer !== 1 || bi === 0 || bi === 15 || ri === 3) { at++; continue; }
      const rate = [44100, 48000, 32000][ri] / (ver === 3 ? 1 : ver === 2 ? 2 : 4);
      const kb = (ver === 3 ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
        : [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160])[bi];
      const size = Math.floor((ver === 3 ? 144 : 72) * kb * 1000 / rate) + ((h >>> 9) & 1);
      if (at + size > b.length) break;
      duration += (ver === 3 ? 1152 : 576) / rate;
      at += size;
    }
  }
  if (!(duration > 0 && duration < 120)) throw new Error('Invalid duration: ' + file);
  return Math.ceil(duration * 10) / 10;
}
module.exports = { Duration };
if (require.main === module) {
  const root = process.argv[2];
  const source = fs.readFileSync(path.join(root, 'WeakAuras_SharedMedia.lua'), 'utf8');
  const rows = [];
  const pattern = /LSM:Register\("sound", "([^"]+)", (?:"([^"]+)"|(\d+))\)/g;
  for (const m of source.matchAll(pattern)) {
    const file = m[2] && m[2].split('\\').pop();
    // Some upstream lists include CartoonHop even though no file is shipped.
    // Do not offer a broken selector entry or substitute a different sound.
    if (file && !fs.existsSync(path.join(root, 'Sounds', file))) continue;
    rows.push({ name: m[1], file, id: m[3] && Number(m[3]),
      duration: file ? Duration(fs.readFileSync(path.join(root, 'Sounds', file)), file) : 10 });
  }
  console.log(JSON.stringify(rows));
}
