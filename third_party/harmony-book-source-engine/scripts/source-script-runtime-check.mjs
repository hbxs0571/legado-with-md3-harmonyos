// 书源脚本运行时支撑的回归：位运算/类型化数组的引擎路由、动态请求头的 "@cache" 指令、
// webJs 返回 Promise 时的页面侧等待脚本（放进 node:vm 的假页面里真实执行）。
// 这些模块的相对 import 不带扩展名，个别还引用了系统 API 模块；这里拷到临时目录，
// 替换掉与被测逻辑无关的依赖后再加载。

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import { pathToFileURL } from 'node:url';
import { readEtsModule } from './lib/ets-module-staging.mjs';

const stagingDir = fs.mkdtempSync(path.join(os.tmpdir(), 'source-script-runtime-check-'));

let assertions = 0;

function equal(actual, expected, message) {
  assertions++;
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${message}\n  expected: ${JSON.stringify(expected)}\n  actual:   ${JSON.stringify(actual)}`);
  }
}

async function load(relative, rewrite = (text) => text) {
  const target = path.join(stagingDir, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, rewrite(readEtsModule(relative)));
  return await import(pathToFileURL(target).href);
}

try {
  const { BookSourceRuntimeRouter } = await load('core/book/BookSourceRuntimeRouter.ts',
    text => text.replace(/^import \{ SourceEngineHost \}.*$/m, 'const SourceEngineHost = { scriptExecutor: () => undefined };'));
  // 只测解析：BookSource 是类型，阶段运行时与路由常量在这里用不到。
  const { BookSourceHeaderRuntime } = await load('core/book/BookSourceHeaderRuntime.ts',
    (text) => text.replace(/^import \{ BookSource \}.*$/m, 'type BookSource = { header: string, bookSourceUrl: string, variable: string };')
      .replace(/^import \{ SourceRuntimeStage \}.*$/m, 'const SourceRuntimeStage = { URL: "url" };')
      .replace(/^import \{ BookSourceStageWebRuntime, StageWebRuntimeRequest \}.*$/m,
        'const BookSourceStageWebRuntime: any = null; const StageWebRuntimeRequest: any = null;'));
  const { WebJsAwaitScript } = await load('core/book/WebJsAwaitScript.ts');

  // ---- 引擎路由 ----
  const runtime = (code) => BookSourceRuntimeRouter.decide('content', code).runtime;
  equal(runtime('var h = 0; h = (h << 5) - h + c; result = h'), 'arkweb', '左移');
  equal(runtime('result = (a >>> 0).toString(16)'), 'arkweb', '无符号右移');
  equal(runtime('x = a ^ b'), 'arkweb', '异或');
  equal(runtime('h ^= s.charCodeAt(i)'), 'arkweb', '异或赋值');
  equal(runtime('x = a & 0xff'), 'arkweb', '按位与');
  equal(runtime('x = n | 0'), 'arkweb', '按位或');
  equal(runtime('x = (a + b) & ~mask'), 'arkweb', '括号后的按位与');
  equal(runtime('var b = new Uint8Array(16)'), 'arkweb', '类型化数组');
  equal(runtime('h = Math.imul(h, 16777619)'), 'arkweb', 'Math.imul');
  equal(runtime('new DataView(buf).getUint32(0)'), 'arkweb', 'DataView');
  equal(runtime('WebAssembly.instantiate(bytes)'), 'arkweb', 'WebAssembly');

  equal(runtime('result = a && b || c'), 'legacy', '逻辑与/或不是位运算');
  equal(runtime('result = result.replace(/a|b&c^d/g, "")'), 'legacy', '正则字面量里的符号不算');
  equal(runtime('result = "https://example.com/?a=1&b=2|3^4" + id'), 'legacy', '字符串里的符号不算');
  equal(runtime('// x = a ^ b << 2\nresult = a + b'), 'legacy', '注释里的符号不算');
  equal(runtime('result = a > b ? a : b'), 'legacy', '比较与三元');
  equal(runtime('result = java.md5Encode(key + "&t=" + Date.now())'), 'legacy', '常见签名拼接仍走轻量引擎');
  equal(runtime('result = myUint8ArrayName + 1'), 'legacy', '标识符只是包含类型名时不算');

  // ---- 动态请求头的 "@cache" 指令 ----
  const defaultTtl = 5 * 60 * 1000;
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"Referer":"https://example.com/"}'),
    { headers: { Referer: 'https://example.com/' }, ttlMs: defaultTtl }, '未声明时沿用默认缓存');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"X-Sign":"abc","@cache":false}'),
    { headers: { 'X-Sign': 'abc' }, ttlMs: 0 }, 'false 关闭缓存，指令本身不作为请求头');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"X-Sign":"abc","@cache":0}').ttlMs, 0, '0 关闭缓存');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"@cache":"false","X-T":1}'),
    { headers: { 'X-T': '1' }, ttlMs: 0 }, '字符串形式的 false');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"@Cache":30}').ttlMs, 30000, '数字是秒数，键名不区分大小写');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"@cache":86400}').ttlMs, defaultTtl, '不超过默认上限');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"@cache":true}').ttlMs, defaultTtl, 'true 等于默认');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"@cache":-5}').ttlMs, defaultTtl, '负数被忽略');
  equal(BookSourceHeaderRuntime.parseHeaderJson('{"@cache":"soon"}').ttlMs, defaultTtl, '无法识别的值被忽略');
  equal(BookSourceHeaderRuntime.parseHeaderJson(JSON.stringify('{"A":"1","@cache":false}')),
    { headers: { A: '1' }, ttlMs: 0 }, 'JSON 编码的对象字符串');
  equal(BookSourceHeaderRuntime.parseHeaderJson('not json'), { headers: {}, ttlMs: defaultTtl }, '非 JSON 返回空请求头');

  // ---- webJs 的 Promise 等待 ----
  const settle = () => new Promise((resolve) => setTimeout(resolve, 10));
  function page(blockEval = false) {
    const context = vm.createContext({}, { codeGeneration: { strings: !blockEval } });
    vm.runInContext('var window = globalThis; var title = "页面标题";', context);
    return (script) => vm.runInContext(script, context);
  }

  let run = page();
  equal(run(WebJsAwaitScript.start('title', 's1')), '页面标题', '同步表达式原样返回');
  equal(run(WebJsAwaitScript.start('var a = 2; a * 21', 's2')), 42, '多语句取最后一个表达式的值');
  equal(run(WebJsAwaitScript.start('', 's3')), undefined, '空脚本没有返回值');
  equal(run(WebJsAwaitScript.poll('s1')), WebJsAwaitScript.LOST, '同步结果不占用等待槽');

  equal(run(WebJsAwaitScript.start('Promise.resolve(title + "!")', 'p1')), WebJsAwaitScript.PENDING, 'Promise 先报告等待中');
  await settle();
  equal(run(WebJsAwaitScript.poll('p1')), '页面标题!', '兑现后取到结果');
  equal(run(WebJsAwaitScript.poll('p1')), WebJsAwaitScript.LOST, '结果取走后等待槽被清理');

  equal(run(WebJsAwaitScript.start('(async function(){ await null; return JSON.stringify({ok:1}); })()', 'p2')),
    WebJsAwaitScript.PENDING, 'async 函数');
  equal(run(WebJsAwaitScript.poll('p2')), WebJsAwaitScript.PENDING, '未兑现时继续等待');
  await settle();
  equal(run(WebJsAwaitScript.poll('p2')), '{"ok":1}', 'async 函数的返回值');

  equal(run(WebJsAwaitScript.start('Promise.reject(new Error("签名失败"))', 'p3')), WebJsAwaitScript.PENDING, '拒绝的 Promise');
  await settle();
  equal(run(WebJsAwaitScript.poll('p3')), WebJsAwaitScript.FAILED_PREFIX + '签名失败', '拒绝原因带回');

  equal(run(WebJsAwaitScript.start('new Promise(function(){})', 'p4')), WebJsAwaitScript.PENDING, '永不兑现的 Promise');
  await settle();
  equal(run(WebJsAwaitScript.poll('p4')), WebJsAwaitScript.PENDING, '一直等待，由请求超时兜底');

  const quoted = 'var s = "a\\"b\\n" + \'c\'; s.length';
  equal(run(WebJsAwaitScript.start(quoted, 's4')), 5, '脚本里的引号与转义不被破坏');

  run = page(true);
  let sideEffects = 0;
  equal(run(WebJsAwaitScript.start('globalThis.touched = 1; title', 'b1')), WebJsAwaitScript.BLOCKED, '禁用 eval 的页面报告受限');
  sideEffects = run('typeof touched');
  equal(sideEffects, 'undefined', '报告受限前不执行书源脚本');

  console.log(`source-script-runtime-check: ${assertions} assertions passed`);
} finally {
  fs.rmSync(stagingDir, { recursive: true, force: true });
}
