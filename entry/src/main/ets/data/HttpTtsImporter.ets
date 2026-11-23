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

/**
 * 单条原始源；字段全部可选，兼容不同来源的缺省。loginUi 上游可能是 JSON 数组。
 * speakersJson / emotionsJson 是源自带的音色与情绪目录，只用于恢复时重建
 * read_aloud_voices，不写回 httpTTS 表（上游 Restore.kt:566-570 的注释同理）。
 */
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
  speakersJson?: string;
  emotionsJson?: string;
}

/** 单个发言人的目录项，对应上游 HttpTtsSpeakerDraft。 */
export interface HttpTtsSpeakerDraft {
  speakerName: string;
  toneID: string;
  tags: string[];
}

/** 单个情绪标签的目录项，对应上游 HttpTtsEmotionDraft。 */
export interface HttpTtsEmotionDraft {
  emotionName: string;
  emotionTag: string;
}

/** 一个源自带的目录，对应上游 HttpTtsCatalogDraft。 */
export interface HttpTtsCatalogDraft {
  speakers: HttpTtsSpeakerDraft[];
  emotions: HttpTtsEmotionDraft[];
}

/** 目录数组元素的原始形态：speakersJson / emotionsJson 两个字符串字段。 */
interface RawCatalogHolder {
  speakersJson?: string;
  emotionsJson?: string;
}

/** 目录内部单个元素的原始形态：平铺项或分组项，字段别名一并兼容。 */
interface RawCatalogItem {
  speakerName?: string;
  name?: string;
  toneID?: string;
  toneId?: string;
  tone_id?: string;
  tags?: Object[];
  items?: Object[];
  emotionName?: string;
  emotionTag?: string;
  tag?: string;
  value?: string;
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

  /**
   * 解析 httpTTS.json 里每一条源自带的目录，返回顺序与源数组同序，便于按下标配对。
   * 对应上游 `HttpTtsCatalogParser.parseList`：顶层是数组就逐元素解析，
   * 不是数组（单对象）就退化成一次单对象解析；整体解析失败返回空数组，
   * 由调用方按「条数与源条数不一致」处理，而不是猜一个默认目录。
   */
  static parseCatalogs(text: string): HttpTtsCatalogDraft[] {
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return [];
    }
    try {
      if (trimmed.startsWith('[')) {
        const items: Object[] = JSON.parse(trimmed) as Object[];
        if (!Array.isArray(items)) {
          return [HttpTtsImporter.parseCatalogText(trimmed)];
        }
        return items.map((item: Object): HttpTtsCatalogDraft =>
          HttpTtsImporter.parseCatalogObject(item));
      }
      if (trimmed.startsWith('{')) {
        return [HttpTtsImporter.parseCatalogText(trimmed)];
      }
    } catch (_) {
      // 落到下面统一按「目录不可解析」处理。
    }
    return [];
  }

  /** 解析一个 JSON 文本形态的目录（顶层是单个对象）。 */
  private static parseCatalogText(text: string): HttpTtsCatalogDraft {
    try {
      const holder: RawCatalogHolder = JSON.parse(text) as RawCatalogHolder;
      return HttpTtsImporter.parseCatalogObject(holder);
    } catch (_) {
      return { speakers: [], emotions: [] };
    }
  }

  /** 从已解析的对象取两个目录字段；非字符串形态按空处理，与上游 readString 一致。 */
  private static parseCatalogObject(item: Object): HttpTtsCatalogDraft {
    const holder: RawCatalogHolder = item as RawCatalogHolder;
    const speakersJson = typeof holder.speakersJson === 'string' ? holder.speakersJson : undefined;
    const emotionsJson = typeof holder.emotionsJson === 'string' ? holder.emotionsJson : undefined;
    return {
      speakers: HttpTtsImporter.parseSpeakers(speakersJson),
      emotions: HttpTtsImporter.parseEmotions(emotionsJson)
    };
  }

  /** 解析发言人目录：平铺项在前、分组项在后，同一 toneID 只保留首次出现的那条。 */
  private static parseSpeakers(json?: string): HttpTtsSpeakerDraft[] {
    const flat: HttpTtsSpeakerDraft[] = [];
    const grouped: HttpTtsSpeakerDraft[] = [];
    HttpTtsImporter.catalogElements(json).forEach((item: RawCatalogItem) => {
      const items = item.items;
      if (items !== undefined && Array.isArray(items)) {
        items.forEach((child: Object) => {
          const draft = HttpTtsImporter.speakerFrom(child as RawCatalogItem);
          if (draft !== undefined) { grouped.push(draft); }
        });
      } else {
        const draft = HttpTtsImporter.speakerFrom(item);
        if (draft !== undefined) { flat.push(draft); }
      }
    });
    return HttpTtsImporter.distinctSpeakers(flat.concat(grouped));
  }

  /** 解析情绪目录：结构与发言人一致，同一 emotionTag 只保留首次出现的那条。 */
  private static parseEmotions(json?: string): HttpTtsEmotionDraft[] {
    const flat: HttpTtsEmotionDraft[] = [];
    const grouped: HttpTtsEmotionDraft[] = [];
    HttpTtsImporter.catalogElements(json).forEach((item: RawCatalogItem) => {
      const items = item.items;
      if (items !== undefined && Array.isArray(items)) {
        items.forEach((child: Object) => {
          const draft = HttpTtsImporter.emotionFrom(child as RawCatalogItem);
          if (draft !== undefined) { grouped.push(draft); }
        });
      } else {
        const draft = HttpTtsImporter.emotionFrom(item);
        if (draft !== undefined) { flat.push(draft); }
      }
    });
    return HttpTtsImporter.distinctEmotions(flat.concat(grouped));
  }

  /** 顶层是数组就展开，是单个对象就包一层；空串与非对象元素一律丢弃。 */
  private static catalogElements(json?: string): RawCatalogItem[] {
    if (json === undefined || json === null || json.trim().length === 0) {
      return [];
    }
    try {
      const parsed: Object = JSON.parse(json) as Object;
      if (Array.isArray(parsed)) {
        const items: Object[] = parsed as Object[];
        return items.filter((item: Object): boolean => item !== null && typeof item === 'object') as RawCatalogItem[];
      }
      if (parsed !== null && typeof parsed === 'object') {
        return [parsed as RawCatalogItem];
      }
    } catch (_) {
      // 目录文本损坏时按「没有目录」处理：源本身仍然可以恢复。
    }
    return [];
  }

  /** 取一个发言人；缺名字或缺 toneID 的条目丢弃——只有名字的发言人是没法合成的。 */
  private static speakerFrom(item: RawCatalogItem): HttpTtsSpeakerDraft | undefined {
    const speakerName = HttpTtsImporter.firstString([item.speakerName, item.name]);
    const toneID = HttpTtsImporter.firstString([item.toneID, item.toneId, item.tone_id]);
    if (speakerName === undefined || toneID === undefined) {
      return undefined;
    }
    return { speakerName: speakerName, toneID: toneID, tags: HttpTtsImporter.stringArray(item.tags) };
  }

  /** 取一个情绪标签；缺名字或缺 tag 的条目丢弃。 */
  private static emotionFrom(item: RawCatalogItem): HttpTtsEmotionDraft | undefined {
    const emotionName = HttpTtsImporter.firstString([item.emotionName, item.name]);
    const emotionTag = HttpTtsImporter.firstString([item.emotionTag, item.tag, item.value]);
    if (emotionName === undefined || emotionTag === undefined) {
      return undefined;
    }
    return { emotionName: emotionName, emotionTag: emotionTag };
  }

  /** 按字段别名顺序取第一个非空白字符串。 */
  private static firstString(values: (string | undefined)[]): string | undefined {
    for (let index = 0; index < values.length; index++) {
      const value = values[index];
      if (typeof value === 'string' && value.trim().length > 0) {
        return value;
      }
    }
    return undefined;
  }

  /** 只收非空字符串元素的数组，非数组或非字符串元素一律忽略。 */
  private static stringArray(values?: Object[]): string[] {
    if (values === undefined || !Array.isArray(values)) {
      return [];
    }
    const result: string[] = [];
    values.forEach((value: Object) => {
      if (typeof value === 'string' && value.trim().length > 0) {
        result.push(value);
      }
    });
    return result;
  }

  /** 按 toneID 去重，保留首次出现。 */
  private static distinctSpeakers(items: HttpTtsSpeakerDraft[]): HttpTtsSpeakerDraft[] {
    const seen: string[] = [];
    const result: HttpTtsSpeakerDraft[] = [];
    items.forEach((item: HttpTtsSpeakerDraft) => {
      if (seen.indexOf(item.toneID) >= 0) { return; }
      seen.push(item.toneID);
      result.push(item);
    });
    return result;
  }

  /** 按 emotionTag 去重，保留首次出现。 */
  private static distinctEmotions(items: HttpTtsEmotionDraft[]): HttpTtsEmotionDraft[] {
    const seen: string[] = [];
    const result: HttpTtsEmotionDraft[] = [];
    items.forEach((item: HttpTtsEmotionDraft) => {
      if (seen.indexOf(item.emotionTag) >= 0) { return; }
      seen.push(item.emotionTag);
      result.push(item);
    });
    return result;
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
