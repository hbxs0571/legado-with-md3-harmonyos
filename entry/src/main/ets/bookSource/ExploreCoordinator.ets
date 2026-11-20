// 发现协调器（P2 骨架，P7 填实）：exploreUrl 四写法 + 分类 chip + 结果列表。
export class ExploreCoordinator {
  /** P7 实现：解析 exploreUrl、跑发现规则、返回分类与结果。 */
  static async explore(_sourceUrl: string, _page: number): Promise<Object[]> {
    throw new Error('P7 未实现：发现');
  }
}
