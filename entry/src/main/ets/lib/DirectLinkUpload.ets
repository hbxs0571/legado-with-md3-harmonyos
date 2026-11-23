import { preferences } from '@kit.ArkData';
import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { AnalyzeRule } from '@legado/sourceengine';
import { EpubWriter } from '../data/EpubWriter';

/**
 * 直链上传（上游 help/DirectLinkUpload.kt，116 行）。
 *
 * 上游把「往网盘传一个文件、再按规则从响应里抠出下载地址」做成一件事：
 * 上传地址本身带一段 JSON 选项（method / body / type / headers），body 里值为
 * `fileRequest` 的键就是文件要填的位置；传完把响应体交给 AnalyzeRule 跑
 * downloadUrlRule 得到直链。这里逐段照搬，只是把 OkHttp 换成 rcp 的 MultipartForm。
 */
export interface DirectLinkRule {
  /** 上传地址，可带 `,{"method":"POST",...}` 选项后缀。 */
  uploadUrl: string;
  /** 从上传响应里取下载地址的规则（AnalyzeRule 语法）。 */
  downloadUrlRule: string;
  /** 备注，界面上显示这一条。 */
  summary: string;
  /** 上传前是否先压成 zip（上游 Rule.compress）。 */
  compress: boolean;
}

/** 上游 DirectLinkUpload.kt:23 `const val ruleFileName = "directLinkUploadRule.json"`。 */
export const DIRECT_LINK_RULE_FILE_NAME: string = 'directLinkUploadRule.json';

/** 上游 body 里标记「这里是文件」的占位值（AnalyzeUrl.kt:704-723）。 */
const FILE_PLACEHOLDER: string = 'fileRequest';

/**
 * 上游 assets/defaultData/directLinkUpload.json 的三条默认规则，逐字段照抄。
 * 界面上的「导入默认规则」取第一条填进四个输入框（对齐 OtherConfigViewModel.kt:257-266
 * 的 loadDefaultRules() 与 DirectLinkUploadBottomSheet.kt 的 import_default_rule）。
 */
export const DEFAULT_DIRECT_LINK_RULES: DirectLinkRule[] = [
  {
    uploadUrl: 'https://sy.nyasama.net/shuyuan,{"method":"POST","body": {"file": "fileRequest"},"type": "multipart/form-data"}',
    downloadUrlRule: '$.data@js:if (result == \'\') \n \'\' \n else \n \'https://shuyuan.nyasama.net/shuyuan/\' + result',
    summary: '喵公子网盘①(有效期30天·香港G口)',
    compress: false
  },
  {
    uploadUrl: 'https://sy.mgz6.com/shuyuan,{"method":"POST","body": {"file": "fileRequest"},"type": "multipart/form-data"}',
    downloadUrlRule: '$.data@js:if (result == \'\') \n \'\' \n else \n \'https://shuyuan.mgz6.com/shuyuan/\' + result',
    summary: '喵公子网盘②(有效期7天)',
    compress: false
  },
  {
    uploadUrl: 'http://v2.jt12.eu/up-v2.php,{"method":"POST","body": {"file": "fileRequest"},"type": "multipart/form-data"}',
    downloadUrlRule: '$.msg',
    summary: '橘涂书源网盘2.0 Beta(永久有效)',
    compress: false
  }
];

/** 上传地址解析结果：真实地址 + 从地址后缀里拆出来的请求选项。 */
interface DirectLinkRequest {
  url: string;
  method: string;
  headers: Record<string, string>;
  /** body 的 JSON 文本；空串表示没有 body。 */
  bodyText: string;
  type: string;
}

/** 上传失败统一抛这个，message 直接给用户看（对齐上游 NoStackTraceException 的文案）。 */
export class DirectLinkError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DirectLinkError';
  }
}

/**
 * 规则的存取。上游用 `ACache.get(cacheDir = false).getAsString(ruleFileName)`，
 * 这里换成 preferences 单键 JSON：内容一致、重启后还在，且不占缓存目录。
 */
export class DirectLinkUploadStore {
  private static readonly preferenceName: string = 'legado_direct_link_upload';
  private static readonly storeKey: string = DIRECT_LINK_RULE_FILE_NAME;
  private static saveQueue: Promise<void> = Promise.resolve();

  /** 读当前规则；没存过则回落到默认规则第一条（对齐上游 getRule()）。 */
  static async loadRule(context: Context): Promise<DirectLinkRule> {
    const stored = await DirectLinkUploadStore.loadStored(context);
    if (stored !== undefined) {
      return stored;
    }
    return DEFAULT_DIRECT_LINK_RULES[0];
  }

  /** 只读落盘的那份，没有就返回 undefined（界面用来判断「用户改过没有」）。 */
  static async loadStored(context: Context): Promise<DirectLinkRule | undefined> {
    try {
      const store = await preferences.getPreferences(context, DirectLinkUploadStore.preferenceName);
      const value = await store.get(DirectLinkUploadStore.storeKey, '');
      if (typeof value !== 'string' || value.length === 0) {
        return undefined;
      }
      return DirectLinkUploadStore.parse(value);
    } catch (error) {
      console.error(`[DirectLinkUpload] 读取规则失败: ${error instanceof Error ? error.message : String(error)}`);
      return undefined;
    }
  }

  static saveRule(context: Context, rule: DirectLinkRule): Promise<void> {
    const operation = DirectLinkUploadStore.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, DirectLinkUploadStore.preferenceName);
      await store.put(DirectLinkUploadStore.storeKey, JSON.stringify(rule));
      await store.flush();
    });
    DirectLinkUploadStore.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 对齐上游 delConfig()。 */
  static deleteRule(context: Context): Promise<void> {
    const operation = DirectLinkUploadStore.saveQueue.then(async (): Promise<void> => {
      const store = await preferences.getPreferences(context, DirectLinkUploadStore.preferenceName);
      await store.delete(DirectLinkUploadStore.storeKey);
      await store.flush();
    });
    DirectLinkUploadStore.saveQueue = operation.then((): void => {}, (_error: Error): void => {});
    return operation;
  }

  /** 逐字段校验，缺项按空串/false 补，坏 JSON 当作没存过。 */
  static parse(raw: string): DirectLinkRule | undefined {
    let parsed: Record<string, Object>;
    try {
      parsed = JSON.parse(raw) as Record<string, Object>;
    } catch (_) {
      return undefined;
    }
    if (parsed === undefined || parsed === null) {
      return undefined;
    }
    const record = parsed;
    const str = (key: string): string => {
      const value = record[key];
      return typeof value === 'string' ? value as string : '';
    };
    const flag = record['compress'];
    return {
      uploadUrl: str('uploadUrl'),
      downloadUrlRule: str('downloadUrlRule'),
      summary: str('summary'),
      compress: typeof flag === 'boolean' ? flag as boolean : false
    };
  }
}

/**
 * 上传本体。上游 DirectLinkUpload.kt:26-71 upLoad()。
 *
 * content 支持字符串与字节两种：书源书单导出给的是 JSON 文本，测试按钮给的是 "{}"，
 * 压缩分支给的是 zip 字节。
 */
export class DirectLinkUpload {
  /**
   * 把 content 传到 rule.uploadUrl 指的位置，返回 downloadUrlRule 从响应里取到的直链。
   * 失败抛 DirectLinkError，message 面向用户。
   */
  static async upload(context: Context, fileName: string, content: string | ArrayBuffer,
    contentType: string, rule: DirectLinkRule): Promise<string> {
    const request = DirectLinkUpload.parseRequest(rule.uploadUrl);
    let uploadName = fileName;
    let uploadContent: string | ArrayBuffer = content;
    let uploadType = contentType;
    // 上游：compress 且不是 zip 时先压，文件名补 .zip、contentType 改 zip。
    if (rule.compress && contentType !== 'application/zip') {
      uploadName = `${fileName}.zip`;
      uploadType = 'application/zip';
      uploadContent = await DirectLinkUpload.zipContent(fileName, content);
    }
    const payload = DirectLinkUpload.buildPayload(request, uploadName, uploadContent, uploadType);
    const session = rcp.createSession({
      headers: DirectLinkUpload.requestHeaders(request)
    });
    try {
      const response = await session.fetch(new rcp.Request(request.url, request.method, undefined, payload, undefined, undefined, {
        transfer: {
          timeout: { connectMs: 15000, transferMs: 120000 }
        }
      }));
      const body = DirectLinkUpload.responseText(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw new DirectLinkError(`上传失败，HTTP ${response.statusCode}${body.length > 0 ? `：${body}` : ''}`);
      }
      // 上游把响应体当 AnalyzeRule 的内容、响应 URL 当 baseUrl 去跑 downloadUrlRule。
      const baseUrl = response.effectiveUrl !== undefined ? response.effectiveUrl.toString() : request.url;
      const downloadUrl = new AnalyzeRule(body, baseUrl).getString(rule.downloadUrlRule).trim();
      if (downloadUrl.length === 0) {
        throw new DirectLinkError(`上传失败,${body}`);
      }
      return downloadUrl;
    } finally {
      session.close();
    }
  }

  /**
   * 拆「地址 + JSON 选项」。上游 AnalyzeUrl.kt 的 findOptionIndex 从右往左找第一个
   * 能解析成 JSON 对象的逗号；这里照做，避免把 URL 路径里本身的逗号当成选项起点。
   */
  static parseRequest(uploadUrl: string): DirectLinkRequest {
    const trimmed = uploadUrl.trim();
    if (trimmed.length === 0) {
      throw new DirectLinkError('上传url未设置');
    }
    let url = trimmed;
    let optionText = '';
    for (let index = trimmed.length - 1; index > 0; index--) {
      if (trimmed.charAt(index) !== ',') {
        continue;
      }
      const candidate = trimmed.substring(index + 1).trim();
      if (!candidate.startsWith('{')) {
        continue;
      }
      let parsed: Record<string, Object> | undefined = undefined;
      try {
        parsed = JSON.parse(candidate) as Record<string, Object>;
      } catch (_) {
        parsed = undefined;
      }
      if (parsed !== undefined && parsed !== null) {
        optionText = candidate;
        url = trimmed.substring(0, index).trim();
        break;
      }
    }
    const request: DirectLinkRequest = {
      url: url,
      method: 'POST',
      headers: {},
      bodyText: '',
      type: ''
    };
    if (optionText.length > 0) {
      DirectLinkUpload.applyOptions(request, optionText);
    }
    return request;
  }

  /** 把选项 JSON 灌进 request；字段缺失保持默认。 */
  private static applyOptions(request: DirectLinkRequest, optionText: string): void {
    let parsed: Record<string, Object> | undefined = undefined;
    try {
      parsed = JSON.parse(optionText) as Record<string, Object>;
    } catch (_) {
      return;
    }
    if (parsed === undefined || parsed === null) {
      return;
    }
    const record = parsed;
    const method = record['method'];
    if (typeof method === 'string' && method.length > 0) {
      request.method = method.toUpperCase();
    }
    const type = record['type'];
    if (typeof type === 'string') {
      request.type = type;
    }
    const headers = record['headers'];
    if (headers !== undefined && headers !== null && typeof headers === 'object') {
      const headerRecord = headers as Record<string, Object>;
      for (const key of Object.keys(headerRecord)) {
        const value = headerRecord[key];
        if (typeof value === 'string') {
          request.headers[key] = value as string;
        }
      }
    }
    const body = record['body'];
    if (typeof body === 'string') {
      request.bodyText = body;
    } else if (body !== undefined && body !== null && typeof body === 'object') {
      request.bodyText = JSON.stringify(body);
    }
  }

  private static requestHeaders(request: DirectLinkRequest): rcp.RequestHeaders {
    const headers: rcp.RequestHeaders = {
      'accept': '*/*'
    };
    for (const key of Object.keys(request.headers)) {
      headers[key] = request.headers[key];
    }
    return headers;
  }

  /**
   * 按 type 组装请求体。multipart 时把 body 里值为 fileRequest 的键换成文件字段
   * （上游 AnalyzeUrl.kt:704-723 就是这么替换的）；其余字段原样作为文本段。
   */
  private static buildPayload(request: DirectLinkRequest, fileName: string,
    content: string | ArrayBuffer, contentType: string): rcp.RequestContent {
    const type = request.type.toLowerCase();
    const isMultipart = type.indexOf('multipart/form-data') >= 0;
    const fields = DirectLinkUpload.bodyFields(request.bodyText);
    if (isMultipart) {
      const formFields: rcp.MultipartFormFields = {};
      for (const key of Object.keys(fields)) {
        const value = fields[key];
        if (value === FILE_PLACEHOLDER) {
          const fileValue: rcp.FormFieldFileValue = {
            contentType: contentType,
            remoteFileName: fileName,
            contentOrPath: { content: content }
          };
          formFields[key] = fileValue;
        } else {
          formFields[key] = value;
        }
      }
      return new rcp.MultipartForm(formFields);
    }
    // 非 multipart：把占位符换成文本内容（上游此时 file 是 String/ByteArray，直接当 body 发）。
    if (request.bodyText.length > 0) {
      const text = typeof content === 'string' ? content : new util.TextDecoder().decodeToString(new Uint8Array(content));
      let bodyText = request.bodyText;
      for (const key of Object.keys(fields)) {
        if (fields[key] === FILE_PLACEHOLDER) {
          bodyText = bodyText.split(FILE_PLACEHOLDER).join(DirectLinkUpload.escapeJson(text));
        }
      }
      return bodyText;
    }
    return typeof content === 'string' ? content : content;
  }

  /** body 文本解析成「键 → 值」，只保留字符串值；解析失败当空表。 */
  private static bodyFields(bodyText: string): Record<string, string> {
    const fields: Record<string, string> = {};
    if (bodyText.trim().length === 0) {
      return fields;
    }
    let parsed: Record<string, Object> | undefined = undefined;
    try {
      parsed = JSON.parse(bodyText) as Record<string, Object>;
    } catch (_) {
      return fields;
    }
    if (parsed === undefined || parsed === null) {
      return fields;
    }
    const record = parsed;
    for (const key of Object.keys(record)) {
      const value = record[key];
      if (typeof value === 'string') {
        fields[key] = value as string;
      }
    }
    return fields;
  }

  /** 把文本转义成能安全塞进 JSON 字符串的形式。 */
  private static escapeJson(text: string): string {
    return text
      .replace(/\\/g, '\\\\')
      .replace(/"/g, '\\"')
      .replace(/\n/g, '\\n')
      .replace(/\r/g, '\\r')
      .replace(/\t/g, '\\t');
  }

  /**
   * 压成 zip 字节。上游用 ZipUtils.zipByteArray；本地没有内存 zip 写入口，
   * 复用 EpubWriter 的 zip 容器写入器（它就是通用 zip 结构，只对 mimetype 条目特殊处理）。
   */
  private static async zipContent(fileName: string, content: string | ArrayBuffer): Promise<ArrayBuffer> {
    const bytes = typeof content === 'string'
      ? new util.TextEncoder().encodeInto(content)
      : new Uint8Array(content);
    return await EpubWriter.build([{ name: fileName, data: bytes }]);
  }

  /** 响应体转文本，取不到返回空串。 */
  private static responseText(response: rcp.Response): string {
    try {
      const text = response.toString();
      return text === null ? '' : text;
    } catch (_) {
      return '';
    }
  }
}
