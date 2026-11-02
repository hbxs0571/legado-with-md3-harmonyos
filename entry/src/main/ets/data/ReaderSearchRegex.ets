/**
 * 正则搜索的时间预算（对齐上游 `utils/RegexDeadlineSequence.kt` + `ReaderSearchMatcher.kt`）。
 *
 * 上游做法是给 Java 正则包一层带截止时间的 `CharSequence`，`charAt` 里检查超时并抛异常打断
 * matcher。ArkTS 的正则引擎是 V8 的，拿不到这种逐字符回调，所以换成：
 * 把整段正则匹配丢进 taskpool 的 worker 线程跑，主线程用 Promise.race 加 500ms 预算。
 * 超时后主线程立刻放弃这一章继续往下搜，**界面不会被一条灾难性回溯的正则冻住**；
 * worker 里那次匹配会自己跑完再被丢弃，不影响主线程。
 */
import { taskpool } from '@kit.ArkTS';

/** 一条命中：起始下标与长度，字段与上游 `ReaderSearchMatch` 同口径。 */
export interface ReaderRegexHit {
  position: number;
  length: number;
}

/** worker 侧执行体：不可捕获闭包变量，所有入参都必须显式传。 */
@Concurrent
function matchInWorker(content: string, pattern: string, limit: number): ReaderRegexHit[] {
  const hits: ReaderRegexHit[] = [];
  const matcher = new RegExp(pattern, 'g');
  let match = matcher.exec(content);
  while (match !== null && hits.length < limit) {
    const length = match[0].length;
    if (length > 0) {
      hits.push({ position: match.index, length: length } as ReaderRegexHit);
    } else {
      // 零宽匹配：手动前进一位，否则 exec 会原地打转。
      matcher.lastIndex++;
    }
    match = matcher.exec(content);
  }
  return hits;
}

/** 正则本身不合法时抛这个，调用方按「正则表达式无效」提示。 */
export class ReaderRegexInvalidError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ReaderRegexInvalidError';
  }
}

export class ReaderSearchRegex {
  /** 单章正则匹配的时间预算，与上游 `REGEX_MATCH_TIMEOUT_MILLIS = 500` 一致。 */
  static readonly MATCH_TIMEOUT_MILLIS: number = 500;

  /**
   * 在主线程之外跑一次正则匹配。
   * @returns 命中列表；超时返回 `timedOut: true` 且 hits 为空。
   */
  static async run(content: string, pattern: string, limit: number): Promise<ReaderRegexResult> {
    // 先在本线程做一次语法校验：非法正则要立刻报「正则表达式无效」，
    // 而不是丢进 worker 后变成一句笼统的超时。
    try {
      new RegExp(pattern, 'g');
    } catch (_) {
      throw new ReaderRegexInvalidError('正则表达式无效');
    }
    const task = new taskpool.Task(matchInWorker, content, pattern, limit);
    let timer: number = -1;
    const timeout = new Promise<ReaderRegexResult>((resolve: (value: ReaderRegexResult) => void) => {
      timer = setTimeout(() => {
        // 超时后取消任务；worker 已经在跑的匹配无法中断，但它不在主线程，界面不受影响。
        try { taskpool.cancel(task); } catch (_) { }
        resolve({ hits: [], timedOut: true } as ReaderRegexResult);
      }, ReaderSearchRegex.MATCH_TIMEOUT_MILLIS);
    });
    const matched = taskpool.execute(task).then((value: Object): ReaderRegexResult => {
      return { hits: value as ReaderRegexHit[], timedOut: false } as ReaderRegexResult;
    }).catch((_error: Error): ReaderRegexResult => {
      return { hits: [], timedOut: true } as ReaderRegexResult;
    });
    try {
      return await Promise.race([matched, timeout]);
    } finally {
      if (timer >= 0) { clearTimeout(timer); }
    }
  }
}

/** 一次正则匹配的结果。 */
export interface ReaderRegexResult {
  hits: ReaderRegexHit[];
  /** true 表示这一章超时被跳过。 */
  timedOut: boolean;
}
