import { fileIo } from '@kit.CoreFileKit';
import { ThemeModeResolver } from './ThemeModeResolver';
import { resolvePaletteColors } from './ThemePalette';
import { CustomThemeSnapshot } from './CustomThemeColors';

/**
 * 主题配色清单，对应上游 `help/config/ThemeConfigStore.kt`。
 *
 * 上游把「一套配色」存成 `Config`（8 个字段），整个清单是一个 JSON 数组，落在
 * `filesDir/themeConfig.json`；备份时整份写进归档（`Backup.kt:241-246`），恢复时整份覆盖
 * 回来并 `upConfig()` 重新装载（`Restore.kt:327-336`）。本地此前只在归档清单里列了文件名，
 * 既没有写出也没有读回，所以这个类别一直是「零行」。
 */

/** 归档与私有目录里的文件名，对齐上游 `ThemeConfigStore.configFileName`。 */
export const THEME_CONFIG_FILE_NAME: string = 'themeConfig.json';

/** 一套配色，字段名与顺序对齐上游 `ThemeConfigStore.Config`（含 `toMap()` 的键名）。 */
export interface ThemeConfigEntry {
  themeName: string;
  isNightTheme: boolean;
  primaryColor: string;
  accentColor: string;
  backgroundColor: string;
  bottomBackground: string;
  backgroundImgPath?: string;
  backgroundImgBlur?: number;
}

/**
 * 内置四套默认配色，逐条对齐上游 `app/src/main/assets/defaultData/themeConfig.json`。
 *
 * 这是「文件不存在时」的兜底，与上游 `configList = getConfigs() ?: DefaultData.themeConfigs` 同义。
 */
export function defaultThemeConfigs(): ThemeConfigEntry[] {
  return [
    {
      themeName: '默认', isNightTheme: false,
      primaryColor: '#795548', accentColor: '#E53935',
      backgroundColor: '#F5F5F5', bottomBackground: '#EEEEEE'
    },
    {
      themeName: '典雅蓝', isNightTheme: false,
      primaryColor: '#03A9F4', accentColor: '#AD1457',
      backgroundColor: '#F5F5F5', bottomBackground: '#EEEEEE'
    },
    {
      themeName: '黑白', isNightTheme: true,
      primaryColor: '#303030', accentColor: '#E0E0E0',
      backgroundColor: '#424242', bottomBackground: '#424242'
    },
    {
      themeName: 'A屏黑', isNightTheme: true,
      primaryColor: '#000000', accentColor: '#FFFFFF',
      backgroundColor: '#000000', bottomBackground: '#000000'
    }
  ];
}

/** 颜色串归一；非法值回落空串（上游 `validateConfig` 要求可 `toColorInt()`）。 */
function normalizeColor(value: string): string {
  if (typeof value !== 'string') { return ''; }
  const trimmed = value.trim().toUpperCase();
  if (!/^#([0-9A-F]{6}|[0-9A-F]{8})$/.test(trimmed)) { return ''; }
  return trimmed;
}

/** 校验一套配色：四个颜色必须可解析，否则整条丢弃（对齐上游 `validateConfig`）。 */
export function validateThemeConfig(entry: ThemeConfigEntry): boolean {
  return normalizeColor(entry.primaryColor).length > 0
    && normalizeColor(entry.accentColor).length > 0
    && normalizeColor(entry.backgroundColor).length > 0
    && normalizeColor(entry.bottomBackground).length > 0;
}

/** 从任意 JSON 文本解析清单；坏数据整条跳过，全坏时回落内置四套。 */
export function parseThemeConfigs(raw: string): ThemeConfigEntry[] {
  if (raw.length === 0) { return defaultThemeConfigs(); }
  let list: Object[];
  try {
    const parsed = JSON.parse(raw) as Object[];
    if (!Array.isArray(parsed)) { return defaultThemeConfigs(); }
    list = parsed;
  } catch (_) {
    return defaultThemeConfigs();
  }
  const result: ThemeConfigEntry[] = [];
  for (let index = 0; index < list.length; index++) {
    const item = list[index];
    if (item === null || typeof item !== 'object') { continue; }
    const record = item as Record<string, Object>;
    const readString = (key: string): string => {
      const value = record[key];
      return typeof value === 'string' ? value : '';
    };
    const entry: ThemeConfigEntry = {
      themeName: readString('themeName'),
      isNightTheme: record['isNightTheme'] === true,
      primaryColor: readString('primaryColor'),
      accentColor: readString('accentColor'),
      backgroundColor: readString('backgroundColor'),
      bottomBackground: readString('bottomBackground')
    };
    const imagePath = readString('backgroundImgPath');
    if (imagePath.length > 0) { entry.backgroundImgPath = imagePath; }
    const blur = record['backgroundImgBlur'];
    if (typeof blur === 'number' && Number.isFinite(blur)) { entry.backgroundImgBlur = blur; }
    if (entry.themeName.length === 0 || !validateThemeConfig(entry)) { continue; }
    result.push(entry);
  }
  return result.length > 0 ? result : defaultThemeConfigs();
}

/** 清单 → JSON 文本（紧凑数组，字段顺序对齐上游 `Config` 的声明顺序）。 */
export function themeConfigsToJson(list: ThemeConfigEntry[]): string {
  const normalized: ThemeConfigEntry[] = list.map((entry: ThemeConfigEntry) => {
    const item: ThemeConfigEntry = {
      themeName: entry.themeName,
      isNightTheme: entry.isNightTheme,
      primaryColor: normalizeColor(entry.primaryColor),
      accentColor: normalizeColor(entry.accentColor),
      backgroundColor: normalizeColor(entry.backgroundColor),
      bottomBackground: normalizeColor(entry.bottomBackground)
    };
    if (entry.backgroundImgPath !== undefined && entry.backgroundImgPath.length > 0) {
      item.backgroundImgPath = entry.backgroundImgPath;
    }
    if (entry.backgroundImgBlur !== undefined) { item.backgroundImgBlur = entry.backgroundImgBlur; }
    return item;
  });
  return JSON.stringify(normalized);
}

/** 私有目录里的清单文件路径（`filesDir/themeConfig.json`），对齐上游 `configFilePath`。 */
export function themeConfigFilePath(context: Context): string {
  return `${context.filesDir}/${THEME_CONFIG_FILE_NAME}`;
}

/** 读私有目录里的清单；文件不存在时返回内置四套。 */
export function loadThemeConfigs(context: Context): ThemeConfigEntry[] {
  const path = themeConfigFilePath(context);
  if (!fileIo.accessSync(path)) { return defaultThemeConfigs(); }
  try {
    return parseThemeConfigs(fileIo.readTextSync(path));
  } catch (_) {
    return defaultThemeConfigs();
  }
}

/** 整份写回私有目录，对齐上游 `save()` 的 `writeTextAtomic`。 */
export function saveThemeConfigs(context: Context, list: ThemeConfigEntry[]): void {
  const path = themeConfigFilePath(context);
  const file = fileIo.openSync(path,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  try {
    fileIo.writeSync(file.fd, themeConfigsToJson(list));
  } finally {
    fileIo.closeSync(file);
  }
}

/**
 * 追加或同名替换，对齐上游 `addConfig(newConfig)`。
 *
 * 上游按 `themeName` 判重（同名替换、不同名追加），本地照抄这条语义，
 * 这样「再次保存同名配色」不会在清单里堆出重复项。
 */
export function addThemeConfig(context: Context, entry: ThemeConfigEntry): void {
  if (!validateThemeConfig(entry) || entry.themeName.length === 0) { return; }
  const list = loadThemeConfigs(context);
  const index = list.findIndex((item: ThemeConfigEntry) => item.themeName === entry.themeName);
  if (index >= 0) {
    list[index] = entry;
  } else {
    list.push(entry);
  }
  saveThemeConfigs(context, list);
}

/**
 * 按当前主题状态生成日/夜两套配色，对齐上游 `getDurConfig(context)`。
 *
 * 上游取的是 `cPrimary`/`cAccent`/`cBackground`/`cBBackground` 这四个独立键；
 * 本地这些键由调色板（`resolvePaletteColors`）算出来，所以这里用同一套解析结果，
 * 保证「备份里的配色 = 界面上看到的配色」。自定义配色优先，其次调色板。
 */
export function buildCurrentThemeConfigs(
  paletteIndex: number, customTheme: CustomThemeSnapshot
): ThemeConfigEntry[] {
  const day = resolvePaletteColors(paletteIndex, false);
  const night = resolvePaletteColors(paletteIndex, true);
  const dayCustom = customTheme.day;
  const nightCustom = customTheme.night;
  const pick = (custom: string, fallback: string): string =>
    normalizeColor(custom).length > 0 ? normalizeColor(custom) : fallback;
  const dayEntry: ThemeConfigEntry = {
    themeName: 'MD3-Day',
    isNightTheme: false,
    primaryColor: pick(dayCustom.primary, day.primary),
    accentColor: pick(dayCustom.secondary, day.primary),
    backgroundColor: pick(dayCustom.background, day.surface),
    bottomBackground: pick(dayCustom.labelContainer, day.surfaceContainerLow)
  };
  const nightEntry: ThemeConfigEntry = {
    themeName: 'MD3-Night',
    isNightTheme: true,
    primaryColor: pick(nightCustom.primary, night.primary),
    accentColor: pick(nightCustom.secondary, night.primary),
    backgroundColor: pick(nightCustom.background, night.surface),
    bottomBackground: pick(nightCustom.labelContainer, night.surfaceContainerLow)
  };
  return [dayEntry, nightEntry];
}

/**
 * 恢复后重新装载，对齐上游 `upConfig()`。
 *
 * 上游是「读文件 → 逐条 addConfig 覆盖内存清单」；本地没有内存清单（每次按需读文件），
 * 所以等价动作就是「校验文件可解析并落一次盘」，把非法条目剔除掉。
 */
export function upThemeConfig(context: Context): ThemeConfigEntry[] {
  const list = loadThemeConfigs(context);
  saveThemeConfigs(context, list);
  return list;
}

/** 当前日夜下应当生效的那一套，对齐上游 `getDurConfig(context)` 的选取语义。 */
export function currentThemeConfig(context: Context, isDark: boolean): ThemeConfigEntry | undefined {
  const list = loadThemeConfigs(context);
  const wanted = isDark ? 'MD3-Night' : 'MD3-Day';
  const exact = list.find((item: ThemeConfigEntry) => item.themeName === wanted);
  if (exact !== undefined) { return exact; }
  return list.find((item: ThemeConfigEntry) => item.isNightTheme === isDark);
}

/** 供 `ThemeModeResolver` 的日夜判定复用，避免调用方各自算一遍。 */
export function isDarkNow(context: Context, themeMode: string): boolean {
  return ThemeModeResolver.isDarkTheme(themeMode, ThemeModeResolver.isSystemDark(context));
}
