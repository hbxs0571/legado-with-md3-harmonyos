import { CoverSettings } from '../data/CoverSettingsRepository';

/**
 * 无封面时的文字封面排版。
 *
 * 对齐上游 legado-with-MD3 的
 * ui/widget/components/image/cover/CoilBookCover.kt:512-700（CoverTextOverlay）：
 * 竖排逐字排、横排整段排，书名与作者各一套坐标规则。
 * 这里只做几何计算，不碰画布，方便单独验证。
 */

/** 封面上一段待绘制的文字。 */
export interface CoverTextGlyph {
  /** 实际要画的字符（竖排时是单个字，横排时是整行）。 */
  text: string;
  /** 绘制基点 x（px，左上角为 0）。 */
  x: number;
  /** 绘制基线 y（px）。 */
  y: number;
  /** 字号（px）。 */
  fontSize: number;
  /** 是否粗体：上游书名 DEFAULT_BOLD，作者普通字重。 */
  bold: boolean;
}

/** 一次绘制的完整排版结果。 */
export interface CoverTextLayout {
  glyphs: CoverTextGlyph[];
  /** 是否横排，供调用方决定是否需要描边路径差异。 */
  horizontal: boolean;
}

/**
 * 判断文字是否以拉丁字母为主。
 *
 * 对应上游 CoilBookCover.kt:505-509：拉丁字母占比超过 30% 即视为拉丁文本，
 * 强制横排（竖排英文会变成一列单字母，可读性极差）。
 */
export function isLatinBasedText(value: string): boolean {
  if (value.length === 0) { return false; }
  let latin = 0;
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    const isUpper = code >= 65 && code <= 90;
    const isLower = code >= 97 && code <= 122;
    if (isUpper || isLower) { latin += 1; }
  }
  return latin / value.length > 0.3;
}

/** 当前是否横排：配置成横排，或书名以拉丁字母为主。 */
export function isCoverTextHorizontal(title: string, settings: CoverSettings): boolean {
  return settings.infoOrientation === '1' || isLatinBasedText(title);
}

/**
 * 计算书名与作者在封面上的位置。
 *
 * @param widthPx 封面宽（px）
 * @param heightPx 封面高（px）
 * @param title 书名
 * @param author 作者
 * @param settings 封面设置（决定是否显示书名/作者、横排还是竖排）
 * @param charHeightRatio 单字行高与字号的比值，由调用方用真实字体量出来后传入
 */
export function buildCoverTextLayout(
  widthPx: number, heightPx: number, title: string, author: string,
  settings: CoverSettings, charHeightRatio: number, isNight: boolean = false
): CoverTextLayout {
  const glyphs: CoverTextGlyph[] = [];
  const horizontal = isCoverTextHorizontal(title, settings);
  if (widthPx <= 0 || heightPx <= 0) {
    return { glyphs: glyphs, horizontal: horizontal };
  }
  // 上游：showAuthor 在 showName 关闭时无效（CoilBookCover.kt:519-520）；
  // 夜间取 *Dark 一组开关，与上游 CoverTextOverlay(name, author, isNight) 一致。
  const showName = isNight ? settings.showNameDark : settings.showName;
  const showAuthor = (isNight ? settings.showAuthorDark : settings.showAuthor) && showName;
  const ratio = charHeightRatio > 0 ? charHeightRatio : 1.2;

  if (showName && title.length > 0) {
    // 上游：书名 textSize = 封面宽 / 8（CoilBookCover.kt:546）
    const fontSize = Math.max(1, widthPx / 8);
    if (horizontal) {
      // 上游：横排书名最多 3 行，起点 y = h*0.08，逐行下移
      const maxWidth = Math.max(1, widthPx * 0.8);
      const lineHeight = fontSize * ratio;
      let line = '';
      let lineIndex = 0;
      for (let index = 0; index < title.length; index++) {
        const candidate = line + title.charAt(index);
        if (line.length > 0 && estimateTextWidth(candidate, fontSize) > maxWidth) {
          glyphs.push({
            text: line, x: widthPx / 2, y: heightPx * 0.08 + fontSize + lineHeight * lineIndex,
            fontSize: fontSize, bold: true
          });
          lineIndex += 1;
          if (lineIndex >= 3) { line = ''; break; }
          line = title.charAt(index);
        } else {
          line = candidate;
        }
      }
      if (line.length > 0 && lineIndex < 3) {
        glyphs.push({
          text: line, x: widthPx / 2, y: heightPx * 0.08 + fontSize + lineHeight * lineIndex,
          fontSize: fontSize, bold: true
        });
      }
    } else {
      // 上游：竖排逐字，起点 startX = w*0.16、startY = h*0.16，
      // startY 超过 h*0.8 时换列 startX += textSize*1.2、startY = h*0.2
      // （CoilBookCover.kt:558-572）。注意 y 直接就是绘制基线，不要再加字号。
      const charHeight = fontSize * ratio;
      let startX = widthPx * 0.16;
      let startY = heightPx * 0.16;
      for (let index = 0; index < title.length; index++) {
        glyphs.push({
          text: title.charAt(index), x: startX, y: startY,
          fontSize: fontSize, bold: true
        });
        startY += charHeight;
        if (startY > heightPx * 0.8) {
          startX += fontSize * 1.2;
          startY = heightPx * 0.2;
        }
      }
    }
  }

  if (showAuthor && author.length > 0) {
    // 上游：作者 textSize = 封面宽 / 12（CoilBookCover.kt:597）
    const fontSize = Math.max(1, widthPx / 12);
    if (horizontal) {
      // 上游：横排作者居中画在 h*0.75 处（CoilBookCover.kt:682）
      glyphs.push({
        text: author, x: widthPx / 2, y: heightPx * 0.75,
        fontSize: fontSize, bold: false
      });
    } else {
      // 上游：竖排作者在 startX = w*0.84 的右列，
      // 起点 startY = max(h*0.16 - 作者字数*charHeight, h*0.2)（CoilBookCover.kt:611-614）
      // 与书名一样，y 就是基线，不再加字号。
      const charHeight = fontSize * ratio;
      const startX = widthPx * 0.84;
      let startY = Math.max(heightPx * 0.16 - author.length * charHeight, heightPx * 0.2);
      for (let index = 0; index < author.length; index++) {
        glyphs.push({
          text: author.charAt(index), x: startX, y: startY,
          fontSize: fontSize, bold: false
        });
        startY += charHeight;
      }
    }
  }

  return { glyphs: glyphs, horizontal: horizontal };
}

/**
 * 粗略估算一段文字的宽度。
 *
 * 只用于横排折行判断，不需要精确：拉丁字符按 0.55 个字号、其余按 1 个字号估。
 * 真正的行宽由画布绘制时的字体决定，折行早一行晚一行都不影响可读性。
 */
function estimateTextWidth(value: string, fontSize: number): number {
  let width = 0;
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    const isLatin = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    width += fontSize * (isLatin ? 0.55 : 1);
  }
  return width;
}
