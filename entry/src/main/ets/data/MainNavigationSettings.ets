/**
 * 首页与导航设置的口径层。
 *
 * 对齐上游：
 * - `ui/main/MainDestination.kt` 的五项与 route 字符串（home/bookshelf/explore/rss/my）
 * - `MainDestination.ordered(order)` 的排序规则：先按给定顺序取已知项并去重，再补齐缺失项
 * - `domain/model/settings/AppShellSettings.kt:6-8` 的 showHome / showDiscovery / showRss
 * - `AppShellSettings.kt:17-19` 的 defaultHomePage / mainNavigationOrder / labelVisibilityMode
 */

/** 五个主导航项的 route，顺序与上游 `MainDestination.mainDestinations` 一致。 */
export const MAIN_NAVIGATION_ROUTES: string[] = ['home', 'bookshelf', 'explore', 'rss', 'my'];

/** 中文标签，对齐上游 `R.string.home/bookshelf/discovery/rss/my`。 */
export function mainNavigationLabel(route: string): string {
  if (route === 'home') { return '首页'; }
  if (route === 'bookshelf') { return '书架'; }
  if (route === 'explore') { return '发现'; }
  if (route === 'rss') { return '订阅'; }
  if (route === 'my') { return '我的'; }
  return route;
}

/** 默认顺序，对齐上游 `mainNavigationOrder` 的默认值。 */
export const MAIN_NAVIGATION_ORDER_DEFAULT: string = 'home,bookshelf,explore,rss,my';

/** 默认主页面，对齐上游 `defaultHomePage` 的默认值。 */
export const DEFAULT_HOME_PAGE_DEFAULT: string = 'bookshelf';

/** 导航标签模式的可选值，对齐上游 `R.array.label_vis_mode_value`。 */
export const LABEL_VISIBILITY_VALUES: string[] = ['auto', 'selected', 'labeled', 'unlabeled'];

export const LABEL_VISIBILITY_DEFAULT: string = 'auto';

export function labelVisibilityLabel(value: string): string {
  if (value === 'selected') { return '仅选中项显示'; }
  if (value === 'labeled') { return '全部显示'; }
  if (value === 'unlabeled') { return '全部隐藏'; }
  return '自动';
}

export function normalizeLabelVisibility(value: string): string {
  return LABEL_VISIBILITY_VALUES.includes(value) ? value : LABEL_VISIBILITY_DEFAULT;
}

/**
 * 按 order 排序并补齐缺失项，逐条对齐上游 `MainDestination.ordered(order)`：
 * `order.split(',').map(trim).distinct().mapNotNull(byRoute::get)` 后再接上未出现的项。
 */
export function orderedMainNavigation(order: string): string[] {
  const seen: string[] = [];
  const parts: string[] = order.split(',');
  for (let index = 0; index < parts.length; index++) {
    const route = parts[index].trim();
    if (route.length === 0) { continue; }
    if (!MAIN_NAVIGATION_ROUTES.includes(route)) { continue; }
    if (seen.includes(route)) { continue; }
    seen.push(route);
  }
  const result: string[] = seen.slice();
  for (let index = 0; index < MAIN_NAVIGATION_ROUTES.length; index++) {
    const route = MAIN_NAVIGATION_ROUTES[index];
    if (!result.includes(route)) { result.push(route); }
  }
  return result;
}

export function joinMainNavigation(routes: string[]): string {
  return routes.join(',');
}

/** 上移一位，返回新数组（首项上移无变化）。 */
export function moveNavigationUp(routes: string[], route: string): string[] {
  const index = routes.indexOf(route);
  if (index <= 0) { return routes.slice(); }
  const next = routes.slice();
  const item = next[index];
  next[index] = next[index - 1];
  next[index - 1] = item;
  return next;
}

/** 下移一位，返回新数组（末项下移无变化）。 */
export function moveNavigationDown(routes: string[], route: string): string[] {
  const index = routes.indexOf(route);
  if (index < 0 || index >= routes.length - 1) { return routes.slice(); }
  const next = routes.slice();
  const item = next[index];
  next[index] = next[index + 1];
  next[index + 1] = item;
  return next;
}

/**
 * 默认主页面必须是可见项；不可见时回落书架，
 * 对齐上游 `MainNavigationSettingsSheet.kt:81-84`。
 */
export function normalizeDefaultHomePage(value: string, visibleRoutes: string[]): string {
  if (visibleRoutes.includes(value)) { return value; }
  return 'bookshelf';
}

/** 逐项显隐：对齐上游 `showHome` / `showDiscovery` / `showRss`，书架与我的恒可见。 */
export function isMainDestinationVisible(route: string, showHome: boolean,
  showDiscovery: boolean, showRss: boolean): boolean {
  if (route === 'home') { return showHome; }
  if (route === 'explore') { return showDiscovery; }
  if (route === 'rss') { return showRss; }
  return true;
}

/** 按可见性过滤已排序的 route 列表。 */
export function visibleMainNavigation(order: string, showHome: boolean,
  showDiscovery: boolean, showRss: boolean): string[] {
  const ordered = orderedMainNavigation(order);
  const result: string[] = [];
  for (let index = 0; index < ordered.length; index++) {
    const route = ordered[index];
    if (isMainDestinationVisible(route, showHome, showDiscovery, showRss)) {
      result.push(route);
    }
  }
  return result;
}
