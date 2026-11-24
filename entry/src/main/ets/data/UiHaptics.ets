import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 书架拖拽的触感反馈。
 *
 * 对齐上游 `BookshelfScreen.kt:1809-1822` 的 `longPressDraggableHandle`：
 * - `onDragStarted` 发 `HapticFeedbackType.GestureThresholdActivate`（拖拽阈值激活，一次明确触感）
 * - `onDragStopped` 发 `HapticFeedbackType.GestureEnd`（松手，一次更轻的收尾触感）
 * - `BookshelfScreen.kt:1731-1736` 每次跨位移动时发 `HapticFeedbackType.SegmentFrequentTick`
 *
 * 鸿蒙没有 Compose 那套 HapticFeedbackType 枚举，`@ohos.vibrator` 的 `HapticFeedback`
 * 只给到 `haptic.effect.soft` / `hard` / `sharp`（@since 12）。按语义映射：
 * 阈值激活用 hard、跨位用 soft、结束用 sharp（最短促，符合「松手」）。
 *
 * 振动失败一律吞掉：模拟器与部分设备没有马达，`startVibration` 会抛 14600101，
 * 不能让它打断拖拽手势（同 `ReaderHaptics` 的处置）。
 */
export class UiHaptics {
  /** 长按拖拽阈值激活（上游 GestureThresholdActivate）。 */
  static dragThresholdActivate(): void {
    UiHaptics.vibrate(vibrator.HapticFeedback.EFFECT_HARD);
  }

  /** 拖拽跨过一格（上游 SegmentFrequentTick）。 */
  static dragTick(): void {
    UiHaptics.vibrate(vibrator.HapticFeedback.EFFECT_SOFT);
  }

  /** 松手结束拖拽（上游 GestureEnd）。 */
  static dragEnd(): void {
    UiHaptics.vibrate(vibrator.HapticFeedback.EFFECT_SHARP);
  }

  private static vibrate(effectId: string): void {
    try {
      vibrator.startVibration(
        { type: 'preset', effectId: effectId, count: 1 },
        { usage: 'touch' }
      ).catch((error: BusinessError) => {
        console.warn(`UiHaptics: 振动失败 ${error.code} ${error.message}`);
      });
    } catch (error) {
      const failure = error as BusinessError;
      console.warn(`UiHaptics: 振动调用异常 ${failure.code} ${failure.message}`);
    }
  }
}
