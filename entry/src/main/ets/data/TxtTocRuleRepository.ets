import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { TxtTocRule } from '../model/TxtTocRule';

/** 批量导入结果，供界面如实反馈新增与覆盖的条数。 */
export interface TxtTocRuleImportOutcome {
  added: number;
  updated: number;
  skipped: number;
}

/**
 * 从启用的规则里挑一条最贴合样本文本的规则。
 * 返回值里的 rule 为空表示没有任何规则达到命中门槛，调用方应退回按字数分章。
 */
export interface TxtTocRuleSelection {
  rule?: TxtTocRule;
  /** 选中规则的「章节样」匹配数，便于界面对照。 */
  matches: number;
}

/**
 * TXT 目录规则的持久化与匹配。
 *
 * 匹配策略对齐上游 app/src/main/java/io/legado/app/model/localBook/TxtTocRuleSelector.kt：
 * - 单条规则至少要有 2 处「章节样」匹配才算命中。像「正文」「尾声」「楔子」这类词
 *   在简介里偶发出现一次，若只要求 1 处，误判会把整本书压成一章，读起来就是空白。
 * - 相邻匹配必须间隔超过 1000 字符才计数。章节之间总隔着正文，而「匹配每一行」的
 *   错误规则会被间隔条件压到很低，不会被当成章节规则。
 * - 规则按 serialNumber 升序参与匹配，命中数相等时低序号优先。
 */
export class TxtTocRuleRepository {
  private static readonly preferenceName: string = 'legado_txt_toc_rules';
  private static readonly preferenceKey: string = 'rules_v1';
  /** 认定一条规则命中所需要的最少章节样匹配数，与上游 MIN_TXT_TOC_CHAPTER_MATCHES 一致。 */
  static readonly minimumChapterMatches: number = 2;
  /** 相邻两次匹配之间至少相隔的字符数，与上游 countChapterLikeMatches 的 minGap 一致。 */
  static readonly minimumMatchGap: number = 1000;
  /** 导入文件大小上限，防止误选大文件占满内存。 */
  private static readonly maximumImportBytes: number = 8 * 1024 * 1024;
  private static cachedRules: TxtTocRule[] = [];

  static getAll(): TxtTocRule[] {
    return TxtTocRuleRepository.cachedRules.map((rule: TxtTocRule) => TxtTocRuleRepository.copyRule(rule));
  }

  /** 按 id 取单条规则，供编辑页回填；找不到返回 undefined。 */
  static findById(id: number): TxtTocRule | undefined {
    const found = TxtTocRuleRepository.cachedRules.find((rule: TxtTocRule) => rule.id === id);
    return found === undefined ? undefined : TxtTocRuleRepository.copyRule(found);
  }

  /** 只取启用的规则，按 serialNumber 升序；匹配与阅读链路都用这一份。 */
  static getEnabled(): TxtTocRule[] {
    return TxtTocRuleRepository.cachedRules
      .filter((rule: TxtTocRule) => rule.enable && rule.chapterRule.trim().length > 0)
      .map((rule: TxtTocRule) => TxtTocRuleRepository.copyRule(rule));
  }

  static async load(context: Context): Promise<TxtTocRule[]> {
    try {
      const store = await preferences.getPreferences(context, TxtTocRuleRepository.preferenceName);
      const raw = await store.get(TxtTocRuleRepository.preferenceKey, '[]');
      if (typeof raw !== 'string') {
        TxtTocRuleRepository.cachedRules = [];
      } else {
        const parsed: TxtTocRule[] = JSON.parse(raw);
        TxtTocRuleRepository.cachedRules = parsed
          .filter((item: TxtTocRule) => TxtTocRuleRepository.isRule(item))
          .map((rule: TxtTocRule) => TxtTocRuleRepository.normalize(rule));
      }
    } catch (_) {
      TxtTocRuleRepository.cachedRules = [];
    }
    return TxtTocRuleRepository.getAll();
  }

  /**
   * 保存一条规则：同 id 覆盖，否则追加。
   * 正则语法错误直接抛错，由调用方提示，不静默存入一条永远无法生效的规则。
   */
  static async save(context: Context, rule: TxtTocRule): Promise<void> {
    if (!TxtTocRuleRepository.isRule(rule)) {
      throw new Error('TXT 目录规则无效');
    }
    const pattern = rule.chapterRule.trim();
    if (pattern.length === 0) {
      throw new Error('章节正则不能为空');
    }
    try {
      new RegExp(pattern, 'm');
    } catch (_) {
      throw new Error('章节正则格式无效');
    }
    const volumePattern = rule.volumeRule.trim();
    if (volumePattern.length > 0) {
      try {
        new RegExp(volumePattern, 'm');
      } catch (_) {
        throw new Error('分卷正则格式无效');
      }
    }
    const existingIndex = TxtTocRuleRepository.cachedRules.findIndex((item: TxtTocRule) => item.id === rule.id);
    const next = [...TxtTocRuleRepository.cachedRules];
    if (existingIndex >= 0) {
      next[existingIndex] = TxtTocRuleRepository.normalize(rule);
    } else {
      next.push(TxtTocRuleRepository.normalize(rule));
    }
    await TxtTocRuleRepository.persist(context, next);
  }

  static async remove(context: Context, id: number): Promise<void> {
    await TxtTocRuleRepository.persist(context,
      TxtTocRuleRepository.cachedRules.filter((rule: TxtTocRule) => rule.id !== id));
  }

  /**
   * 批量删除。
   * @returns 实际删除的条数，用于区分「没选中」与「选中项已不存在」。
   */
  static async removeBatch(context: Context, ids: number[]): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    const next = TxtTocRuleRepository.cachedRules.filter((rule: TxtTocRule) => !ids.includes(rule.id));
    const removed = TxtTocRuleRepository.cachedRules.length - next.length;
    if (removed === 0) {
      return 0;
    }
    await TxtTocRuleRepository.persist(context, next);
    return removed;
  }

  static async setEnabled(context: Context, id: number, enabled: boolean): Promise<void> {
    await TxtTocRuleRepository.persist(context, TxtTocRuleRepository.cachedRules.map((rule: TxtTocRule) => {
      if (rule.id !== id) {
        return rule;
      }
      const copy = TxtTocRuleRepository.copyRule(rule);
      copy.enable = enabled;
      return copy;
    }));
  }

  /**
   * 批量启用/停用。
   * @returns 实际改变的条数，避免把「本来就是这个状态」算作本次结果。
   */
  static async setEnabledBatch(context: Context, ids: number[], enabled: boolean): Promise<number> {
    if (ids.length === 0) {
      return 0;
    }
    let changed = 0;
    const next = TxtTocRuleRepository.cachedRules.map((rule: TxtTocRule) => {
      if (ids.includes(rule.id) && rule.enable !== enabled) {
        changed += 1;
        const copy = TxtTocRuleRepository.copyRule(rule);
        copy.enable = enabled;
        return copy;
      }
      return rule;
    });
    if (changed === 0) {
      return 0;
    }
    await TxtTocRuleRepository.persist(context, next);
    return changed;
  }

  /**
   * 把规则移动到指定位置，用于排序与拖拽。
   * 落位后重排 serialNumber，让存储顺序与匹配优先级保持一致。
   */
  static async moveRule(context: Context, fromId: number, toIndex: number): Promise<void> {
    const fromIndex = TxtTocRuleRepository.cachedRules.findIndex((rule: TxtTocRule) => rule.id === fromId);
    if (fromIndex < 0) {
      return;
    }
    const next = [...TxtTocRuleRepository.cachedRules];
    const moved = next.splice(fromIndex, 1)[0];
    const target = Math.max(0, Math.min(next.length, toIndex));
    next.splice(target, 0, moved);
    await TxtTocRuleRepository.persist(context, next);
  }

  /**
   * 批量导入：同 id 或同章节正则视为同一条，命中时保留已有 id 覆盖其余字段。
   * 非法正则条目计入 skipped 后跳过，不因为一条坏规则丢掉整份文件。
   */
  static async importRules(context: Context, incoming: TxtTocRule[]): Promise<TxtTocRuleImportOutcome> {
    const next = [...TxtTocRuleRepository.cachedRules];
    let added = 0;
    let updated = 0;
    let skipped = 0;
    incoming.forEach((rule: TxtTocRule) => {
      const pattern = typeof rule.chapterRule === 'string' ? rule.chapterRule.trim() : '';
      if (!TxtTocRuleRepository.isRule(rule) || pattern.length === 0) {
        skipped += 1;
        return;
      }
      try {
        new RegExp(pattern, 'm');
      } catch (_) {
        skipped += 1;
        return;
      }
      const existingIndex = next.findIndex((item: TxtTocRule) =>
        item.id === rule.id || item.chapterRule.trim() === pattern);
      if (existingIndex >= 0) {
        const merged = TxtTocRuleRepository.normalize(rule);
        merged.id = next[existingIndex].id;
        next[existingIndex] = merged;
        updated += 1;
      } else {
        next.push(TxtTocRuleRepository.normalize(rule));
        added += 1;
      }
    });
    if (added === 0 && updated === 0) {
      return { added: added, updated: updated, skipped: skipped };
    }
    await TxtTocRuleRepository.persist(context, next);
    return { added: added, updated: updated, skipped: skipped };
  }

  /**
   * 导出为与上游 txtTocRule.json 一致的 JSON 数组。
   * 字段名用 chapterRule/volumeRule/example/serialNumber/enable，Android 端可直接读回。
   */
  static exportRules(rules: TxtTocRule[]): string {
    const ordered: TxtTocRule[] = rules.map((rule: TxtTocRule, index: number) => {
      const copy = TxtTocRuleRepository.copyRule(rule);
      copy.serialNumber = index;
      return copy;
    });
    return JSON.stringify(ordered, null, 2);
  }

  /**
   * 从启用的规则里挑一条最贴合样本文本的规则。
   * 实现对齐上游 selectTxtTocRule：倒序遍历（低序号优先），命中数严格大于当前最大值才替换，
   * 因此命中数相等时先参与的高序号被后到的低序号覆盖。
   */
  static selectForSample(sample: string): TxtTocRuleSelection {
    // 样本必须先统一行尾：ArkTS 的正则在多行模式下只把 \n 当作行终止符，
    // $ 不会匹配到 \r 之前，而 Windows 文本每行都以 \r\n 结尾。
    // 不归一的话，所有以 `.{0,30}$` 收尾的内置规则在 CRLF 文本上都会 0 命中，
    // 书会被误判成「没有可用目录规则」而退回按字数分章。
    // 章节切分本身不受影响：splitChapterStarts 逐行处理时已经去掉了行尾 \r。
    const normalized = sample.indexOf('\r') >= 0 ? sample.replace(/\r\n?/g, '\n') : sample;
    const rules = TxtTocRuleRepository.getEnabled();
    let maxMatches = TxtTocRuleRepository.minimumChapterMatches;
    let best: TxtTocRule | undefined = undefined;
    let bestMatches = 0;
    for (let index = rules.length - 1; index >= 0; index--) {
      const rule = rules[index];
      let pattern: RegExp;
      try {
        pattern = new RegExp(rule.chapterRule, 'gm');
      } catch (_) {
        // 语法错误的规则直接跳过，不影响其余规则参与匹配。
        continue;
      }
      const matches = TxtTocRuleRepository.countChapterLikeMatches(pattern, normalized);
      if (matches >= maxMatches) {
        maxMatches = matches;
        best = rule;
        bestMatches = matches;
      }
    }
    return { rule: best, matches: bestMatches };
  }

  /**
   * 统计「章节样」的匹配数。
   * 空匹配（如 (?=…) 或空正则）不构成章节，直接跳过；
   * 与上一处计数的间隔不超过 minimumMatchGap 的匹配也不计数。
   */
  static countChapterLikeMatches(pattern: RegExp, sample: string): number {
    let start = 0;
    let count = 0;
    let match = pattern.exec(sample);
    while (match !== null) {
      const value = match[0];
      if (value.length > 0) {
        const matchStart = match.index;
        if (start === 0 || matchStart - start > TxtTocRuleRepository.minimumMatchGap) {
          count += 1;
          start = matchStart + value.length;
        }
      } else {
        // 零宽匹配要手动推进，否则 exec 会原地死循环。
        pattern.lastIndex += 1;
      }
      if (pattern.lastIndex > sample.length) {
        break;
      }
      match = pattern.exec(sample);
    }
    return count;
  }

  /**
   * 用一条规则切出章节的起始偏移。
   *
   * 逐行匹配、命中则记录该行行首偏移，而不是整段 findAll。两个原因：
   * 1. 本地阅读器按「章节起点到下一章起点」取正文，起点落在行首才不会有半截标题；
   * 2. 逐行判断天然把「正文里提到的第X章」挡在外面，只有独占一行的标题才算章节。
   *
   * 注意这里用原始行（只去掉行尾 \r）参与匹配，不做 trim：
   * 内置规则「目录(去空白)」靠 (?<=[　\s]) 识别「　第1章」这类带缩进的标题，
   * trim 掉前导空白会让这条规则永远匹配不到。
   */
  static splitChapterStarts(content: string, chapterRule: string): number[] {
    const pattern = chapterRule.trim();
    if (pattern.length === 0) {
      return [];
    }
    let regex: RegExp;
    try {
      regex = new RegExp(pattern, 'm');
    } catch (_) {
      return [];
    }
    const starts: number[] = [];
    const lines = content.split('\n');
    let offset = 0;
    for (let index = 0; index < lines.length; index++) {
      const rawLine = lines[index] ?? '';
      const line = rawLine.replace(/\r$/, '');
      if (line.trim().length > 0) {
        regex.lastIndex = 0;
        if (regex.test(line)) {
          starts.push(offset);
        }
      }
      offset += rawLine.length + (index < lines.length - 1 ? 1 : 0);
    }
    return starts;
  }

  /**
   * 读取打包在 rawfile 里的内置规则库。
   * 读不到或解析失败时返回空数组，由调用方提示，不阻断规则页其它操作。
   */
  static loadBuiltinRules(context: Context): TxtTocRule[] {
    try {
      const bytes = context.resourceManager.getRawFileContentSync('txttoc/builtin-rules.json');
      const text = new util.TextDecoder('utf-8').decodeToString(bytes);
      const parsed: TxtTocRule[] = JSON.parse(text);
      return parsed
        .filter((item: TxtTocRule) => TxtTocRuleRepository.isRule(item))
        .map((rule: TxtTocRule) => TxtTocRuleRepository.normalize(rule));
    } catch (_) {
      return [];
    }
  }

  private static async persist(context: Context, rules: TxtTocRule[]): Promise<void> {
    const ordered = rules.map((rule: TxtTocRule, index: number) => {
      const copy = TxtTocRuleRepository.copyRule(rule);
      copy.serialNumber = index;
      return copy;
    });
    const store = await preferences.getPreferences(context, TxtTocRuleRepository.preferenceName);
    await store.put(TxtTocRuleRepository.preferenceKey, JSON.stringify(ordered));
    await store.flush();
    TxtTocRuleRepository.cachedRules = ordered;
  }

  private static copyRule(rule: TxtTocRule): TxtTocRule {
    return {
      id: rule.id,
      name: rule.name,
      chapterRule: rule.chapterRule,
      volumeRule: rule.volumeRule,
      example: rule.example,
      serialNumber: rule.serialNumber,
      enable: rule.enable
    };
  }

  /** 补齐缺失字段并做类型收敛，避免旧数据或手工编辑的 JSON 把 undefined 带进匹配链路。 */
  private static normalize(rule: TxtTocRule): TxtTocRule {
    return {
      id: typeof rule.id === 'number' ? rule.id : Date.now(),
      name: typeof rule.name === 'string' ? rule.name : '',
      chapterRule: typeof rule.chapterRule === 'string' ? rule.chapterRule : '',
      volumeRule: typeof rule.volumeRule === 'string' ? rule.volumeRule : '',
      example: typeof rule.example === 'string' ? rule.example : undefined,
      serialNumber: typeof rule.serialNumber === 'number' ? rule.serialNumber : -1,
      enable: typeof rule.enable === 'boolean' ? rule.enable : true
    };
  }

  private static isRule(value: TxtTocRule): boolean {
    return value !== null && value !== undefined && typeof value.id === 'number' &&
      typeof value.name === 'string' && typeof value.chapterRule === 'string';
  }
}
