import crypto from 'node:crypto';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const moduleUrl = pathToFileURL(
  path.join(root, 'sourceengine', 'src', 'main', 'ets', 'core', 'http', 'HttpAuth.ts')).href;
const { HttpAuth } = await import(moduleUrl);

let assertions = 0;

function assertEquals(actual, expected, label) {
  assertions++;
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`${label}\n    实际: ${actualJson}\n    期望: ${expectedJson}`);
  }
}

function assertTrue(condition, message) {
  assertions++;
  if (!condition) throw new Error(message);
}

const hash = (algorithm, text) =>
  crypto.createHash(algorithm === 'SHA256' ? 'sha256' : 'md5').update(text, 'utf8').digest('hex');

function responseOf(header) {
  const match = header.match(/response="([0-9a-f]+)"/);
  return match ? match[1] : '';
}

// ---- Calibre 内容服务器的质询（srv/auth.py）：MD5 + qop=auth ----
const calibre = HttpAuth.digestChallenge(
  'Digest realm="calibre", nonce="1700000000:abcdef", algorithm="MD5", qop="auth"');
assertTrue(calibre !== null, 'calibre: 应识别 Digest 质询');
assertEquals(calibre.realm, 'calibre', 'calibre: realm');
assertEquals(calibre.nonce, '1700000000:abcdef', 'calibre: nonce 内的冒号不应截断');
assertEquals(calibre.qop, 'auth', 'calibre: qop');
assertEquals(calibre.hashName, 'MD5', 'calibre: 摘要算法');
assertEquals(calibre.stale, false, 'calibre: 默认非 stale');
assertTrue(HttpAuth.digestChallenge(
  'Digest realm="calibre", nonce="n", algorithm="MD5", qop="auth", stale="true"').stale,
  'calibre: stale="true" 应识别');

// ---- RFC 2617 3.5 示例 ----
const rfc2617 = HttpAuth.digestChallenge('Digest realm="testrealm@host.com", qop="auth,auth-int", ' +
  'nonce="dcd98b7102dd2f0e8b11d0f600bfb0c093", opaque="5ccc069c403ebaf9f0171e9517f40e41"');
const header2617 = HttpAuth.digestAuthorization(rfc2617, 'Mufasa', 'Circle Of Life', 'GET',
  'http://www.nowhere.org/dir/index.html', 1, '0a4f113b', hash);
assertEquals(responseOf(header2617), '6629fae49393a05397450978507c4ef1', 'rfc2617: response');
assertTrue(header2617.indexOf('uri="/dir/index.html"') > 0, 'rfc2617: uri 只含路径');
assertTrue(header2617.indexOf('nc=00000001') > 0, 'rfc2617: nc 八位十六进制');
assertTrue(header2617.indexOf('qop=auth,') > 0, 'rfc2617: 多个 qop 时选 auth');
assertTrue(header2617.indexOf('opaque="5ccc069c403ebaf9f0171e9517f40e41"') > 0, 'rfc2617: opaque 原样回传');
assertTrue(header2617.indexOf('algorithm=') < 0, 'rfc2617: 质询未给 algorithm 时应答不带');

// ---- RFC 7616 3.9.1 示例：同一质询的 MD5 与 SHA-256 ----
const nonce7616 = '7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v';
const cnonce7616 = 'f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ';
const md5Challenge = HttpAuth.digestChallenge(
  `Digest realm="http-auth@example.org", qop="auth, auth-int", algorithm=MD5, nonce="${nonce7616}"`);
assertEquals(responseOf(HttpAuth.digestAuthorization(md5Challenge, 'Mufasa', 'Circle of Life', 'GET',
  'http://www.example.org/dir/index.html', 1, cnonce7616, hash)),
  '8ca523f5e9506fed4657c9700eebdbec', 'rfc7616: MD5 response');
const shaChallenge = HttpAuth.digestChallenge(
  `Digest realm="http-auth@example.org", qop="auth, auth-int", algorithm=SHA-256, nonce="${nonce7616}"`);
assertEquals(shaChallenge.hashName, 'SHA256', 'rfc7616: SHA-256 映射');
assertEquals(responseOf(HttpAuth.digestAuthorization(shaChallenge, 'Mufasa', 'Circle of Life', 'GET',
  'http://www.example.org/dir/index.html', 1, cnonce7616, hash)),
  '753927fa0e85d155564e2e272a28d1802ca10daf4496794697cf8db5856cb6c1', 'rfc7616: SHA-256 response');

// ---- 多质询与不支持的组合 ----
const mixed = 'Basic realm="lib, main", Digest realm="r", nonce="n1", qop="auth"';
assertEquals(HttpAuth.parseChallenges(mixed).map((item) => item.scheme), ['basic', 'digest'],
  'mixed: 拆出两个质询');
assertEquals(HttpAuth.parseChallenges(mixed)[0].params.realm, 'lib, main', 'mixed: 引号内逗号不拆分');
assertTrue(HttpAuth.hasScheme(mixed, 'Basic'), 'mixed: hasScheme 不区分大小写');
assertEquals(HttpAuth.digestChallenge(mixed).nonce, 'n1', 'mixed: 取到 Digest 质询');
assertEquals(HttpAuth.digestChallenge('Basic realm="x"'), null, 'basic: 无 Digest 质询');
assertEquals(HttpAuth.digestChallenge(''), null, 'empty: 空头');
assertEquals(HttpAuth.digestChallenge('Digest realm="r", nonce="n", qop="auth-int"'), null,
  'auth-int: 仅 auth-int 不支持');
assertEquals(HttpAuth.digestChallenge('Digest realm="r", nonce="n", algorithm=SHA-512-256, qop="auth"'),
  null, 'sha-512-256: 不支持的算法');
assertEquals(HttpAuth.digestChallenge('Negotiate, Digest realm="r", nonce="n2"').qop, '',
  'legacy: 无参数 scheme 之后的 Digest，且无 qop');

// ---- 无 qop 的旧式应答（RFC 2069）与 MD5-sess ----
const legacy = HttpAuth.digestChallenge('Digest realm="r", nonce="n"');
const legacyHeader = HttpAuth.digestAuthorization(legacy, 'u', 'p', 'GET', 'http://h/a?b=1#frag', 1, 'c', hash);
assertEquals(responseOf(legacyHeader),
  hash('MD5', `${hash('MD5', 'u:r:p')}:n:${hash('MD5', 'GET:/a?b=1')}`), 'legacy: response');
assertTrue(legacyHeader.indexOf('cnonce') < 0 && legacyHeader.indexOf('nc=') < 0, 'legacy: 不带 qop 相关字段');
const sess = HttpAuth.digestChallenge('Digest realm="r", nonce="n", algorithm=MD5-sess, qop="auth"');
assertEquals(responseOf(HttpAuth.digestAuthorization(sess, 'u', '密码', 'GET', 'http://h/x', 17, 'c', hash)),
  hash('MD5', `${hash('MD5', `${hash('MD5', 'u:r:密码')}:n:c`)}:n:00000011:c:auth:${hash('MD5', 'GET:/x')}`),
  'sess: MD5-sess + 非 ASCII 密码 + nc 递增');

// ---- uri 提取 ----
assertEquals(HttpAuth.requestUri('http://192.168.1.10:8080/opds'), '/opds', 'uri: 带端口');
assertEquals(HttpAuth.requestUri('http://h:8080'), '/', 'uri: 无路径');
assertEquals(HttpAuth.requestUri('http://h?x=1'), '/?x=1', 'uri: 只有查询串');
assertEquals(HttpAuth.requestUri('https://h/get/epub/12/lib?a=b&c=d'), '/get/epub/12/lib?a=b&c=d',
  'uri: 保留查询串');

console.log(`HTTP auth check passed: ${assertions} assertions.`);
