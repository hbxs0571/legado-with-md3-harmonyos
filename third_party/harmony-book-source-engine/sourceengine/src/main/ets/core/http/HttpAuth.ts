// HTTP 认证辅助（OPDS、WebDAV 共用）：解析 WWW-Authenticate 质询并生成 Digest 应答。
// 纯 TypeScript，无平台 API 依赖（摘要函数由调用方注入），可在 Node 中直接运行。

export type HttpHashFunction = (algorithm: string, text: string) => string;

export class HttpAuthChallenge {
  scheme: string = '';
  params: Record<string, string> = {};
}

export class HttpDigestChallenge {
  realm: string = '';
  nonce: string = '';
  opaque: string = '';
  // 'MD5' / 'SHA256'，对应注入的摘要函数的 algorithm 入参。
  hashName: string = 'MD5';
  // 原样回传给服务器的 algorithm 值；质询未给出时为空，应答里也不带。
  algorithm: string = '';
  session: boolean = false;
  // 'auth' 或 ''（RFC 2069 旧式质询，无 qop）。
  qop: string = '';
  stale: boolean = false;
}

export class HttpAuth {
  // 逗号既分隔参数也分隔多个质询：按「token 后面是不是 '='」区分参数与新质询的 scheme。
  static parseChallenges(header: string): HttpAuthChallenge[] {
    const result: HttpAuthChallenge[] = [];
    let current: HttpAuthChallenge | null = null;
    for (const raw of HttpAuth.splitOutsideQuotes(header || '')) {
      let item: string = raw.trim();
      if (item === '') continue;
      const lead: RegExpMatchArray | null = item.match(/^([!#$%&'*+.^_`|~0-9A-Za-z-]+)(\s*)(.?)/);
      if (lead === null) continue;
      if (lead[3] !== '=') {
        current = new HttpAuthChallenge();
        current.scheme = lead[1].toLowerCase();
        result.push(current);
        item = item.substring(lead[1].length).trim();
        if (item === '') continue;
      }
      if (current === null) continue;
      const equals: number = item.indexOf('=');
      if (equals <= 0) continue;
      const name: string = item.substring(0, equals).trim().toLowerCase();
      if (!(name in current.params)) {
        current.params[name] = HttpAuth.unquote(item.substring(equals + 1).trim());
      }
    }
    return result;
  }

  static hasScheme(header: string, scheme: string): boolean {
    const target: string = scheme.toLowerCase();
    for (const challenge of HttpAuth.parseChallenges(header)) {
      if (challenge.scheme === target) return true;
    }
    return false;
  }

  // 取第一个本端能应答的 Digest 质询；算法或 qop 不支持（如仅 auth-int）时返回 null。
  static digestChallenge(header: string): HttpDigestChallenge | null {
    for (const challenge of HttpAuth.parseChallenges(header)) {
      if (challenge.scheme !== 'digest') continue;
      const nonce: string = challenge.params['nonce'] || '';
      if (nonce === '') continue;
      const result: HttpDigestChallenge = new HttpDigestChallenge();
      result.realm = challenge.params['realm'] || '';
      result.nonce = nonce;
      result.opaque = challenge.params['opaque'] || '';
      result.algorithm = challenge.params['algorithm'] || '';
      let algorithm: string = result.algorithm.toUpperCase();
      if (algorithm.endsWith('-SESS')) {
        result.session = true;
        algorithm = algorithm.substring(0, algorithm.length - 5);
      }
      if (algorithm === '' || algorithm === 'MD5') result.hashName = 'MD5';
      else if (algorithm === 'SHA-256') result.hashName = 'SHA256';
      else continue;
      const qopOptions: string[] = (challenge.params['qop'] || '').split(',')
        .map((value: string): string => value.trim().toLowerCase())
        .filter((value: string): boolean => value !== '');
      if (qopOptions.length > 0) {
        if (qopOptions.indexOf('auth') < 0) continue;
        result.qop = 'auth';
      } else if (result.session) {
        continue;
      }
      result.stale = (challenge.params['stale'] || '').toLowerCase() === 'true';
      return result;
    }
    return null;
  }

  static digestAuthorization(challenge: HttpDigestChallenge, username: string, password: string,
    method: string, url: string, nonceCount: number, cnonce: string, hash: HttpHashFunction): string {
    const uri: string = HttpAuth.requestUri(url);
    const digest = (text: string): string => hash(challenge.hashName, text);
    let ha1: string = digest(`${username}:${challenge.realm}:${password}`);
    if (challenge.session) ha1 = digest(`${ha1}:${challenge.nonce}:${cnonce}`);
    const ha2: string = digest(`${method.toUpperCase()}:${uri}`);
    const nc: string = HttpAuth.nonceCountText(nonceCount);
    const response: string = challenge.qop !== '' ?
      digest(`${ha1}:${challenge.nonce}:${nc}:${cnonce}:${challenge.qop}:${ha2}`) :
      digest(`${ha1}:${challenge.nonce}:${ha2}`);
    const parts: string[] = [
      `username="${HttpAuth.quote(username)}"`,
      `realm="${HttpAuth.quote(challenge.realm)}"`,
      `nonce="${HttpAuth.quote(challenge.nonce)}"`,
      `uri="${HttpAuth.quote(uri)}"`,
      `response="${response}"`
    ];
    if (challenge.algorithm !== '') parts.push(`algorithm=${challenge.algorithm}`);
    if (challenge.opaque !== '') parts.push(`opaque="${HttpAuth.quote(challenge.opaque)}"`);
    if (challenge.qop !== '') {
      parts.push(`qop=${challenge.qop}`);
      parts.push(`nc=${nc}`);
      parts.push(`cnonce="${HttpAuth.quote(cnonce)}"`);
    }
    return `Digest ${parts.join(', ')}`;
  }

  // Digest 的 uri 是请求行里的路径 + 查询串，不含协议、主机和片段。
  static requestUri(url: string): string {
    const value: string = (url || '').split('#')[0];
    const match: RegExpMatchArray | null = value.match(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/[^/?]*(.*)$/);
    if (match === null) return value || '/';
    const rest: string = match[1];
    if (rest === '') return '/';
    return rest.charAt(0) === '?' ? `/${rest}` : rest;
  }

  private static nonceCountText(count: number): string {
    const hex: string = Math.max(1, Math.floor(count)).toString(16);
    return hex.length >= 8 ? hex : '00000000'.substring(hex.length) + hex;
  }

  private static splitOutsideQuotes(text: string): string[] {
    const parts: string[] = [];
    let current: string = '';
    let quoted: boolean = false;
    for (let i = 0; i < text.length; i++) {
      const ch: string = text.charAt(i);
      if (quoted && ch === '\\' && i + 1 < text.length) {
        current += ch + text.charAt(i + 1);
        i++;
        continue;
      }
      if (ch === '"') quoted = !quoted;
      if (ch === ',' && !quoted) {
        parts.push(current);
        current = '';
        continue;
      }
      current += ch;
    }
    parts.push(current);
    return parts;
  }

  private static unquote(value: string): string {
    if (value.length >= 2 && value.charAt(0) === '"' && value.charAt(value.length - 1) === '"') {
      return value.substring(1, value.length - 1).replace(/\\(.)/g, '$1');
    }
    return value;
  }

  private static quote(value: string): string {
    return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  }
}
