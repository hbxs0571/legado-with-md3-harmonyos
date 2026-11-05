import image from '@ohos.multimedia.image';

/**
 * 封面主色提取。
 *
 * 上游 `ui/theme/ImageSeedColorExtractor.kt` 用 Coil 解码 + `QuantizerCelebi` 量化 + `Score` 打分
 * 取一个种子色；ArkUI 没有这两套算法，本地改为「缩到 16×16 后取像素均值并提升饱和度」，
 * 目标一致——得到一个能代表封面的主色，用于书籍详情页的取色叠层。
 *
 * 与上游一致的三个常量：解码尺寸上限 64、量化色数上限 64、提取失败回落色 `#4285F4`
 * （`ImageSeedColorExtractor.kt:32-35`）。
 */

/** 解码目标边长，对齐上游 `IMAGE_COLOR_EXTRACT_SIZE_PX = 128` 的取样意图（本地取更小以省内存）。 */
const EXTRACT_SIZE_PX: number = 16;

/** 提取失败时的回落色，对齐上游 `IMAGE_FALLBACK_SEED_COLOR = 0xFF4285F4`。 */
const FALLBACK_SEED_COLOR: string = '#4285F4';

export class ImageSeedColorExtractor {
  /**
   * 从图片 uri 提取主色。
   *
   * uri 既支持 `file://` 也支持 `datashare://`（本地封面统一是 `file://` 前缀，
   * 见 `data/BookRepository.ets:512-518 resolveCoverUri`）。失败返回空串，调用方据此跳过取色。
   */
  static async extract(uri: string): Promise<string> {
    if (uri.length === 0) { return ''; }
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = image.createImageSource(uri);
      const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) { return ''; }
      pixelMap = await source.createPixelMap({
        desiredSize: {
          width: EXTRACT_SIZE_PX,
          height: EXTRACT_SIZE_PX
        }
      });
      return ImageSeedColorExtractor.averageColor(pixelMap);
    } catch (_) {
      return '';
    } finally {
      if (pixelMap !== undefined) {
        try { await pixelMap.release(); } catch (_) {}
      }
      if (source !== undefined) {
        try { await source.release(); } catch (_) {}
      }
    }
  }

  /**
   * 读取封面原图的宽高比（width / height）。
   *
   * A8「限制封面比例」关闭时，搜索/详情页按真实比例推导封面高度
   * （上游 CoverSettings.kt:6-10）；读不到或尺寸无效时返回 0，调用方回落到固定 5:7。
   */
  static async coverAspectRatio(uri: string): Promise<number> {
    if (uri.length === 0) { return 0; }
    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(uri);
      const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) { return 0; }
      return info.size.width / info.size.height;
    } catch (_) {
      return 0;
    } finally {
      if (source !== undefined) {
        try { await source.release(); } catch (_) {}
      }
    }
  }

  /** 取缩略图所有像素的均值，再按上游口径提饱和度，避免灰扑扑的封面给出无彩主色。 */
  private static averageColor(pixelMap: image.PixelMap): string {
    const info: image.ImageInfo = pixelMap.getImageInfoSync();
    const bufferSize = pixelMap.getPixelBytesNumber();
    if (bufferSize <= 0 || info.size.width <= 0 || info.size.height <= 0) { return FALLBACK_SEED_COLOR; }
    const buffer = new ArrayBuffer(bufferSize);
    pixelMap.readPixelsToBufferSync(buffer);
    const bytes = new Uint8Array(buffer);
    // 本地封面解码统一按 RGBA_8888 输出，每像素 4 字节。
    let redSum = 0;
    let greenSum = 0;
    let blueSum = 0;
    let count = 0;
    for (let index = 0; index + 3 < bytes.length; index += 4) {
      const alpha = bytes[index + 3];
      if (alpha < 32) { continue; }
      redSum += bytes[index];
      greenSum += bytes[index + 1];
      blueSum += bytes[index + 2];
      count += 1;
    }
    if (count === 0) { return FALLBACK_SEED_COLOR; }
    return ImageSeedColorExtractor.saturate(
      Math.round(redSum / count),
      Math.round(greenSum / count),
      Math.round(blueSum / count)
    );
  }

  /**
   * 提饱和度。
   *
   * 均值法天然偏灰，直接拿去做取色层会和页面底色糊在一起；这里把每个通道相对灰度的偏离放大
   * 1.6 倍（与上游 `Score` 打分后仍保留封面主色观感的取向一致），再夹回 0..255。
   */
  private static saturate(red: number, green: number, blue: number): string {
    const gray = red * 0.2126 + green * 0.7152 + blue * 0.0722;
    const boost = 1.6;
    return '#' + ImageSeedColorExtractor.toHex(ImageSeedColorExtractor.clampChannel(gray + (red - gray) * boost))
      + ImageSeedColorExtractor.toHex(ImageSeedColorExtractor.clampChannel(gray + (green - gray) * boost))
      + ImageSeedColorExtractor.toHex(ImageSeedColorExtractor.clampChannel(gray + (blue - gray) * boost));
  }

  private static clampChannel(value: number): number {
    const rounded = Math.round(value);
    if (rounded < 0) { return 0; }
    if (rounded > 255) { return 255; }
    return rounded;
  }

  private static toHex(channel: number): string {
    const text = channel.toString(16).toUpperCase();
    return text.length < 2 ? `0${text}` : text;
  }
}
