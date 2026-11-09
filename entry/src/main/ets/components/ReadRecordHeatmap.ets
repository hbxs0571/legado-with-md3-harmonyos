/**
 * 阅读记录热力图：年度按周网格，对应上游 HeatmapCalendarSection +
 * ui/widget/components/heatmap/HeatmapCalendarComponents.kt。
 *
 * 上游是 Jetpack Compose 的 LazyRow；ArkUI 没有 LazyRow 组件，这里用横向
 * Scroll + Row 承载周列，启动时滚到最后一列，效果一致。
 */
@Component
export struct ReadRecordHeatmap {
  /** 每日阅读次数，键为 yyyy-MM-dd。 */
  @Prop dailyReadCounts: Map<string, number> = new Map<string, number>();
  /** 每日阅读时长（毫秒），键为 yyyy-MM-dd。 */
  @Prop dailyReadTimes: Map<string, number> = new Map<string, number>();
  /** 当前选中日期，空串表示未选中。 */
  @Prop selectedDate: string = '';
  /** 0 = 次数，1 = 时长；对应上游 HeatmapMode.COUNT / TIME。 */
  @Prop mode: number = 1;
  onDateSelected: (date: string) => void = (_date: string) => {};

  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';

  private heatmapScroller: Scroller = new Scroller();

  /** 单元格 16vp、间距 4vp、圆角 4vp，对应上游 HeatmapConfig 默认值。 */
  private readonly cellSize: number = 16;
  private readonly cellSpacing: number = 4;
  private readonly cellRadius: number = 4;

  private toDateKey(date: Date): string {
    const year = date.getFullYear().toString();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private parseDateKey(key: string): Date {
    const parts = key.split('-');
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }

  private addDays(date: Date, amount: number): Date {
    const next = new Date(date.getTime());
    next.setDate(next.getDate() + amount);
    return next;
  }

  private addMonths(date: Date, amount: number): Date {
    const next = new Date(date.getTime());
    next.setMonth(next.getMonth() + amount);
    return next;
  }

  /** 有数据的最早/最晚日期；起始再往前推一个月，与上游 rememberDateRange 一致。 */
  private dateBounds(): string[] {
    const keys: string[] = [];
    const collect = (source: Map<string, number>): void => {
      for (const key of Array.from(source.keys())) {
        if ((source.get(key) ?? 0) > 0 && !keys.includes(key)) { keys.push(key); }
      }
    };
    collect(this.dailyReadCounts);
    collect(this.dailyReadTimes);
    keys.sort();
    if (keys.length === 0) {
      const today = this.toDateKey(new Date());
      return [today, today];
    }
    const first = this.addMonths(this.parseDateKey(keys[0]), -1);
    return [this.toDateKey(first), keys[keys.length - 1]];
  }

  /** 周一起算，首周补空位，按 7 天切列；与上游 rememberWeeks 一致。 */
  private buildWeeks(): string[][] {
    const bounds = this.dateBounds();
    const start = this.parseDateKey(bounds[0]);
    const end = this.parseDateKey(bounds[1]);
    const days: string[] = [];
    let cursor = start;
    while (cursor.getTime() <= end.getTime()) {
      days.push(this.toDateKey(cursor));
      cursor = this.addDays(cursor, 1);
    }
    const offset = (start.getDay() + 6) % 7;
    const padded: string[] = [];
    for (let i = 0; i < offset; i++) { padded.push(''); }
    for (const day of days) { padded.push(day); }
    const weeks: string[][] = [];
    for (let i = 0; i < padded.length; i += 7) { weeks.push(padded.slice(i, i + 7)); }
    return weeks;
  }

  private maxValue(): number {
    const values = this.mode === 1 ? this.dailyReadTimes : this.dailyReadCounts;
    let max = 0;
    for (const value of Array.from(values.values())) {
      if (value > max) { max = value; }
    }
    return max < 1 ? 1 : max;
  }

  /** 五档刻度，fraction 与上游 HeatmapScale.levelOf 同阈值。 */
  private levelOf(day: string): number {
    if (day.length === 0) { return 0; }
    const value = this.mode === 1 ? (this.dailyReadTimes.get(day) ?? 0) : (this.dailyReadCounts.get(day) ?? 0);
    const fraction = value / this.maxValue();
    if (fraction <= 0) { return 0; }
    if (fraction < 0.25) { return 1; }
    if (fraction < 0.5) { return 2; }
    if (fraction < 0.75) { return 3; }
    return 4;
  }

  /** 0 级用 onSurface 8% 透明度，1..4 用主题主色按 0.35/0.55/0.75/1 叠加。 */
  private levelColor(level: number): string {
    if (level <= 0) { return '#141B1C22'; }
    const alphas: string[] = ['', '59', '8C', 'BF', 'FF'];
    const accent = this.themeColorAccent.length > 7
      ? this.themeColorAccent.substring(this.themeColorAccent.length - 6)
      : this.themeColorAccent.substring(1);
    return `#${alphas[level]}${accent}`;
  }

  /** 某周若跨过月初，顶部叠月份标签。 */
  private monthLabel(week: string[]): string {
    for (const day of week) {
      if (day.length > 0 && this.parseDateKey(day).getDate() === 1) {
        return `${this.parseDateKey(day).getMonth() + 1}月`;
      }
    }
    return '';
  }

  /** 左侧周标签：只显示一/三/五/日，隔行留白。 */
  @Builder
  private WeekdayLabels() {
    Column() {
      ForEach(['一', '', '三', '', '五', '', '日'], (label: string, index: number) => {
        Text(label).fontSize(10).fontColor(this.themeColorTextTertiary)
          .height(this.cellSize).margin({ bottom: this.cellSpacing })
      }, (_label: string, index: number) => index.toString())
    }.padding({ top: 24, right: 8 })
  }

  /** 单个热力格子；空格子占位不响应点击，选中格加 2vp 描边。 */
  @Builder
  private HeatmapCell(day: string) {
    if (day.length === 0) {
      Row().width(this.cellSize).height(this.cellSize).margin({ bottom: this.cellSpacing })
    } else {
      Row()
        .width(this.cellSize).height(this.cellSize)
        .backgroundColor(this.levelColor(this.levelOf(day)))
        .borderRadius(this.cellRadius)
        .border({ width: this.selectedDate === day ? 2 : 0, color: this.themeColorAccent })
        .margin({ bottom: this.cellSpacing })
        .id(`heatmap_cell_${day}`)
        .onClick(() => this.onDateSelected(day))
    }
  }

  /** 一周一列，列顶叠月份标签。 */
  @Builder
  private WeekColumn(week: string[]) {
    Column() {
      Text(this.monthLabel(week)).fontSize(10).fontColor(this.themeColorTextTertiary)
        .height(24).width(this.cellSize)
      Column() {
        ForEach(week, (day: string) => {
          this.HeatmapCell(day)
        }, (day: string, index: number) => `${index}_${day}`)
      }
    }.width(this.cellSize).margin({ right: this.cellSpacing })
  }

  /** 图例：少 + 五档色块 + 多，单位按次数/时长切换。 */
  @Builder
  private HeatmapLegend() {
    Row() {
      Text(`少${this.mode === 1 ? '(时长)' : '(次)'}`).fontSize(11).fontColor(this.themeColorTextTertiary)
      ForEach([0, 1, 2, 3, 4], (level: number) => {
        Row().width(12).height(12).backgroundColor(this.levelColor(level)).borderRadius(2)
          .margin({ left: 4 })
      }, (level: number) => level.toString())
      Text(`多${this.mode === 1 ? '(时长)' : '(次)'}`).fontSize(11)
        .fontColor(this.themeColorTextTertiary).margin({ left: 4 })
    }.width('100%').justifyContent(FlexAlign.End).margin({ top: 16 })
  }

  build() {
    Column() {
      Row() {
        this.WeekdayLabels()
        Scroll(this.heatmapScroller) {
          Row() {
            ForEach(this.buildWeeks(), (week: string[], weekIndex: number) => {
              this.WeekColumn(week)
            }, (week: string[], weekIndex: number) => `${weekIndex}_${week.join('')}`)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .id('read_record_heatmap_grid')
        .onAppear(() => { this.heatmapScroller.scrollEdge(Edge.End); })
      }.width('100%')
      this.HeatmapLegend()
    }.width('100%').padding({ left: 16, right: 16 })
  }
}
