import fs from 'node:fs';
import path from 'node:path';

// 引擎中立回归：内核里不能出现站点专用地址、默认凭据或针对某个平台的适配。示例书源不要放进这些目录。
const projectRoot = path.resolve(import.meta.dirname, '..');
const scanRoots = [
  'sourceengine/src/main/ets/core/book',
  'sourceengine/src/main/ets/core/http',
  'sourceengine/src/main/ets/core/nativesource',
  'sourceengine/src/main/ets/core/rule'
];

// This is a regression check for previously embedded content adapters. It is not a legal opinion.
const forbidden = [
  ['fixed content URL', /https?:\/\/[a-z0-9.-]+\.(?:com|cn|cf|top|net|org)\/[a-z0-9_/?=&.-]+/i],
  ['legacy default credential', /tongrenshuqi134679/i],
  ['legacy content adapter', /BookSourceShuqiSupport|shuqi-comments|legado-shuqi-comment/i],
  ['platform-specific content API', /qidian_full_api|novel\.snssdk\.com|sinfonlineb\.fqnovel\.com/i],
  ['hardcoded aggregator host', /(?:101\.35\.133\.34|219\.154\.201\.122|aadcn|vossc\.com|langge\.cf|czyl\.cf|gyks\.cf)/i]
];

function filesUnder(target) {
  const absolute = path.join(projectRoot, target);
  const stat = fs.statSync(absolute);
  if (stat.isFile()) return [absolute];
  return fs.readdirSync(absolute, { withFileTypes: true }).flatMap((entry) => {
    const child = path.join(absolute, entry.name);
    if (entry.isDirectory()) return filesUnder(path.relative(projectRoot, child));
    return /\.(?:ets|ts)$/.test(entry.name) ? [child] : [];
  });
}

const failures = [];
for (const file of scanRoots.flatMap(filesUnder)) {
  const content = fs.readFileSync(file, 'utf8');
  for (const [label, pattern] of forbidden) {
    if (pattern.test(content)) failures.push(`${path.relative(projectRoot, file)}: ${label}`);
  }
}

if (failures.length > 0) {
  console.error('Neutral source-engine check failed:');
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
console.log('Neutral source-engine check passed: no embedded content endpoint, default credential, or known platform adapter found.');
