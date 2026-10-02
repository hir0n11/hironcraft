const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { Duration } = require('./InspectAlertSounds.cjs');
const source = fs.readFileSync('Media/AlertSounds.lua', 'utf8');
const rows = [...source.matchAll(/\{ "([^"]+)", "([^"]+)", ([\d.]+) \}/g)];
assert.equal(rows.length, 107);
const names = new Set(), files = new Set();
for (const [,file,name,seconds] of rows) {
  assert(!names.has(name)); names.add(name);
  if (/^\d+$/.test(file)) { assert.equal(file, '554003'); continue; }
  assert.equal(path.basename(file), file);
  assert(!files.has(file)); files.add(file);
  const buffer = fs.readFileSync(path.join('Media/SharedMedia/Sounds', file));
  const measured = Duration(buffer, file);
  assert(Math.abs(measured - Number(seconds)) < 0.11, `Incorrect mute duration for ${file}`);
}
assert.equal(files.size, 106);
assert(Duration(fs.readFileSync('Media/WhisperAlert.ogg'), 'WhisperAlert.ogg') <= 2);
for (const licence of ['Provided by.txt', 'Creative Commons - CC0 1.0.txt',
  'Creative Commons - Attribution 3.0.txt', 'Creative Commons - Attribution-NonCommercial 3.0.txt',
  'Creative Commons - Sampling Plus 1.0.txt']) {
  assert(fs.statSync(path.join('Media/SharedMedia',licence)).size>100, 'Missing sound credits/licence');
}
const toc = fs.readFileSync('HironCraft.toc', 'utf8');
assert(toc.indexOf('Media\\AlertSounds.lua')<toc.indexOf('Customer\\Notifications.lua'));
console.log('Alert sound assets passed (107 SharedMedia entries, original WhisperAlert, file headers/durations, credits, load order).');
