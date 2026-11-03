/**
 * 替换净化规则的正则执行器。
 *
 * 上游 `help/book/ContentProcessor.kt:180-215` 用一条带截止时间的 `CharSequence`
 * 包住正文，`get(index)` 里发现超时就抛 `RegexTimeoutException`，捕获后把该规则
 * `isEnabled = false` 落库、并让本章正文显示「规则名 + 堆栈」。
 *
 * ArkTS 的正则执行是原子的，拿不到逐字符回调，所以换一条等价路子：
 * 把整轮替换搬进 taskpool worker，worker 内部逐条计时，单条超过该规则的
 * `timeoutMillisecond`（<=0 时取 3000，与上游 `ReplaceRule.getValidTimeoutMillisecond()`
 * 同口径）就判这条超时、停用后续、正文换成提示文案。
 *
 * 这样即使遇到灾难性回溯的病态表达式，也只是 worker 卡住，UI 线程不受影响。
 */

/** worker 入参：只带执行必需的字段，避免把整本规则表搬进线程。 */
export interface ReplaceRuleWorkerInput {
  id: number;
  name: string;
  pattern: string;
  replacement: string;
  isRegex: boolean;
  timeoutMillisecond: number;
}

/** worker 结果：命中过正文的规则 id，以及判定超时的规则 id。 */
export interface ReplaceRuleWorkerResult {
  text: string;
  effectiveRuleIds: number[];
  timedOutRuleIds: number[];
}

/** 规则没填超时（或填了非正数）时的兜底预算，与上游 ReplaceRule.kt:114-119 一致。 */
export const DEFAULT_REPLACE_TIMEOUT_MILLIS: number = 3000;

/**
 * 在 worker 线程里按顺序跑一遍替换规则。
 *
 * 逐行 trim 后再替换，对齐上游 `mContent.lines().joinToString("\n") { it.trim() }`；
 * 只有正文真的变了才把规则记进 effectiveRuleIds（上游 `if (mContent != tmp)`）。
 */
@Concurrent
export function applyReplaceRulesInWorker(content: string, rules: ReplaceRuleWorkerInput[]):
  ReplaceRuleWorkerResult {
  // @Concurrent 函数只能引用 import 进来的变量或函数内的局部变量，
  // 所以这里把兜底预算写成局部常量（值同 DEFAULT_REPLACE_TIMEOUT_MILLIS）。
  const fallbackBudget: number = 3000;
  let result = content.split(/\r?\n/).map((line: string) => line.trim()).join('\n');
  const effectiveRuleIds: number[] = [];
  const timedOutRuleIds: number[] = [];
  for (let index = 0; index < rules.length; index++) {
    const rule = rules[index];
    if (rule.pattern.length === 0) {
      continue;
    }
    const budget = rule.timeoutMillisecond > 0 ? rule.timeoutMillisecond : fallbackBudget;
    const startedAt = Date.now();
    let replaced = result;
    try {
      replaced = rule.isRegex
        ? result.replace(new RegExp(rule.pattern, 'g'), rule.replacement)
        : result.split(rule.pattern).join(rule.replacement);
    } catch (_) {
      // 无效正则或当前运行时不支持的写法：不改变正文，也不打断阅读。
      continue;
    }
    if (Date.now() - startedAt > budget) {
      // 单条规则跑超预算：停用该规则，本章正文换成提示文案，后续规则继续跑
      // （上游 catch 之后也继续 forEach 后面的规则）。
      timedOutRuleIds.push(rule.id);
      result = `${rule.name}\n该替换规则执行超过 ${budget} 毫秒，已自动停用。`;
      continue;
    }
    if (replaced !== result) {
      result = replaced;
      effectiveRuleIds.push(rule.id);
    }
  }
  return { text: result, effectiveRuleIds: effectiveRuleIds, timedOutRuleIds: timedOutRuleIds };
}
