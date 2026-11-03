/**
 * 目录规则预览的扫描引擎（对齐上游 `TxtTocRulePreviewViewModel.analyzeWithPattern`）。
 *
 * 预览页要把几十条规则各自扫一遍全书，一本几 MB 的 TXT 逐条扫下来是几千万次正则调用，
 * 放主线程上必被 watchdog 判成 THREAD_BLOCK_6S。所以整段扫描丢进 taskpool：
 * 主线程只递文件路径、编码和规则列表，worker 自己读文件、解码、扫完再把每条的
 * 章数与前 500 章样本一次性交回来——正文不进任务参数，避免把整本字符串跨线程搬运。
 */
import { taskpool } from '@kit.ArkTS';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';

/** 一条规则的预览结果：`totalCount` 全书命中数，`chapterTitles` 前 N 条样本。 */
export interface TocRulePreviewCount {
  totalCount: number;
  chapterTitles: string[];
}

/**
 * worker 侧：读整本 → 逐条规则扫。
 *
 * `@Concurrent` 只能引用 import 进来的变量或函数内的局部变量，所以读文件、解码、
 * 正则前缀转换、逐行匹配全写在本函数体内，不拆模块级辅助函数。
 */
@Concurrent
export function scanTocPreviewInWorker(path: string, encoding: string, patterns: string[],
  limit: number): TocRulePreviewCount[] {
  let content = '';
  try {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(path);
      const buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      const bytes = new Uint8Array(buffer);
      // 编码名可能带连字符或大小写差异，解不开就退回 UTF-8（与主线程的兜底一致）。
      const candidates: string[] = encoding.length > 0 ? [encoding, 'utf-8'] : ['utf-8'];
      for (let index = 0; index < candidates.length; index++) {
        try {
          const decoder = util.TextDecoder.create(candidates[index], { ignoreBOM: true });
          content = decoder.decodeToString(bytes);
          break;
        } catch (error) {
          content = '';
        }
      }
    } finally {
      fileIo.closeSync(file);
    }
  } catch (error) {
    return [];
  }
  if (content.length === 0) {
    return [];
  }
  // 去掉文件头 BOM，避免首行标题匹配不上。
  if (content.charCodeAt(0) === 0xFEFF) {
    content = content.substring(1);
  }
  const lines: string[] = content.split('\n');
  const results: TocRulePreviewCount[] = [];
  for (let ruleIndex = 0; ruleIndex < patterns.length; ruleIndex++) {
    const source = (patterns[ruleIndex] ?? '').trim();
    let regex: RegExp | undefined = undefined;
    if (source.length > 0) {
      // 与 `TxtTocRuleRepository.compileRegex` 同口径：把 Java 风格的 `(?i)(?m)(?im)`
      // 前缀转成 JS flags；正则写坏时保持 undefined，该条按 0 章处理（上游
      // PatternSyntaxException 同样只给 totalCount = 0）。
      const inline = /^\(\?([ims]+)\)/.exec(source);
      let body = source;
      let flags = 'm';
      if (inline !== null) {
        const requested = inline[1] ?? '';
        body = source.substring(inline[0].length);
        for (let flagIndex = 0; flagIndex < requested.length; flagIndex++) {
          const flag = requested.charAt(flagIndex);
          if (!flags.includes(flag)) {
            flags += flag;
          }
        }
      }
      try {
        regex = new RegExp(body, flags);
      } catch (error) {
        regex = undefined;
      }
    }
    const titles: string[] = [];
    let totalCount = 0;
    if (regex !== undefined) {
      const matcher = regex;
      for (let index = 0; index < lines.length; index++) {
        const line = (lines[index] ?? '').replace(/\r$/, '');
        if (line.trim().length === 0) {
          continue;
        }
        matcher.lastIndex = 0;
        if (!matcher.test(line)) {
          continue;
        }
        totalCount += 1;
        if (titles.length < limit) {
          titles.push(line.trim());
        }
      }
    }
    results.push({ totalCount: totalCount, chapterTitles: titles });
  }
  return results;
}

export class TocRulePreviewEngine {
  /** 单条规则最多收多少章样本，与上游 `chapters.size < 500` 一致。 */
  static readonly chapterSampleLimit: number = 500;

  /**
   * 在 worker 线程里把每条规则的章数与样本一次算完。
   *
   * 失败时返回空数组，调用方据此把卡片显示成 0 章，不会一直转圈。
   */
  static async scan(path: string, encoding: string, patterns: string[]): Promise<TocRulePreviewCount[]> {
    if (path.length === 0 || patterns.length === 0) {
      return [];
    }
    const started = Date.now();
    try {
      const task = new taskpool.Task(scanTocPreviewInWorker, path, encoding, patterns,
        TocRulePreviewEngine.chapterSampleLimit);
      const value = await taskpool.execute(task);
      const list = value as TocRulePreviewCount[];
      console.info(`[TocRulePreviewEngine] 预览扫描完成 ${list.length} 条，耗时 ${Date.now() - started}ms`);
      return list;
    } catch (error) {
      console.error(`[TocRulePreviewEngine] 目录规则预览扫描失败: ${error}`);
      return [];
    }
  }
}
