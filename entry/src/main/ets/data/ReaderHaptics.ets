import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 阅读页触感反馈。
 *
 * 对齐上游两处消费点：
 * - `ReaderCanvasSurface.kt:1109` 长按选中首个词时 `performHapticFeedback(HapticFeedbackType.LongPress)`
 * - `ReaderCanvasSurface.kt:1225` 拖动选区手柄改变选区时 `performHapticFeedback(HapticFeedbackType.TextHandleMove)`
 *
 * 两处都受 `selectionHapticsEnabled`（即 `ReadSettings.kt:41 selectVibrator`）控制，
 * 由 `ReadBookRouteScreen.kt:755` 传入。
 *
 * 上游 `sliderVibrator`（`ReadSettings.kt:36`）在 UI 侧没有任何消费点——全仓 grep 只命中
 * 存储层与设置项，`feature/reader` 一处都没有。按「上游没有就不要这个效果」，本地也不
 * 凭空给进度条加振动，只保留开关与落库。
 */
export class ReaderHaptics {
  /** 长按选中首个词，对应上游 HapticFeedbackType.LongPress。 */
  static selectionStart(enabled: boolean): void {
    if (!enabled) { return; }
    ReaderHaptics.vibrate(40);
  }

  /** 拖动选区手柄，对应上游 HapticFeedbackType.TextHandleMove，比长按更轻。 */
  static selectionMove(enabled: boolean): void {
    if (!enabled) { return; }
    ReaderHaptics.vibrate(15);
  }

  /**
   * 振动失败一律吞掉：模拟器与部分设备没有马达，`startVibration` 会抛 14600101，
   * 不能让它打断阅读页手势。
   */
  private static vibrate(duration: number): void {
    try {
      vibrator.startVibration(
        { type: 'time', duration: duration },
        { usage: 'touch' }
      ).catch((error: BusinessError) => {
        console.warn(`ReaderHaptics: 振动失败 ${error.code} ${error.message}`);
      });
    } catch (error) {
      const failure = error as BusinessError;
      console.warn(`ReaderHaptics: 振动调用异常 ${failure.code} ${failure.message}`);
    }
  }
}
