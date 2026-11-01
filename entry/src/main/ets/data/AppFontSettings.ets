/**
 * 应用字体（`font_setting`）的取值域与注册名。
 *
 * 上游 `ui/config/themeConfig/ThemeConfigScreen.kt:263` 是 `ClickableSettingItem(font_setting)` →
 * `FontSelectSheet`；选中后 `ThemeConfigViewModel.kt:582` 把复制到私有目录的字体路径写进
 * `ThemeSettings.appFontPath`，启动时 `base/AppContextWrapper.kt` 用它换全局字体。
 *
 * ArkUI 没有「换 resources 字体」这一层，等价做法是
 * `UIContext.getFont().registerFont({ familyName, familySrc })` 注册后再
 * `ApplicationContext.setFont(familyName)`。
 */

/** 允许选择的字体文件扩展名，对齐上游 `ThemeConfigViewModel.kt:555` 的 `substringAfterLast('.', "ttf")`。 */
export const APP_FONT_EXTENSIONS: string[] = ['.ttf', '.otf', '.ttc'];

/** 注册到系统时使用的族名；固定值，避免依赖字体文件内部的 family 名。 */
export const APP_FONT_FAMILY: string = 'LegadoAppFont';

/** 未选择字体时返回空串，表示使用系统默认字体。 */
export function normalizeAppFontPath(value: string): string {
  if (typeof value !== 'string') { return ''; }
  const trimmed = value.trim();
  if (trimmed.length === 0) { return ''; }
  const lower = trimmed.toLowerCase();
  for (let index = 0; index < APP_FONT_EXTENSIONS.length; index++) {
    if (lower.endsWith(APP_FONT_EXTENSIONS[index])) { return trimmed; }
  }
  return '';
}

/** 从路径取文件名，用于设置页的「当前字体」摘要。 */
export function appFontDisplayName(path: string): string {
  if (path.length === 0) { return ''; }
  const separator = Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
  return separator >= 0 ? path.substring(separator + 1) : path;
}
