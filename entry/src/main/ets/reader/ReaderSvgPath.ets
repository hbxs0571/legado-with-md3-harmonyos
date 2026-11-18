import { drawing } from '@kit.ArkGraphics2D';

/**
 * SVG path 解析与缓存，对齐上游 ReaderPageDecorationDrawCache.kt:154-166 的 ReaderSvgPathCache。
 *
 * 支持 M/m L/l H/h V/v C/c S/s Q/q T/t Z/z。
 * A/a（椭圆弧）**不支持**：SDK 的 drawing.Path.arcTo 是「矩形 + 起止角」，SVG 的 A 是
 * 「端点参数化 + 两段半径 + 旋转 + 大弧/顺逆标志」，两者要解椭圆中心，本批不做。
 * 命中 A/a 或参数不合法时整条路径返回 undefined，该条规则不下划线——如实不支持，不画错。
 */

/** 解析期可变游标状态：当前点、子路径起点、上次贝塞尔控制点、上一条命令。 */
class SvgBuildState {
  cx: number = 0;
  cy: number = 0;
  sx: number = 0;
  sy: number = 0;
  ctrlX: number = 0;
  ctrlY: number = 0;
  prevCmd: string = '';
}

export class ReaderSvgPath {
  /** 上限 32，与上游 LruCache<String, Path>(32) 一致（ReaderPageDecorationDrawCache.kt:155）。 */
  private static readonly CACHE_LIMIT: number = 32;
  private static cache: Map<string, drawing.Path> = new Map<string, drawing.Path>();

  static parse(pathData: string): drawing.Path | undefined {
    const trimmed = pathData.trim();
    if (trimmed.length === 0) {
      return undefined;
    }
    const cached = ReaderSvgPath.cache.get(trimmed);
    if (cached !== undefined) {
      return cached;
    }
    const parsed = ReaderSvgPath.build(trimmed);
    if (parsed === undefined) {
      return undefined;
    }
    ReaderSvgPath.cache.set(trimmed, parsed);
    ReaderSvgPath.evict();
    return parsed;
  }

  static clear(): void {
    ReaderSvgPath.cache.clear();
  }

  private static evict(): void {
    while (ReaderSvgPath.cache.size > ReaderSvgPath.CACHE_LIMIT) {
      let firstKey: string = '';
      for (const key of ReaderSvgPath.cache.keys()) {
        firstKey = key;
        break;
      }
      if (firstKey.length === 0) {
        return;
      }
      ReaderSvgPath.cache.delete(firstKey);
    }
  }

  /** 每条命令的参数个数；A/a 不在此表内，遇到即整条路径放弃。 */
  private static arity(upper: string): number {
    if (upper === 'M' || upper === 'L' || upper === 'T') { return 2; }
    if (upper === 'H' || upper === 'V') { return 1; }
    if (upper === 'C') { return 6; }
    if (upper === 'S' || upper === 'Q') { return 4; }
    if (upper === 'Z') { return 0; }
    return -1;
  }

  private static isCommand(tok: string): boolean {
    return /^[a-zA-Z]$/.test(tok);
  }

  private static build(trimmed: string): drawing.Path | undefined {
    const tokens: string[] | null =
      trimmed.match(/[a-zA-Z]|-?\d*\.?\d+(?:[eE][-+]?\d+)?/g);
    if (tokens === null || tokens.length === 0) {
      return undefined;
    }
    const path = new drawing.Path();
    const st = new SvgBuildState();
    let idx = 0;
    while (idx < tokens.length) {
      const tok = tokens[idx];
      if (!ReaderSvgPath.isCommand(tok)) {
        return undefined;
      }
      const cmd: string = tok;
      idx++;
      const upper = cmd.toUpperCase();
      if (upper === 'Z') {
        path.close();
        st.cx = st.sx;
        st.cy = st.sy;
        st.prevCmd = 'z';
        continue;
      }
      // A/a 与其它未知命令：如实放弃整条路径
      const n = ReaderSvgPath.arity(upper);
      if (n <= 0) {
        return undefined;
      }
      let first = true;
      while (idx < tokens.length && !ReaderSvgPath.isCommand(tokens[idx])) {
        const group: number[] = [];
        for (let k = 0; k < n; k++) {
          if (idx >= tokens.length || ReaderSvgPath.isCommand(tokens[idx])) {
            return undefined;
          }
          group.push(Number(tokens[idx]));
          idx++;
        }
        // M/m 后续参数组隐式转成 L/l
        const runCmd = first ? cmd : (cmd === 'm' ? 'l' : (cmd === 'M' ? 'L' : cmd));
        if (!ReaderSvgPath.applyGroup(path, runCmd, group, st)) {
          return undefined;
        }
        first = false;
      }
      if (first) {
        return undefined;
      }
    }
    return path;
  }

  /** 执行一组参数，更新路径与游标；非法（含 A/a）返回 false。 */
  private static applyGroup(path: drawing.Path, cmd: string,
    p: number[], st: SvgBuildState): boolean {
    const upper = cmd.toUpperCase();
    const rel = cmd !== upper;
    const ox = st.cx;
    const oy = st.cy;
    const ax = (v: number): number => rel ? ox + v : v;
    const ay = (v: number): number => rel ? oy + v : v;
    if (upper === 'M') {
      const x = ax(p[0]);
      const y = ay(p[1]);
      path.moveTo(x, y);
      st.cx = x; st.cy = y; st.sx = x; st.sy = y;
      st.prevCmd = 'm';
      return true;
    }
    if (upper === 'L') {
      const x = ax(p[0]);
      const y = ay(p[1]);
      path.lineTo(x, y);
      st.cx = x; st.cy = y;
      st.prevCmd = 'l';
      return true;
    }
    if (upper === 'H') {
      const x = ax(p[0]);
      path.lineTo(x, st.cy);
      st.cx = x;
      st.prevCmd = 'h';
      return true;
    }
    if (upper === 'V') {
      const y = ay(p[0]);
      path.lineTo(st.cx, y);
      st.cy = y;
      st.prevCmd = 'v';
      return true;
    }
    if (upper === 'C') {
      const x1 = ax(p[0]); const y1 = ay(p[1]);
      const x2 = ax(p[2]); const y2 = ay(p[3]);
      const x3 = ax(p[4]); const y3 = ay(p[5]);
      path.cubicTo(x1, y1, x2, y2, x3, y3);
      st.ctrlX = x2; st.ctrlY = y2; st.cx = x3; st.cy = y3;
      st.prevCmd = 'c';
      return true;
    }
    if (upper === 'S') {
      // 第一控制点：上一条是 C/S 时取当前点关于上次第二控制点的反射，否则就是当前点
      const smooth = st.prevCmd === 'c' || st.prevCmd === 's';
      const x1 = smooth ? 2 * st.cx - st.ctrlX : st.cx;
      const y1 = smooth ? 2 * st.cy - st.ctrlY : st.cy;
      const x2 = ax(p[0]); const y2 = ay(p[1]);
      const x3 = ax(p[2]); const y3 = ay(p[3]);
      path.cubicTo(x1, y1, x2, y2, x3, y3);
      st.ctrlX = x2; st.ctrlY = y2; st.cx = x3; st.cy = y3;
      st.prevCmd = 's';
      return true;
    }
    if (upper === 'Q') {
      const x1 = ax(p[0]); const y1 = ay(p[1]);
      const x2 = ax(p[2]); const y2 = ay(p[3]);
      path.quadTo(x1, y1, x2, y2);
      st.ctrlX = x1; st.ctrlY = y1; st.cx = x2; st.cy = y2;
      st.prevCmd = 'q';
      return true;
    }
    if (upper === 'T') {
      // 控制点：上一条是 Q/T 时取反射，否则就是当前点
      const smooth = st.prevCmd === 'q' || st.prevCmd === 't';
      const x1 = smooth ? 2 * st.cx - st.ctrlX : st.cx;
      const y1 = smooth ? 2 * st.cy - st.ctrlY : st.cy;
      const x2 = ax(p[0]); const y2 = ay(p[1]);
      path.quadTo(x1, y1, x2, y2);
      st.ctrlX = x1; st.ctrlY = y1; st.cx = x2; st.cy = y2;
      st.prevCmd = 't';
      return true;
    }
    return false;
  }
}
