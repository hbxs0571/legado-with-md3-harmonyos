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

  static isOnWifi(): boolean {
    return NetworkProbe.onWifi;
  }

  /** 同步查询一次当前默认网络，返回判断结果。查询失败保持上一次的值。 */
  static refresh(): boolean {
    try {
      const handle = connection.getDefaultNetSync();
      if (handle === undefined || handle.netId === 0) {
        NetworkProbe.onWifi = false;
        return NetworkProbe.onWifi;
      }
      const caps = connection.getNetCapabilitiesSync(handle);
      NetworkProbe.onWifi = NetworkProbe.isWifiBearer(caps);
    } catch (e) {
      // 无网络权限、查询异常时不做判断，沿用旧值。
    }
    return NetworkProbe.onWifi;
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