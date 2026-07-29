#!/usr/bin/env node
// Capture the compiled, locale-resolved catalogue from the only visual/gameplay
// reference. This is runtime content, not a parity fixture; port_fixtures stays
// owned exclusively by roguecardv2/tools/capture-port-fixtures.mjs.

import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const reference = path.resolve(root, '../roguecardv2-benchmark');
const head = execFileSync('git', ['-C', reference, 'rev-parse', '--short', 'HEAD'],
  { encoding: 'utf8' }).trim();
if (head !== '6e06911') throw new Error(`reference must be 6e06911, got ${head}`);

const { CORE_CONTENT } = await import(pathToFileURL(path.join(reference, 'src/content.js')));
const functionPaths = [];
function inspect(value, prefix = 'core') {
  if (!value || typeof value !== 'object') return;
  for (const [key, child] of Object.entries(value)) {
    const childPath = `${prefix}.${key}`;
    if (typeof child === 'function') functionPaths.push(childPath);
    else inspect(child, childPath);
  }
}
inspect(CORE_CONTENT);
const unexpected = functionPaths.filter((entry) =>
  !/^core\.(enemies\.[^.]+|shadeKits\.[^.]+)\.ai$/.test(entry));
if (unexpected.length) throw new Error(`unserialisable mechanics: ${unexpected.join(', ')}`);

const captured = {
  ...CORE_CONTENT,
  _source: { repository: 'roguecardv2-benchmark', commit: head },
};
const output = path.join(root, 'content/full-content.json');
fs.writeFileSync(output, `${JSON.stringify(captured, (_key, value) =>
  typeof value === 'function' ? undefined : value)}\n`);
console.log(`full content: ${output} (${Object.keys(captured.cards).length} cards, ` +
  `${Object.keys(captured.enemies).length} enemies)`);
