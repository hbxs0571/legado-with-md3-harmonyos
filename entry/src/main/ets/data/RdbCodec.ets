import { relationalStore } from '@kit.ArkData';

/**
 * 结果集读取辅助。
 *
 * relationalStore 的 ResultSet 只能按列下标取值，列名写错不会在编译期报错，
 * 运行时才抛 14800013（列下标越界）或返回空值。所以每个仓储读同一张表时
 * 都应先 getColumnIndex 一次、把下标存下来复用，而不是每行每列都查一遍名字。
 */
export class RdbCodec {
  /** 读 TEXT 列，NULL 时返回 fallback。 */
  static text(resultSet: relationalStore.ResultSet, index: number, fallback: string = ''): string {
    if (index < 0 || resultSet.isColumnNull(index)) { return fallback; }
    return resultSet.getString(index);
  }

  /** 读可空 TEXT 列，NULL 时返回 undefined。 */
  static optionalText(resultSet: relationalStore.ResultSet, index: number): string | undefined {
    if (index < 0 || resultSet.isColumnNull(index)) { return undefined; }
    return resultSet.getString(index);
  }

  /** 读 INTEGER 列，NULL 时返回 fallback。 */
  static integer(resultSet: relationalStore.ResultSet, index: number, fallback: number = 0): number {
    if (index < 0 || resultSet.isColumnNull(index)) { return fallback; }
    return resultSet.getLong(index);
  }

  /** 读可空 INTEGER 列，NULL 时返回 undefined。 */
  static optionalInteger(resultSet: relationalStore.ResultSet, index: number): number | undefined {
    if (index < 0 || resultSet.isColumnNull(index)) { return undefined; }
    return resultSet.getLong(index);
  }

  /** 读布尔列，库里存 0/1。 */
  static boolean(resultSet: relationalStore.ResultSet, index: number, fallback: boolean = false): boolean {
    if (index < 0 || resultSet.isColumnNull(index)) { return fallback; }
    return resultSet.getLong(index) !== 0;
  }

  /**
   * 读 REAL 列，NULL 时返回 fallback。
   *
   * REAL 列禁止用 getLong：实测 0.1 会静默变成 0、1.25 变成 1，不报错。
   * highlightRules 的九宫格边距、下划线宽度、字距全是 REAL，
   * 用错方法的表现是「规则能存能读，但样式全丢」，极难排查。
   */
  static real(resultSet: relationalStore.ResultSet, index: number, fallback: number = 0): number {
    if (index < 0 || resultSet.isColumnNull(index)) { return fallback; }
    return resultSet.getDouble(index);
  }

  /** 读可空 REAL 列，NULL 时返回 undefined。 */
  static optionalReal(resultSet: relationalStore.ResultSet, index: number): number | undefined {
    if (index < 0 || resultSet.isColumnNull(index)) { return undefined; }
    return resultSet.getDouble(index);
  }

  /**
   * 取列下标；列不存在时返回 -1（不抛错），由调用方的 fallback 兜底。
   * 表结构对齐上游后列名是固定的，出现 -1 说明 SQL 与 schema 不一致，
   * 属于开发期错误，但运行期不该因此崩溃。
   */
  static column(resultSet: relationalStore.ResultSet, name: string): number {
    try {
      return resultSet.getColumnIndex(name);
    } catch (_) {
      return -1;
    }
  }
}
