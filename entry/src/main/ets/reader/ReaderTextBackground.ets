import { common2D } from '@kit.ArkGraphics2D';

/** 判断源路径是否为九宫格图：去掉 query/fragment 后看是否以 `.9.png` 结尾。 */
export function isNinePatchSource(source: string): boolean {
  const query = source.indexOf('?');
  const fragment = source.indexOf('#');
  let end = source.length;
  if (query >= 0 && query < end) {
    end = query;
  }
  if (fragment >= 0 && fragment < end) {
    end = fragment;
  }
  return source.substring(0, end).toLowerCase().endsWith('.9.png');
}

/**
 * 文字背景图（气泡图）的几何模型，照抄上游
 * `feature/reader/core/model/ReaderPage.kt` 的 `ReaderTextBackgroundImage` 与
 * `ReaderTextBackgroundRun`、以及 `ReaderNineSliceLayout.kt` 的 `cells`。
 *
 * 单位口径：进入绘制时坐标已经是物理像素（px），本文件不做 vp 换算。
 */

/** 九宫格的一片：源图矩形 + 目标矩形 + 补缝外扩后的绘制矩形。 */
export class ReaderNineSliceCell {
  sourceLeft: number = 0;
  sourceTop: number = 0;
  sourceRight: number = 0;
  sourceBottom: number = 0;
  destLeft: number = 0;
  destTop: number = 0;
  destRight: number = 0;
  destBottom: number = 0;
  /** 补缝外扩半像素后的绘制矩形，绘制时必须裁剪到目标矩形避免重叠合成。 */
  paintLeft: number = 0;
  paintTop: number = 0;
  paintRight: number = 0;
  paintBottom: number = 0;
}

/** 背景图的几何描述：source/fit/scale 来自规则，四个 contentInset 与 bandHeight 在拿到位图尺寸后回填。 */
export class ReaderTextBackgroundImage {
  source: string = '';
  /** 0 平铺 / 1 等比内缩居中裁剪 / 2 等比填充居中 / 3 九宫格。 */
  fit: number = 0;
  /** 图片大小 0.1~5。 */
  scale: number = 1;
  ninePatchLeft: number = 0.1;
  ninePatchRight: number = 0.1;
  ninePatchTop: number = 0.1;
  ninePatchBottom: number = 0.1;
  lengthOffsetLeftPx: number = 0;
  lengthOffsetRightPx: number = 0;
  contentInsetLeftPx: number = 0;
  contentInsetRightPx: number = 0;
  contentInsetTopPx: number = 0;
  contentInsetBottomPx: number = 0;
  contentBandHeightPx: number = 0;
  hasNinePatchBorder: boolean = false;

  get hasNinePatch(): boolean {
    return this.hasNinePatchBorder || isNinePatchSource(this.source);
  }

  sizeFactor(): number {
    return Math.min(5, Math.max(0.1, this.scale));
  }

  /** 中间带（上下两条切线之间的显示区）至少留整图高的 25%。 */
  private minContentBandPx(contentHeightPx: number): number {
    return Math.min(contentHeightPx, Math.max(0, Math.round(contentHeightPx * 0.25)));
  }

  /**
   * 把四条切线换算成整像素源切片厚度并写回 contentInset 与 contentBandHeight。
   * 只对 fit==3 生效；这是「整张图等比、绝不形变」的前提——切线两处读同一份。
   */
  withBitmapSize(widthPx: number, heightPx: number): ReaderTextBackgroundImage {
    const copy = new ReaderTextBackgroundImage();
    copy.source = this.source;
    copy.fit = this.fit;
    copy.scale = this.scale;
    copy.ninePatchLeft = this.ninePatchLeft;
    copy.ninePatchRight = this.ninePatchRight;
    copy.ninePatchTop = this.ninePatchTop;
    copy.ninePatchBottom = this.ninePatchBottom;
    copy.lengthOffsetLeftPx = this.lengthOffsetLeftPx;
    copy.lengthOffsetRightPx = this.lengthOffsetRightPx;
    copy.hasNinePatchBorder = this.hasNinePatch;
    if (this.fit !== 3 || widthPx <= 0 || heightPx <= 0) {
      return copy;
    }
    const borderPx = copy.hasNinePatchBorder ? 1 : 0;
    const contentWidthPx = Math.max(0, widthPx - borderPx * 2);
    const contentHeightPx = Math.max(0, heightPx - borderPx * 2);
    let leftPx = Math.round(contentWidthPx * Math.min(1, Math.max(0, this.ninePatchLeft)));
    let rightPx = Math.round(contentWidthPx * Math.min(1, Math.max(0, this.ninePatchRight)));
    let topPx = Math.round(contentHeightPx * Math.min(1, Math.max(0, this.ninePatchTop)));
    let bottomPx = Math.round(contentHeightPx * Math.min(1, Math.max(0, this.ninePatchBottom)));
    const maxEdgePx = contentHeightPx - this.minContentBandPx(contentHeightPx);
    const edgeSum = topPx + bottomPx;
    if (edgeSum > maxEdgePx && edgeSum > 0) {
      topPx = Math.round(topPx * maxEdgePx / edgeSum);
      bottomPx = maxEdgePx - topPx;
    }
    const maxColumnPx = Math.max(0, contentWidthPx - 1);
    const columnSum = leftPx + rightPx;
    if (columnSum > maxColumnPx && columnSum > 0) {
      leftPx = Math.round(leftPx * maxColumnPx / columnSum);
      rightPx = maxColumnPx - leftPx;
    }
    copy.ninePatchLeft = contentWidthPx > 0 ? leftPx / contentWidthPx : 0;
    copy.ninePatchRight = contentWidthPx > 0 ? rightPx / contentWidthPx : 0;
    copy.ninePatchTop = contentHeightPx > 0 ? topPx / contentHeightPx : 0;
    copy.ninePatchBottom = contentHeightPx > 0 ? bottomPx / contentHeightPx : 0;
    copy.contentInsetLeftPx = leftPx;
    copy.contentInsetRightPx = rightPx;
    copy.contentInsetTopPx = topPx;
    copy.contentInsetBottomPx = bottomPx;
    copy.contentBandHeightPx = Math.max(0, contentHeightPx - topPx - bottomPx);
    return copy;
  }

  /** 整张图的等比缩放倍率：中间带 = 行盒高 × 图片大小。 */
  verticalScalePx(lineHeightPx: number): number {
    if (this.fit !== 3 || this.contentBandHeightPx <= 0 || lineHeightPx <= 0) {
      return 1;
    }
    return lineHeightPx * this.sizeFactor() / this.contentBandHeightPx;
  }

  /** 图片大小 ≠ 1 时中间带比行盒多/少的量，上下各分一半。 */
  bandOverhangPx(lineHeightPx: number): number {
    if (this.fit !== 3) {
      return 0;
    }
    return lineHeightPx * (this.sizeFactor() - 1) / 2;
  }

  frameTopPx(lineHeightPx: number): number {
    return this.fit !== 3 ? 0 : this.bandOverhangPx(lineHeightPx) + this.contentInsetTopPx * this.verticalScalePx(lineHeightPx);
  }

  frameBottomPx(lineHeightPx: number): number {
    return this.fit !== 3 ? 0 : this.bandOverhangPx(lineHeightPx) + this.contentInsetBottomPx * this.verticalScalePx(lineHeightPx);
  }

  frameLeftPx(lineHeightPx: number): number {
    return this.fit !== 3 ? 0 : this.contentInsetLeftPx * this.verticalScalePx(lineHeightPx);
  }

  frameRightPx(lineHeightPx: number): number {
    return this.fit !== 3 ? 0 : this.contentInsetRightPx * this.verticalScalePx(lineHeightPx);
  }

  stretchLeftPx(textWidthPx: number): number {
    return Math.max(-textWidthPx / 2, this.lengthOffsetLeftPx);
  }

  stretchRightPx(textWidthPx: number): number {
    return Math.max(-textWidthPx / 2, this.lengthOffsetRightPx);
  }
}

/** 一条合并后的背景图 run：外框（bounds）+ 文字区（contentBounds）+ 图片描述。 */
export class ReaderTextBackgroundRun {
  image: ReaderTextBackgroundImage = new ReaderTextBackgroundImage();
  frameLeft: number = 0;
  frameTop: number = 0;
  frameRight: number = 0;
  frameBottom: number = 0;
  contentLeft: number = 0;
  contentTop: number = 0;
  contentRight: number = 0;
  contentBottom: number = 0;

  contentWidth(): number {
    return this.contentRight - this.contentLeft;
  }

  contentHeight(): number {
    return this.contentBottom - this.contentTop;
  }
}

/**
 * 九宫格切分：把一张图切成 9 格（含退化），逐格返回源矩形 + 目标矩形。
 * 照抄上游 `ReaderNineSliceLayout.cells`：任何一格都不单独拉伸，整张图只等比变大小。
 */
export class ReaderNineSliceLayout {
  static readonly SEAM_OVERLAP_PX: number = 0.5;

  static cells(bitmapWidth: number, bitmapHeight: number,
    contentLeft: number, contentTop: number, contentRight: number, contentBottom: number,
    frameLeft: number, frameTop: number, frameRight: number, frameBottom: number,
    image: ReaderTextBackgroundImage): ReaderNineSliceCell[] {
    if (bitmapWidth <= 0 || bitmapHeight <= 0) {
      return [];
    }
    const borderPx = image.hasNinePatchBorder ? 1 : 0;
    const sourceLeft = borderPx;
    const sourceTop = borderPx;
    const sourceRight = Math.max(sourceLeft, bitmapWidth - borderPx);
    const sourceBottom = Math.max(sourceTop, bitmapHeight - borderPx);
    const sourceWidth = sourceRight - sourceLeft;
    const sourceHeight = sourceBottom - sourceTop;
    const sx: number[] = [
      sourceLeft,
      sourceLeft + Math.round(sourceWidth * Math.min(1, Math.max(0, image.ninePatchLeft))),
      sourceRight - Math.round(sourceWidth * Math.min(1, Math.max(0, image.ninePatchRight))),
      sourceRight,
    ];
    const sy: number[] = [
      sourceTop,
      sourceTop + Math.round(sourceHeight * Math.min(1, Math.max(0, image.ninePatchTop))),
      sourceBottom - Math.round(sourceHeight * Math.min(1, Math.max(0, image.ninePatchBottom))),
      sourceBottom,
    ];
    // 交叉时给中间格留至少一像素可拉，图案不会被切断
    sx[2] = Math.max(sx[2], Math.min(sx[1] + 1, sourceRight));
    sy[2] = Math.max(sy[2], Math.min(sy[1] + 1, sourceBottom));
    const textWidthPx = contentRight - contentLeft;
    const overhangPx = image.bandOverhangPx(contentBottom - contentTop);
    const dx: number[] = [
      frameLeft,
      contentLeft - image.stretchLeftPx(textWidthPx),
      contentRight + image.stretchRightPx(textWidthPx),
      frameRight,
    ];
    const dy: number[] = [
      frameTop,
      contentTop - overhangPx,
      contentBottom + overhangPx,
      frameBottom,
    ];
    if (dx[1] > dx[2]) {
      dx[2] = dx[1];
    }
    if (dy[1] > dy[2]) {
      dy[2] = dy[1];
    }
    const cells: ReaderNineSliceCell[] = [];
    for (let row = 0; row < 3; row++) {
      for (let column = 0; column < 3; column++) {
        if (sx[column] === sx[column + 1] || sy[row] === sy[row + 1]) {
          continue;
        }
        const destWidth = dx[column + 1] - dx[column];
        const destHeight = dy[row + 1] - dy[row];
        if (destWidth <= 0 || destHeight <= 0) {
          continue;
        }
        const cell = new ReaderNineSliceCell();
        cell.sourceLeft = sx[column];
        cell.sourceTop = sy[row];
        cell.sourceRight = sx[column + 1];
        cell.sourceBottom = sy[row + 1];
        cell.destLeft = dx[column];
        cell.destTop = dy[row];
        cell.destRight = dx[column + 1];
        cell.destBottom = dy[row + 1];
        cell.paintLeft = dx[column] > dx[0] ? dx[column] - ReaderNineSliceLayout.SEAM_OVERLAP_PX : dx[column];
        cell.paintTop = dy[row] > dy[0] ? dy[row] - ReaderNineSliceLayout.SEAM_OVERLAP_PX : dy[row];
        cell.paintRight = dx[column + 1] < dx[3] ? dx[column + 1] + ReaderNineSliceLayout.SEAM_OVERLAP_PX : dx[column + 1];
        cell.paintBottom = dy[row + 1] < dy[3] ? dy[row + 1] + ReaderNineSliceLayout.SEAM_OVERLAP_PX : dy[row + 1];
        cells.push(cell);
      }
    }
    return cells;
  }
}
