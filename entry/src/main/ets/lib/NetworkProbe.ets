// 批3（r359）：网络状态探针。
// 「仅 WiFi 加载封面」要用它（上游 legado-with-MD3/.../help/coil/CoverFetcher.kt:136
// `if (loadOnlyWifi && !appCtx.isWifiConnect) throw IOException(...)`）；
// 批 2 的章节预下载也要同一份判断，所以单独抽出来，别让两边各写一套。
//
// 注意：ArkUI 的 build 是同步的（BookCover.effectiveCoverUri 在渲染里同步取封面 URI），
// 没法在那一行 await 网络查询，所以这里维持一个缓存的布尔值：
// 启动时查一次 + 注册 netCapabilitiesChange 监听后续变化。
import { connection } from '@kit.NetworkKit';

export class NetworkProbe {
  /**
   * 最近一次判断结果。**未知时按「在 WiFi 上」处理**（true）：
   * 探测失败就把所有网络封面吞掉，等于替用户关掉了封面，比多加载一张图更糟。
   */
  private static onWifi: boolean = true;
  private static started: boolean = false;
  private static conn: connection.NetConnection | undefined = undefined;
  /**
   * 当前是否有可用网络。**未知时按「有网」处理**，理由同 `onWifi`：
   * 探测失败就说没网，会把该做的同步静默跳过，比多试一次更糟。
   */
  private static available: boolean = true;
  /** 可用性从「无」变「有」时逐个回调（对应上游 `ReadBookViewModel.onNetworkChanged`）。 */
  private static availabilityListeners: Array<() => void> = [];

  static isOnWifi(): boolean {
    return NetworkProbe.onWifi;
  }

  static isAvailable(): boolean {
    return NetworkProbe.available;
  }

  /**
   * 注册「网络恢复可用」回调。只在这一刻触发，不做防抖 ——
   * 调用方自己判断要不要做事（上游 `onNetworkChanged` 里也是靠 `syncBookProgressPlus` 等条件过滤）。
   */
  static onAvailable(listener: () => void): void {
    if (!NetworkProbe.availabilityListeners.includes(listener)) {
      NetworkProbe.availabilityListeners.push(listener);
    }
  }

  /** 同步查询一次当前默认网络，返回判断结果。查询失败保持上一次的值。 */
  static refresh(): boolean {
    try {
      const handle = connection.getDefaultNetSync();
      if (handle === undefined || handle.netId === 0) {
        NetworkProbe.onWifi = false;
        NetworkProbe.setAvailable(false);
        return NetworkProbe.onWifi;
      }
      const caps = connection.getNetCapabilitiesSync(handle);
      NetworkProbe.onWifi = NetworkProbe.isWifiBearer(caps);
      NetworkProbe.setAvailable(true);
    } catch (e) {
      // 无网络权限、查询异常时不做判断，沿用旧值。
    }
    return NetworkProbe.onWifi;
  }

  /** 只有「无 → 有」这一跳才通知，避免网络类型在 WiFi/蜂窝之间切换时重复触发。 */
  private static setAvailable(next: boolean): void {
    if (NetworkProbe.available === next) { return; }
    NetworkProbe.available = next;
    if (!next) { return; }
    for (const listener of NetworkProbe.availabilityListeners) {
      try {
        listener();
      } catch (e) {
        // 单个回调出错不能连累其它订阅者。
      }
    }
  }

  /** 注册一次监听并同步初值。重复调用无副作用。 */
  static async ensureStarted(): Promise<void> {
    if (NetworkProbe.started) { return; }
    NetworkProbe.started = true;
    NetworkProbe.refresh();
    try {
      const conn = connection.createNetConnection();
      conn.on('netCapabilitiesChange', () => {
        NetworkProbe.refresh();
      });
      // register 是 NetConnection 实例上的方法（@ohos.net.connection.d.ts:1586），
      // 不是 connection 命名空间的静态方法。
      conn.register((error: Error) => {
        if (error !== undefined && error !== null) {
          NetworkProbe.started = false;
        }
      });
      NetworkProbe.conn = conn;
    } catch (e) {
      // 监听注册失败就退化成「只在启动时判断一次」，不影响封面本身能显示。
    }
  }

  /** 上游 isWifiConnect 只认 WiFi 承载（以太网/蜂窝都不算）。 */
  private static isWifiBearer(caps: connection.NetCapabilities): boolean {
    const bearers = caps.bearerTypes;
    if (bearers === undefined || bearers === null) { return false; }
    return bearers.includes(connection.NetBearType.BEARER_WIFI);
  }
}