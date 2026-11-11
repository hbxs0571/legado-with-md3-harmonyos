import { rcp } from '@kit.RemoteCommunicationKit';
import { util, xml } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { ensureTrailingSlash } from './WebDavConfig';

/**
 * WebDAV 协议层（rcp / RemoteCommunicationKit）。
 *
 * 为什么用 rcp 而不是 @ohos.net.http：后者的 RequestMethod 是枚举，只有
 * GET/POST/PUT/DELETE 等，没有 PROPFIND / MKCOL，且 HttpRequestOptions.method
 * 收的是枚举、传不进自定义字符串，WebDAV 的列举（PROPFIND）与建目录（MKCOL）
 * 做不了。rcp.HttpMethod 末位是 (string & NonNullable<unknown>)，任意非空串合法。
 *
 * 本层只管协议动词与 PROPFIND 解析，不管配置来源、不管界面。
 * 上游 WebDav.kt(512 行) 的 OkHttp 结构不照搬；这里每次操作一个 session，
 * 用完 close()，不做长期复用，避免「配置改了但 session 还带旧 Authorization」。
 */
export interface WebDavEntry {
  /** 完整 URL，目录以 `/` 结尾。 */
  url: string;
  /** 展示名（displayname，空则取路径末段）。 */
  displayName: string;
  /** 路径末段。 */
  urlName: string;
  /** 字节数，服务端没给就是 0。 */
  size: number;
  contentType: string;
  /** httpd/unix-directory 或 resourcetype 含 collection 判为目录。 */
  isDirectory: boolean;
  /** 毫秒时间戳，解析失败为 0。 */
  lastModified: number;
}

/** 401 / 非 2xx / 网络异常统一抛这个，message 面向用户。 */
export class WebDavError extends Error {
  readonly statusCode: number;
  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
  }
}

/** PROPFIND 解析过程中逐 response 收集的字段（显式 interface，避免无类型对象字面量）。 */
interface MultiStatusState {
  field: string;
  sawCollection: boolean;
  href: string;
  displayName: string;
  contentType: string;
  contentLength: string;
  lastModified: string;
}

/** PROPFIND 目录列表请求体：要 displayname / resourcetype / getcontentlength / creationdate / getlastmodified。 */
const APP_DIR: string =
  '<?xml version="1.0"?>' +
  '<a:propfind xmlns:a="DAV:"><a:prop>' +
  '<a:displayname/><a:resourcetype/><a:getcontentlength/>' +
  '<a:creationdate/><a:getlastmodified/>' +
  '</a:prop></a:propfind>';

/** PROPFIND 只探存在性：只要 resourcetype。 */
const APP_RESOURCE_TYPE: string =
  '<?xml version="1.0"?>' +
  '<a:propfind xmlns:a="DAV:"><a:prop><a:resourcetype/></a:prop></a:propfind>';

export class WebDav {
  /** 已补尾斜杠，例如 https://dav.jianguoyun.com/dav/legado/。 */
  private readonly rootUrl: string;
  /** 'Basic ' + base64(account:password)。 */
  private readonly authorization: string;
  private session: rcp.Session | undefined;
  /** check() 之后可读取，供 WebDavSync.test 区分 401 与网络失败。 */
  private lastStatus: number = 0;

  constructor(rootUrl: string, account: string, password: string) {
    let normalized = rootUrl.trim();
    // 上游 WebDav.kt:114 的 httpUrl 映射。
    if (normalized.startsWith('davs://')) {
      normalized = 'https://' + normalized.substring('davs://'.length);
    } else if (normalized.startsWith('dav://')) {
      normalized = 'http://' + normalized.substring('dav://'.length);
    }
    this.rootUrl = ensureTrailingSlash(normalized);
    this.authorization = WebDav.buildAuthorization(account, password);
  }

  getRootUrl(): string { return this.rootUrl; }
  getLastStatus(): number { return this.lastStatus; }

  /**
   * Basic 认证头。上游 Authorization.kt 用 ISO_8859_1 编码 Basic 凭据；
   * 绝大多数 WebDAV 账号是 ASCII，这里用 UTF-8：ASCII 下两者逐字节相同，
   * 而含非 ASCII 字符的账号在 ISO-8859-1 下本就会编码失败（上游那行会抛）。
   */
  private static buildAuthorization(account: string, password: string): string {
    const encoder = new util.TextEncoder();
    const raw = encoder.encodeInto(`${account}:${password}`);
    return 'Basic ' + new util.Base64Helper().encodeToStringSync(raw);
  }

  /**
   * 会话懒建。createSession 带会话级默认头（since 4.1.0(11)）：
   * downloadToFile / uploadFromFile 没有 headers 参数，坚果云会因缺 Authorization
   * 返 401，会话级默认头能覆盖这两条路径；newRequest 里再显式带一次做双保险。
   */
  private ensureSession(): rcp.Session {
    if (this.session !== undefined) {
      return this.session;
    }
    const sessionHeaders: rcp.RequestHeaders = {
      'authorization': this.authorization,
      'accept': '*/*'
    };
    this.session = rcp.createSession({ headers: sessionHeaders });
    return this.session;
  }

  close(): void {
    if (this.session !== undefined) {
      this.session.close();
      this.session = undefined;
    }
  }

  /**
   * 构造请求。rcp.Request 构造是 7 参，第 5(cookies)、6(transferRange) 位必须显式
   * 传 undefined 才能落到第 7 位 configuration。RequestHeaders 有索引签名，'depth'
   * 这类自定义头直接写键即可。
   */
  private newRequest(method: string, url: string, headers?: rcp.RequestHeaders,
    content?: rcp.RequestContent): rcp.Request {
    const merged: rcp.RequestHeaders = {
      'authorization': this.authorization,
      'accept': '*/*'
    };
    if (headers !== undefined) {
      for (const key of Object.keys(headers)) {
        const value = headers[key];
        if (value !== undefined) {
          merged[key] = value;
        }
      }
    }
    // 默认 60 秒对列举目录太长，显式收短连接超时。
    const configuration: rcp.Configuration = {
      transfer: {
        timeout: { connectMs: 15000, transferMs: 60000 }
      }
    };
    return new rcp.Request(url, method, merged, content, undefined, undefined, configuration);
  }

  /** 非 2xx 统一抛 WebDavError，message 面向用户。 */
  private checkResult(response: rcp.Response, what: string): void {
    const code = response.statusCode;
    if (code >= 200 && code < 300) {
      return;
    }
    let detail = `${what}失败（HTTP ${code}）`;
    if (code === 401) {
      detail = `${what}失败：账号或密码不正确（HTTP 401）`;
    } else if (code === 403) {
      detail = `${what}失败：服务端拒绝访问（HTTP 403）`;
    } else if (code === 404) {
      detail = `${what}失败：远端路径不存在（HTTP 404）`;
    } else if (code === 507) {
      detail = `${what}失败：远端空间不足（HTTP 507）`;
    }
    throw new WebDavError(detail, code);
  }

  /**
   * check()：对根目录发 Depth:0 PROPFIND，只看是不是 401。
   * 非 401 的其他失败（403/404 等）返回 true —— 语义是「凭据本身没问题」，
   * 路径问题交给 makeAsDir 去报。网络异常返回 false。
   * lastStatus 留给 WebDavSync.test 细化文案。
   */
  async check(): Promise<boolean> {
    this.lastStatus = 0;
    try {
      const session = this.ensureSession();
      const response = await session.fetch(this.newRequest('PROPFIND', this.rootUrl, {
        'depth': '0',
        'content-type': 'application/xml; charset=utf-8'
      }, APP_RESOURCE_TYPE));
      this.lastStatus = response.statusCode;
      return response.statusCode !== 401;
    } catch (error) {
      console.error(`[WebDav] check 请求失败: ${error instanceof Error ? error.message : String(error)}`);
      return false;
    }
  }

  /** 某个远端文件/目录在不在。 */
  async exists(url: string): Promise<boolean> {
    const session = this.ensureSession();
    const response = await session.fetch(this.newRequest('PROPFIND', ensureTrailingSlash(url), {
      'depth': '0',
      'content-type': 'application/xml; charset=utf-8'
    }, APP_RESOURCE_TYPE));
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /** 建目录，已存在不报错。405（坚果云已存在）/409（父目录不在）都放过。 */
  async makeAsDir(url: string): Promise<void> {
    const session = this.ensureSession();
    const target = ensureTrailingSlash(url);
    const response = await session.fetch(this.newRequest('MKCOL', target));
    if (response.statusCode === 405 || response.statusCode === 409) {
      console.info(`[WebDav] MKCOL ${target} 返回 ${response.statusCode}，按已存在处理`);
      return;
    }
    this.checkResult(response, '创建远端目录');
  }

  /** PROPFIND Depth:1 + 解析 207 响应。 */
  async listFiles(url: string): Promise<WebDavEntry[]> {
    const session = this.ensureSession();
    const target = ensureTrailingSlash(url);
    const response = await session.fetch(this.newRequest('PROPFIND', target, {
      'depth': '1',
      'content-type': 'application/xml; charset=utf-8'
    }, APP_DIR));
    this.checkResult(response, '列出远端目录');
    const body = response.body;
    if (body === undefined) {
      return [];
    }
    const text = new util.TextDecoder('utf-8').decodeToString(new Uint8Array(body));
    return WebDav.parseMultiStatus(text, target);
  }

  /** 上传本地文件到远端。用 UploadFromFile 流式直传，避免整份读进内存（fetch body 默认上限 50MB）。 */
  async upload(localPath: string, remoteUrl: string,
    contentType: string = 'application/octet-stream'): Promise<void> {
    const session = this.ensureSession();
    const request = this.newRequest('PUT', remoteUrl, { 'content-type': contentType },
      new rcp.UploadFromFile(localPath));
    const response = await session.fetch(request);
    this.checkResult(response, '上传文件');
  }

  /**
   * 下载远端文件到本地。
   * downloadToFile 不能带 per-request headers，认证头由 ensureSession() 的会话级
   * 默认头提供（见该处注释）。先删本地旧文件，避免目标已存在时行为依平台而异。
   */
  async downloadTo(remoteUrl: string, localPath: string): Promise<void> {
    const session = this.ensureSession();
    try {
      if (fileIo.accessSync(localPath)) {
        fileIo.unlinkSync(localPath);
      }
    } catch (error) {
      console.error(`[WebDav] 删除本地旧文件失败: ${error instanceof Error ? error.message : String(error)}`);
    }
    const destination: rcp.DownloadToFile = { kind: 'file', file: localPath };
    const response = await session.downloadToFile(remoteUrl, destination);
    this.checkResult(response, '下载文件');
  }

  /** 删除远端文件，本来就不在（404）视为成功。 */
  async delete(remoteUrl: string): Promise<void> {
    const session = this.ensureSession();
    const response = await session.fetch(this.newRequest('DELETE', remoteUrl));
    if (response.statusCode === 404) {
      return;
    }
    this.checkResult(response, '删除远端文件');
  }

  /** 去掉命名空间前缀，服务端可能是 d:response / D:href / 不带前缀。 */
  private static bareName(name: string): string {
    const colon = name.indexOf(':');
    return colon >= 0 ? name.substring(colon + 1) : name;
  }

  /** href 可能是完整 URL 或绝对路径（/dav/legado/backup.zip），都要处理并解百分号编码。 */
  private static resolveHref(href: string, baseUrl: string): string {
    let decoded = href;
    try {
      decoded = decodeURIComponent(href);
    } catch (_) {
      // 解码失败就用原文，不抛。
    }
    if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
      return decoded;
    }
    if (decoded.startsWith('/')) {
      // 取 baseUrl 的 scheme + host（含端口），拼回绝对 URL。
      const schemeEnd = baseUrl.indexOf('://');
      if (schemeEnd >= 0) {
        const hostStart = schemeEnd + 3;
        const pathStart = baseUrl.indexOf('/', hostStart);
        const origin = pathStart >= 0 ? baseUrl.substring(0, pathStart) : baseUrl;
        return origin + decoded;
      }
    }
    return ensureTrailingSlash(baseUrl) + decoded;
  }

  /**
   * 解析 207 Multi-Status。上游用 jsoup 命名空间选择器，这里用 @ohos.xml 的
   * XmlPullParser（compatibleSdkVersion 5.0.0(12)=API12，只能用 since 8 的 parse()，
   * parseXml 是 since 14 不可用）。逐 START_TAG / TEXT 收集 response 节点的字段。
   */
  private static parseMultiStatus(xmlText: string, baseUrl: string): WebDavEntry[] {
    const entries: WebDavEntry[] = [];
    const state: MultiStatusState = {
      field: '',
      sawCollection: false,
      href: '',
      displayName: '',
      contentType: '',
      contentLength: '',
      lastModified: ''
    };

    const encoder = new util.TextEncoder();
    const encoded = encoder.encodeInto(xmlText);
    const parser = new xml.XmlPullParser(encoded.buffer as ArrayBuffer, 'utf-8');
    const options: xml.ParseOptions = {
      tokenValueCallbackFunction: (eventType: xml.EventType, info: xml.ParseInfo): boolean => {
        if (eventType === xml.EventType.START_TAG) {
          const name = WebDav.bareName(info.getName());
          if (name === 'response') {
            state.sawCollection = false;
            state.href = '';
            state.displayName = '';
            state.contentType = '';
            state.contentLength = '';
            state.lastModified = '';
          } else if (name === 'collection') {
            // resourcetype 里嵌 <collection/> 时 TEXT 为空，必须看子元素名。
            state.sawCollection = true;
          } else if (name === 'href' || name === 'displayname' || name === 'getcontenttype' ||
            name === 'getcontentlength' || name === 'getlastmodified' || name === 'resourcetype') {
            state.field = name;
          }
        } else if (eventType === xml.EventType.TEXT) {
          if (state.field.length > 0) {
            const value = info.getText();
            if (state.field === 'href') {
              state.href += value;
            } else if (state.field === 'displayname') {
              state.displayName += value;
            } else if (state.field === 'getcontenttype') {
              state.contentType += value;
            } else if (state.field === 'getcontentlength') {
              state.contentLength += value;
            } else if (state.field === 'getlastmodified') {
              state.lastModified += value;
            } else if (state.field === 'resourcetype' && value.toLowerCase().includes('collection')) {
              state.sawCollection = true;
            }
          }
        } else if (eventType === xml.EventType.END_TAG) {
          const name = WebDav.bareName(info.getName());
          state.field = '';
          if (name === 'response') {
            const href = state.href.trim();
            if (href.length > 0) {
              const fullUrl = WebDav.resolveHref(href, baseUrl);
              const isDir = state.contentType.trim() === 'httpd/unix-directory' || state.sawCollection;
              const urlName = WebDav.urlNameOf(fullUrl);
              const display = state.displayName.trim().length > 0 ? state.displayName.trim() : urlName;
              const size = parseInt(state.contentLength.trim(), 10);
              const modified = Date.parse(state.lastModified.trim());
              const entry: WebDavEntry = {
                url: isDir ? ensureTrailingSlash(fullUrl) : fullUrl,
                displayName: display,
                urlName: urlName,
                size: Number.isFinite(size) && size > 0 ? size : 0,
                contentType: state.contentType.trim(),
                isDirectory: isDir,
                lastModified: Number.isFinite(modified) ? modified : 0
              };
              // 过滤掉根节点自己：结果里必有一条 href 等于请求的目录本身。
              if (ensureTrailingSlash(fullUrl) !== ensureTrailingSlash(baseUrl)) {
                entries.push(entry);
              }
            }
          }
        }
        return true;
      }
    };
    try {
      parser.parse(options);
    } catch (error) {
      // 服务端命名空间写法差异很大，解析失败只记日志、不抛，尽量返回已收条目。
      console.error(`[WebDav] PROPFIND 解析异常: ${error instanceof Error ? error.message : String(error)}`);
    }
    if (entries.length === 0 && xmlText.length > 0) {
      console.warn(`[WebDav] PROPFIND 响应非空但未解析出任何条目，前 200 字符: ${xmlText.substring(0, 200)}`);
    }
    return entries;
  }

  /** 从完整 URL 取末段路径名（去掉尾斜杠与查询串后）。 */
  private static urlNameOf(fullUrl: string): string {
    let path = fullUrl;
    const query = path.indexOf('?');
    if (query >= 0) {
      path = path.substring(0, query);
    }
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    const slash = path.lastIndexOf('/');
    return slash >= 0 ? path.substring(slash + 1) : path;
  }
}
