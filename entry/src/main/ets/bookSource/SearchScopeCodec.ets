/**
 * 搜索范围编解码，逐项对齐上游 `domain/model/BookSearchScope.kt`（181 行）。
 *
 * 编码格式（与上游逐字相同）：
 *   组范围   `{"type":"group","groups":["组名",...]}`
 *   源范围   `{"type":"source","sources":[{"name":"源名","url":"源URL"},...]}`
 *   全部范围 空串 `""`
 *
 * 解析顺序同上游 `parse`：先试 JSON（必须以 `{` 开头 `}` 结尾），失败再走
 * `parseLegacy`（逗号分隔；若每一项都能按 `::` 拆成 name/url 则当源范围，否则当组范围）。
 * legacy 分支是为了兼容上游旧版本存的裸逗号串。
 */

/** 源范围里的一项（上游 `BookSearchScope.ScopeSourceItem`）。 */
export interface ScopeSourceItem {
  name: string;
  url: string;
}

/** 解析结果（上游私有类 `ParsedSearchScope`）。 */
export interface ParsedSearchScope {
  groups: string[];
  sources: ScopeSourceItem[];
}

const TYPE_GROUP: string = 'group';
const TYPE_SOURCE: string = 'source';

/** 空结果（上游 `ParsedSearchScope()` 默认值）。 */
function emptyParsed(): ParsedSearchScope {
  return { groups: [], sources: [] };
}

/** 上游 `:56-57 encodeSource(name, url)`。 */
export function encodeSource(name: string, url: string): string {
  const item: ScopeSourceItem = { name: name, url: url };
  return encodeSources([item]);
}

/** 上游 `:59-71 encodeGroups(groups)`：过滤空白，空列表返回空串。 */
export function encodeGroups(groups: string[]): string {
  const selected: string[] = [];
  for (const group of groups) {
    if (group.trim().length > 0) { selected.push(group); }
  }
  if (selected.length === 0) { return ''; }
  return JSON.stringify({ type: TYPE_GROUP, groups: selected });
}

/** 上游 `:73-90 encodeSources(sources)`：按 url 非空过滤，空列表返回空串。 */
export function encodeSources(sources: ScopeSourceItem[]): string {
  const selected: ScopeSourceItem[] = [];
  for (const source of sources) {
    if (source.url.trim().length > 0) { selected.push(source); }
  }
  if (selected.length === 0) { return ''; }
  const payload: ScopeSourceItem[] = selected.map((source: ScopeSourceItem): ScopeSourceItem => {
    return { name: source.name, url: source.url };
  });
  return JSON.stringify({ type: TYPE_SOURCE, sources: payload });
}

/** 上游 `:130-137 parseLegacy`：逗号分隔，能全部按 `::` 拆成源就当源范围。 */
function parseLegacy(raw: string): ParsedSearchScope {
  const rawItems: string[] = raw.split(',').filter((item: string): boolean => item.trim().length > 0);
  const sourceItems: ScopeSourceItem[] = [];
  for (const item of rawItems) {
    const splitIndex = item.indexOf('::');
    // 上游 `splitIndex <= 0 || splitIndex >= item.lastIndex` 时不算源项
    if (splitIndex > 0 && splitIndex < item.length - 2) {
      sourceItems.push({ name: item.substring(0, splitIndex), url: item.substring(splitIndex + 2) });
    }
  }
  if (rawItems.length > 0 && sourceItems.length === rawItems.length) {
    return { groups: [], sources: sourceItems };
  }
  const groups: string[] = raw.split(',').filter((item: string): boolean => item.trim().length > 0);
  return { groups: groups, sources: [] };
}

/** 上游 `:102-128 parseJson`：格式不对返回 undefined（由调用方回退 legacy）。 */
function parseJson(raw: string): ParsedSearchScope | undefined {
  const json = raw.trim();
  if (!json.startsWith('{') || !json.endsWith('}')) { return undefined; }
  let decoded: Record<string, Object>;
  try {
    decoded = JSON.parse(json) as Record<string, Object>;
  } catch (error) {
    return undefined;
  }
  const type = decoded.type as string | undefined;
  if (type === TYPE_SOURCE) {
    const rawSources = decoded.sources as Object[] | undefined;
    if (rawSources === undefined) { return { groups: [], sources: [] }; }
    const sources: ScopeSourceItem[] = [];
    for (const entry of rawSources) {
      const item = entry as Record<string, Object>;
      const url = item.url as string | undefined;
      if (url === undefined || url.trim().length === 0) { continue; }
      const name = item.name as string | undefined;
      sources.push({ name: name === undefined ? '' : name, url: url });
    }
    return { groups: [], sources: sources };
  }
  if (type === TYPE_GROUP) {
    const rawGroups = decoded.groups as Object[] | undefined;
    if (rawGroups === undefined) { return { groups: [], sources: [] }; }
    const groups: string[] = [];
    for (const entry of rawGroups) {
      if (typeof entry !== 'string') { continue; }
      const value = entry as string;
      if (value.trim().length > 0) { groups.push(value); }
    }
    return { groups: groups, sources: [] };
  }
  return undefined;
}

/** 上游 `:92-100 parse`：JSON 优先，失败回退 legacy。 */
export function parseScope(raw: string): ParsedSearchScope {
  if (raw.length === 0) { return emptyParsed(); }
  const fromJson = parseJson(raw);
  if (fromJson !== undefined) { return fromJson; }
  return parseLegacy(raw);
}

/** 上游 `:26-28 isAll`：组与源都为空即「全部」。 */
export function scopeIsAll(raw: string): boolean {
  const parsed = parseScope(raw);
  return parsed.groups.length === 0 && parsed.sources.length === 0;
}

/** 上游 `:29-30 isSource`：有源项即为源范围。 */
export function scopeIsSource(raw: string): boolean {
  return parseScope(raw).sources.length > 0;
}

/** 上游 `:32-33 groupNames`。 */
export function scopeGroupNames(raw: string): string[] {
  return parseScope(raw).groups;
}

/** 上游 `:35-36 sourceUrls`。 */
export function scopeSourceUrls(raw: string): string[] {
  const urls: string[] = [];
  for (const source of parseScope(raw).sources) { urls.push(source.url); }
  return urls;
}

/** 上游 `:38-39 sourceNames`。 */
export function scopeSourceNames(raw: string): string[] {
  const names: string[] = [];
  for (const source of parseScope(raw).sources) { names.push(source.name); }
  return names;
}

/** 上游 `:20-24 items`：源范围给 url 列表，否则给组名列表。 */
export function scopeItems(raw: string): string[] {
  return scopeIsSource(raw) ? scopeSourceUrls(raw) : scopeGroupNames(raw);
}

/**
 * 上游 `SearchScope.kt:63-74 display`：
 * 源范围 → 源名 join ","，源名为空 → 「全部书源」；
 * 组范围 → 空 scope → 「全部书源」，否则组名 join ","。
 */
export function scopeDisplay(raw: string, allSourceLabel: string): string {
  if (scopeIsSource(raw)) {
    const names = scopeSourceNames(raw);
    if (names.length === 0) { return allSourceLabel; }
    return names.join(',');
  }
  if (raw.length === 0) { return allSourceLabel; }
  return scopeGroupNames(raw).join(',');
}

/** 上游 `SearchScope.kt:79-88 displayNames`：源范围给源名，否则给组名。 */
export function scopeDisplayNames(raw: string): string[] {
  return scopeIsSource(raw) ? scopeSourceNames(raw) : scopeGroupNames(raw);
}

/**
 * 上游 `SearchScope.kt:93-103 remove(scope)`：
 * 源范围按 name 或 url 匹配移除；组范围按组名移除。返回新的编码串。
 */
export function scopeRemove(raw: string, scope: string): string {
  if (scopeIsSource(raw)) {
    const kept: ScopeSourceItem[] = [];
    for (const item of parseScope(raw).sources) {
      if (item.name === scope || item.url === scope) { continue; }
      kept.push(item);
    }
    return encodeSources(kept);
  }
  const keptGroups: string[] = [];
  for (const name of scopeDisplayNames(raw)) {
    if (name === scope) { continue; }
    keptGroups.push(name);
  }
  return encodeGroups(keptGroups);
}

/** 上游 `SearchScope.kt:158-160 sanitizeSourceName`：源名去掉冒号与逗号。 */
export function sanitizeSourceName(name: string): string {
  return name.replace(/:/g, '').replace(/,/g, '');
}

/** 上游 `SearchScope.kt:162-164 encodeSourceScope(name, url)`。 */
export function encodeSourceScope(name: string, url: string): string {
  return encodeSource(sanitizeSourceName(name), url);
}
