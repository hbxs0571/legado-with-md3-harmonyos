import { HttpTts } from '../model/HttpTts';
import { ReadAloudVoice } from '../model/ReadAloudVoice';

/** 导入解析结果。skipped 记录无法解析成合法条目的数量，供恢复结果如实反馈。 */
export interface HttpTtsImportParse {
  sources: HttpTts[];
  skipped: number;
}

/** 音色导入解析结果，与源分开计数，备份桥才能把两类反馈分别落到 RestoreResult。 */
export interface ReadAloudVoiceImportParse {
  voices: ReadAloudVoice[];
  skipped: number;
}

/** 单条原始源；字段全部可选，兼容不同来源的缺省。loginUi 上游可能是 JSON 数组。 */
interface RawHttpTts {
  id?: number;
  name?: string;
  url?: string;
  contentType?: string;
  concurrentRate?: string;
  loginUrl?: string;
  loginUi?: string | Object[];
  header?: string;
  jsLib?: string;
  enabledCookieJar?: boolean;
  loginCheckJs?: string;
  speed?: number;
  synthesisThreadCount?: number;
  lastUpdateTime?: number;
}

/** 单条原始音色；字段全部可选，兼容旧备份里的缺省列。 */
interface RawReadAloudVoice {
  id?: string;
  engineType?: string;
  engineId?: string;
  speakerId?: string;
  displayName?: string;
  traitsJson?: string;
  emotionCatalogJson?: string;
  managedBy?: string;
  enabled?: boolean;
  available?: boolean;
  excluded?: boolean;
  revision?: number;
  createdAt?: number;
  updatedAt?: number;
}

/** 上游 HttpTTS.MAX_SYNTHESIS_THREAD_COUNT：合成并发上限钉死在 1..8。 */
const MAX_SYNTHESIS_THREAD_COUNT: number = 8;

/**
 * 解析 httpTTS.json 与 httpTtsVoices.json。上游 Restore.kt:237-241 只按
 * httpTTS.json 是否解析成功进入音色恢复，所以两类条目各一个解析器、各自计数，
 * 恢复侧才能把「源」与「音色」的失败分开反馈。
 * 只保留数组与单对象两种文本分支：本地没有网络能力，也没有 URI 入口。
 */
export class HttpTtsImporter {
  static parseSources(text: string): HttpTtsImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { sources: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawHttpTts[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { sources: [], skipped: 1 };
        }
        const sources: HttpTts[] = [];
        let skipped = 0;
        items.forEach((item: RawHttpTts) => {
          const source = HttpTtsImporter.toSource(item);
          if (source === undefined) {
            skipped += 1;
          } else {
            sources.push(source);
          }
        });
        return { sources: sources, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawHttpTts = JSON.parse(trimmed);
        const source = HttpTtsImporter.toSource(single);
        if (source === undefined) {
          return { sources: [], skipped: 1 };
        }
        return { sources: [source], skipped: 0 };
      }
    } catch (_) {
      // 落到下面统一按「格式不可识别」处理。
    }
    return { sources: [], skipped: 1 };
  }

  static parseVoices(text: string): ReadAloudVoiceImportParse {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return { voices: [], skipped: 0 };
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: RawReadAloudVoice[] = JSON.parse(trimmed);
        if (!Array.isArray(items)) {
          return { voices: [], skipped: 1 };
        }
        const voices: ReadAloudVoice[] = [];
        let skipped = 0;
        items.forEach((item: RawReadAloudVoice) => {
          const voice = HttpTtsImporter.toVoice(item);
          if (voice === undefined) {
            skipped += 1;
          } else {
            voices.push(voice);
          }
        });
        return { voices: voices, skipped: skipped };
      }
      if (trimmed.startsWith('{')) {
        const single: RawReadAloudVoice = JSON.parse(trimmed);
        const voice = HttpTtsImporter.toVoice(single);
        if (voice === undefined) {
          return { voices: [], skipped: 1 };
        }
        return { voices: [voice], skipped: 0 };
      }
    } catch (_) {
      // 落到下面统一按「格式不可识别」处理。
    }
    return { voices: [], skipped: 1 };
  }

  /** 把一条原始数据转换成源；缺非零 id 或空 name 的条目没有落库依据，按无效跳过。 */
  private static toSource(raw: RawHttpTts): HttpTts | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    if (typeof raw.id !== 'number' || raw.id === 0) {
      return undefined;
    }
    const name = typeof raw.name === 'string' ? raw.name : '';
    if (name.length === 0) {
      return undefined;
    }
    // 上游 HttpTTS.fromJsonDoc 把 List 型的 loginUi 用 GSON.toJson 转回字符串，
    // 这里用 JSON.stringify 做同一件事，保证数组形态不会在写库时丢成 [object Object]。
    let loginUi: string | undefined = undefined;
    const rawLoginUi: string | Object[] | undefined = raw.loginUi;
    if (rawLoginUi !== undefined && Array.isArray(rawLoginUi)) {
      loginUi = JSON.stringify(rawLoginUi);
    } else if (typeof rawLoginUi === 'string') {
      loginUi = rawLoginUi;
    }
    // 上游 coerceIn(1, MAX_SYNTHESIS_THREAD_COUNT)：超范围夹到边界，
    // 缺失或非数字按 1，避免把非法并发数直接写进备份。
    let threads = 1;
    if (typeof raw.synthesisThreadCount === 'number') {
      threads = Math.min(MAX_SYNTHESIS_THREAD_COUNT, Math.max(1, raw.synthesisThreadCount));
    }
    return {
      id: raw.id,
      name: name,
      url: typeof raw.url === 'string' ? raw.url : '',
      contentType: typeof raw.contentType === 'string' ? raw.contentType : undefined,
      concurrentRate: typeof raw.concurrentRate === 'string' ? raw.concurrentRate : undefined,
      loginUrl: typeof raw.loginUrl === 'string' ? raw.loginUrl : undefined,
      loginUi: loginUi,
      header: typeof raw.header === 'string' ? raw.header : undefined,
      jsLib: typeof raw.jsLib === 'string' ? raw.jsLib : undefined,
      enabledCookieJar: typeof raw.enabledCookieJar === 'boolean' ? raw.enabledCookieJar : undefined,
      loginCheckJs: typeof raw.loginCheckJs === 'string' ? raw.loginCheckJs : undefined,
      speed: typeof raw.speed === 'number' ? raw.speed : undefined,
      synthesisThreadCount: threads,
      lastUpdateTime: typeof raw.lastUpdateTime === 'number' ? raw.lastUpdateTime : 0
    };
  }

  /** 把一条原始数据转换成音色；缺 id 或空 engineType 的条目按无效跳过，不塞默认值。 */
  private static toVoice(raw: RawReadAloudVoice): ReadAloudVoice | undefined {
    if (raw === undefined || raw === null) {
      return undefined;
    }
    if (typeof raw.id !== 'string' || raw.id.length === 0) {
      return undefined;
    }
    if (typeof raw.engineType !== 'string' || raw.engineType.length === 0) {
      return undefined;
    }
    return {
      id: raw.id,
      engineType: raw.engineType,
      engineId: typeof raw.engineId === 'string' ? raw.engineId : '',
      speakerId: typeof raw.speakerId === 'string' ? raw.speakerId : '',
      displayName: typeof raw.displayName === 'string' ? raw.displayName : '',
      traitsJson: typeof raw.traitsJson === 'string' ? raw.traitsJson : '[]',
      emotionCatalogJson: typeof raw.emotionCatalogJson === 'string' ? raw.emotionCatalogJson : '[]',
      managedBy: typeof raw.managedBy === 'string' ? raw.managedBy : 'user',
      enabled: typeof raw.enabled === 'boolean' ? raw.enabled : true,
      available: typeof raw.available === 'boolean' ? raw.available : true,
      excluded: typeof raw.excluded === 'boolean' ? raw.excluded : false,
      revision: typeof raw.revision === 'number' ? raw.revision : 0,
      createdAt: typeof raw.createdAt === 'number' ? raw.createdAt : 0,
      updatedAt: typeof raw.updatedAt === 'number' ? raw.updatedAt : 0
    };
  }
}
