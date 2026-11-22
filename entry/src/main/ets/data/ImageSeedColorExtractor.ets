import image from '@ohos.multimedia.image';
import { quantizeCelebi } from './quantize/QuantizerCelebi.ets';
import { scoreColors } from './quantize/Score.ets';

/**
 * 封面主色提取。
 *
 * 对齐上游 `ui/theme/ImageSeedColorExtractor.kt`：解码 → 缩到量化尺寸 → 取像素 →
 * `QuantizerCelebi`（Wu + Wsmeans 两步量化）→ `Score` 打分取第一名。
 * 三个常量照搬上游 `ImageSeedColorExtractor.kt:28-31`：
 * 解码边长 128、量化位图最长边 64、量化色数 64、回落色 0xFF4285F4。
 *
 * 上游先由 Coil 缩到 128、再由 `toSafeBitmap(128)`、再由 `extractSeedColor` 缩到 64，
 * 三次都是等比缩放，终点就是「最长边 ≤ 64」。本地直接一步缩到最长边 64：
 * 中间那次重采样不会改变终点尺寸，只会引入额外的插值误差，所以省掉。
 */

/** 上游 `IMAGE_COLOR_EXTRACT_SIZE_PX = 128`：解码阶段的目标边长。 */
const EXTRACT_SIZE_PX: number = 128;

/** 上游 `IMAGE_QUANTIZE_BITMAP_MAX_SIZE = 64`：送进量化器前的最长边上限。 */
const QUANTIZE_MAX_SIZE_PX: number = 64;

/** 上游 `IMAGE_MAX_QUANTIZE_COLORS = 64`。 */
const MAX_QUANTIZE_COLORS: number = 64;

/** 上游 `IMAGE_FALLBACK_SEED_COLOR = 0xFF4285F4`（Google Blue）。 */
const FALLBACK_SEED_ARGB: number = 0xff4285f4;

/** 上游 `Score.score(quantized, 1, fallbackColorArgb, true)` 里只要一个颜色。 */
const DESIRED_COLOR_COUNT: number = 1;

export class ImageSeedColorExtractor {
  /**
   * 从图片 uri 提取主色，返回 `#RRGGBB`。
   *
   * uri 既支持 `file://` 也支持 `datashare://`（本地封面统一是 `file://` 前缀，
   * 见 `data/BookRepository.ets:512-518 resolveCoverUri`）。失败返回空串，调用方据此跳过取色。
   */
  static async extract(uri: string): Promise<string> {
    if (uri.length === 0) {
      return '';
    }
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    try {
      source = image.createImageSource(uri);
      const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) {
        return '';
      }
      const target = ImageSeedColorExtractor.quantizeTargetSize(info.size.width, info.size.height);
      pixelMap = await source.createPixelMap({
        desiredSize: {
          width: target.width,
          height: target.height
        },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      const argb = ImageSeedColorExtractor.readArgbPixels(pixelMap);
      if (argb.length === 0) {
        return ImageSeedColorExtractor.argbToHex(FALLBACK_SEED_ARGB);
      }
      const quantized = quantizeCelebi(argb, MAX_QUANTIZE_COLORS);
      const scored = scoreColors(quantized, DESIRED_COLOR_COUNT, FALLBACK_SEED_ARGB, true);
      const seed = scored.length > 0 ? scored[0] : FALLBACK_SEED_ARGB;
      return ImageSeedColorExtractor.argbToHex(seed);
    } catch (_) {
      return '';
    } finally {
      if (pixelMap !== undefined) {
        try {
          await pixelMap.release();
        } catch (_) {
        }
      }
      if (source !== undefined) {
        try {
          await source.release();
        } catch (_) {
        }
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
    if (uri.length === 0) {
      return 0;
    }
    let source: image.ImageSource | undefined = undefined;
    try {
      source = image.createImageSource(uri);
      const info = await source.getImageInfo();
      if (info.size.width <= 0 || info.size.height <= 0) {
        return 0;
      }
      return info.size.width / info.size.height;
    } catch (_) {
      return 0;
    } finally {
      if (source !== undefined) {
        try {
          await source.release();
        } catch (_) {
        }
      }
    }
  }

  /**
   * 算出量化前的目标尺寸。
   *
   * 上游 `Bitmap.extractSeedColor` 的判据是 `width > 64 || height > 64` 才缩，
   * 缩的时候按 `minOf(64f / width, 64f / height)` 等比，且每边 `coerceAtLeast(1)`。
   * 小图不放大——放大会凭空插值出原图没有的颜色，量化结果随之改变。
   */
  private static quantizeTargetSize(width: number, height: number): Size2D {
    const needsScaling = width > QUANTIZE_MAX_SIZE_PX || height > QUANTIZE_MAX_SIZE_PX;
    if (!needsScaling) {
      return { width: width, height: height };
    }
    const scale = Math.min(QUANTIZE_MAX_SIZE_PX / width, QUANTIZE_MAX_SIZE_PX / height);
    return {
      width: Math.max(1, Math.floor(width * scale)),
      height: Math.max(1, Math.floor(height * scale))
    };
  }

  /**
   * 把 PixelMap 读成 ARGB 整数数组。
   *
   * 上游用 `Bitmap.getPixels` 直接拿 ARGB；本地 `readPixelsToBufferSync` 出来的是 RGBA_8888
   * 的字节序，所以这里逐像素拼回 ARGB。alpha 照原样保留（上游也没有对透明像素做特判）。
   */
  private static readArgbPixels(pixelMap: image.PixelMap): number[] {
    const bufferSize = pixelMap.getPixelBytesNumber();
    if (bufferSize <= 0) {
      return [];
    }
    const buffer = new ArrayBuffer(bufferSize);
    pixelMap.readPixelsToBufferSync(buffer);
    const bytes = new Uint8Array(buffer);
    const pixels: number[] = [];
    for (let index = 0; index + 3 < bytes.length; index += 4) {
      const alpha = bytes[index + 3];
      const red = bytes[index];
      const green = bytes[index + 1];
      const blue = bytes[index + 2];
      pixels.push(((alpha << 24) | (red << 16) | (green << 8) | blue) | 0);
    }
    return pixels;
  }

  /** ARGB 整数 → `#RRGGBB`。 */
  private static argbToHex(argb: number): string {
    const red = (argb >> 16) & 0xff;
    const green = (argb >> 8) & 0xff;
    const blue = argb & 0xff;
    return '#' + ImageSeedColorExtractor.toHex(red)
      + ImageSeedColorExtractor.toHex(green)
      + ImageSeedColorExtractor.toHex(blue);
  }

  private static toHex(channel: number): string {
    const text = channel.toString(16).toUpperCase();
    return text.length < 2 ? `0${text}` : text;
  }
}

/** 内部用的宽高对。 */
interface Size2D {
  width: number;
  height: number;
}
