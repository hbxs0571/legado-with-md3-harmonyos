/**
 * 阅读记录总览页。
 *
 * 布局顺序照上游 ReadRecordOverviewScreen.kt:99-192：
 * 周期选择器 → 日期导航 → 柱状图 → 统计格 → 跨书热力图 → 时长榜 → 读书日历。
 * 计算口径全部在 data/ReadRecordOverview.ets，这里只负责把结构画出来。
 */

import { Book } from '../model/Book';
import { ReadRecordDetail, ReadRecordSummary } from '../model/ReadRecord';
import { BookCover } from '../components/BookCover';
import { ReadRecordHeatmap } from '../components/ReadRecordHeatmap';
import {
  ReadPeriod,
  ReadRecordOverviewState,
  DailyTimePoint,
  ReadBookRanking,
  OverviewBookProgress,
  hourMinuteLabel,
  roundedMaxTime,
  computeReadRecordOverview
} from '../data/ReadRecordOverview';

/** 周期选择器的一个档位。 */
interface PeriodTab {
  index: ReadPeriod;
  label: string;
}

/** 统计格的一格。 */
interface StatItem {
  label: string;
  value: string;
}

/** 月历的一个格子：空串表示该位置不是当月有效日。 */
interface CalendarCell {
  dateKey: string;
  dayNumber: string;
}

/** 柱状图卡片：柱高按 time / roundedMax，五档取整由数据层算好。 */
@Component
struct ReadTimeBarChartCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop data: DailyTimePoint[] = [];
  @Prop period: number = ReadPeriod.DAY;

  private chartHeight(): number {
    return 150;
  }

  private maxTime(): number {
    return roundedMaxTime(this.data);
  }

  /** 柱高：0 值也留最小可见高度，对应上游 coerceAtLeast(0.01f)。 */
  private barHeight(time: number): number {
    const ratio = time / this.maxTime();
    return Math.max(2, Math.round(this.chartHeight() * ratio));
  }

  private barWidth(): string {
    return this.period === ReadPeriod.MONTH ? '80%' : '60%';
  }

  private dayPart(date: string): number {
    return Number(date.split('-')[2] ?? '0');
  }

  private monthPart(date: string): number {
    return Number(date.split('-')[1] ?? '0');
  }

  private showLabel(date: string, index: number): boolean {
    if (this.period === ReadPeriod.MONTH) {
      return this.dayPart(date) === 1 || this.dayPart(date) === 15 || index === this.data.length - 1;
    }
    return true;
  }

  private labelText(date: string, index: number): string {
    if (this.period === ReadPeriod.YEAR) { return `${this.monthPart(date)}月`; }
    if (this.period === ReadPeriod.WEEK) {
      const names = ['日', '一', '二', '三', '四', '五', '六'];
      return names[index % 7];
    }
    return `${this.dayPart(date)}`;
  }

  build() {
    Column() {
      Text('阅读时长').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.themeColorTextPrimary)
        .width('100%').margin({ bottom: 10 })
      Row() {
        // Y 轴：只标顶端取整值与 0。
        Column() {
          Text(hourMinuteLabel(this.maxTime())).fontSize(10).fontColor(this.themeColorTextTertiary)
          Blank()
          Text('0').fontSize(10).fontColor(this.themeColorTextTertiary)
        }.height(this.chartHeight()).width(46).justifyContent(FlexAlign.SpaceBetween)
          .alignItems(HorizontalAlign.End).padding({ right: 4 })
        Row() {
          ForEach(this.data, (point: DailyTimePoint, index: number) => {
            Column() {
              Stack({ alignContent: Alignment.Bottom }) {
                Column()
                  .width(this.barWidth())
                  .height(this.barHeight(point.time))
                  .borderRadius({ topLeft: 4, topRight: 4 })
                  .backgroundColor(point.time > 0 ? this.themeColorAccent : this.themeColorSurfaceTertiary)
              }.width('100%').height(this.chartHeight())
              if (this.showLabel(point.date, index)) {
                Text(this.labelText(point.date, index)).fontSize(9)
                  .fontColor(this.themeColorTextTertiary).margin({ top: 4 })
              } else {
                Text(' ').fontSize(9).margin({ top: 4 })
              }
            }.layoutWeight(1)
          }, (point: DailyTimePoint, index: number) => `${point.date}_${index}_${point.time}`)
        }.layoutWeight(1).height(this.chartHeight() + 18).alignItems(VerticalAlign.Top)
      }.width('100%')
    }.width('100%').padding(14).backgroundColor(this.themeColorSurfaceElevated).borderRadius(16)
  }
}

/** 统计格：两列一行，五格，最后一格右侧空出。 */
@Component
struct StatsGridCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop totalTime: number = 0;
  @Prop readingDays: number = 0;
  @Prop totalBooks: number = 0;
  @Prop finishedBooks: number = 0;
  @Prop readingBooks: number = 0;

  private statItems(): StatItem[] {
    return [
      { label: '阅读时间', value: hourMinuteLabel(this.totalTime) },
      { label: '阅读天数', value: `${this.readingDays}天` },
      { label: '累计读过', value: `${this.totalBooks}本` },
      { label: '读完书籍', value: `${this.finishedBooks}本` },
      { label: '在读书籍', value: `${this.readingBooks}本` }
    ];
  }

  @Builder
  StatCell(item: StatItem) {
    Column() {
      Text(item.label).fontSize(11).fontColor(this.themeColorTextTertiary)
      Text(item.value).fontSize(17).fontWeight(FontWeight.Bold)
        .fontColor(this.themeColorAccent).margin({ top: 3 })
    }.alignItems(HorizontalAlign.Start).width('100%').padding({ left: 6, top: 8, bottom: 8 })
  }

  build() {
    Column() {
      Text('阅读数据').fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).width('100%').margin({ bottom: 8 })
      Grid() {
        ForEach(this.statItems(), (item: StatItem) => {
          GridItem() {
            this.StatCell(item)
          }
        }, (item: StatItem) => item.label)
      }.columnsTemplate('1fr 1fr').rowsGap(2).columnsGap(2).width('100%')
    }.width('100%').padding(14).backgroundColor(this.themeColorSurfaceElevated).borderRadius(16)
  }
}

/** 阅读时长榜：最多 10 条，前三名序号用主色，整行可点跳书。 */
@Component
struct TopReadingListCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop topBooks: ReadBookRanking[] = [];
  @Prop books: Book[] = [];
  onOpenBook: (bookName: string, bookAuthor: string) => void = () => {};

  private coverUriOf(bookName: string, bookAuthor: string): string {
    const hit = this.books.find((book: Book) => book.title === bookName && book.author === bookAuthor);
    return hit?.coverUri ?? '';
  }

  build() {
    Column() {
      Text('阅读时长榜').fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).width('100%').margin({ bottom: 8 })
      ForEach(this.topBooks, (item: ReadBookRanking, index: number) => {
        Row() {
          Text(`${index + 1}`).fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(index < 3 ? this.themeColorAccent : this.themeColorTextTertiary).width(24)
          BookCover({
            book: {
              id: `${item.bookName}-${item.bookAuthor}`, title: item.bookName,
              author: item.bookAuthor, category: '', lastChapter: '', progress: 0,
              coverUri: this.coverUriOf(item.bookName, item.bookAuthor).length > 0
                ? this.coverUriOf(item.bookName, item.bookAuthor) : undefined,
              isLocal: true
            },
            displayWidth: 40, displayHeight: 56, cornerRadius: 4
          })
          Column() {
            Text(hourMinuteLabel(item.readTime)).fontSize(11).fontColor(this.themeColorAccent)
            Text(item.bookName).fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor(this.themeColorTextPrimary).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 2 })
            Text(item.bookAuthor).fontSize(11).fontColor(this.themeColorTextTertiary)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1).padding({ left: 10 })
        }.width('100%').padding({ top: 6, bottom: 6 })
          .onClick(() => this.onOpenBook(item.bookName, item.bookAuthor))
      }, (item: ReadBookRanking, index: number) => `${index}_${item.bookName}_${item.bookAuthor}`)
    }.width('100%').padding(14).backgroundColor(this.themeColorSurfaceElevated).borderRadius(16)
  }
}

/** 读书日历：当月按周铺格，有当日最多阅读的书时铺封面，不可点。 */
@Component
struct ReadingCalendarCard {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @Prop referenceDate: string = '';
  /** 每天读得最多的书，键 yyyy-MM-dd、值「书名\u0000作者」。 */
  @Prop dailyTopBook: Map<string, string> = new Map<string, string>();
  @Prop books: Book[] = [];

  private refDate(): Date {
    const parts = this.referenceDate.split('-');
    const year = Number(parts[0]);
    const month = Number(parts[1]) - 1;
    const day = Number(parts[2]);
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
      return new Date();
    }
    return new Date(year, month, day);
  }

  private dateKey(date: Date): string {
    const year = date.getFullYear().toString();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /** 当月 1 日是周几（0 = 周日），与上游 atDay(1).dayOfWeek.value % 7 一致。 */
  private firstDayOfWeek(): number {
    const date = this.refDate();
    return new Date(date.getFullYear(), date.getMonth(), 1).getDay();
  }

  private daysInMonth(): number {
    const date = this.refDate();
    return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  }

  private calendarCells(): CalendarCell[] {
    const cells: CalendarCell[] = [];
    const offset = this.firstDayOfWeek();
    const days = this.daysInMonth();
    const total = Math.ceil((days + offset) / 7) * 7;
    const date = this.refDate();
    for (let i = 0; i < total; i += 1) {
      const dayNumber = i - offset + 1;
      if (dayNumber < 1 || dayNumber > days) {
        cells.push({ dateKey: '', dayNumber: '' });
      } else {
        const key = this.dateKey(new Date(date.getFullYear(), date.getMonth(), dayNumber));
        cells.push({ dateKey: key, dayNumber: `${dayNumber}` });
      }
    }
    return cells;
  }

  private coverUriOf(dateKey: string): string {
    const bookKey = this.dailyTopBook.get(dateKey);
    if (bookKey === undefined) { return ''; }
    const parts = bookKey.split('\u0000');
    const hit = this.books.find((book: Book) => book.title === parts[0] && book.author === parts[1]);
    return hit?.coverUri ?? '';
  }

  build() {
    Column() {
      Text('读书日历').fontSize(16).fontWeight(FontWeight.Medium)
        .fontColor(this.themeColorTextPrimary).width('100%').margin({ bottom: 8 })
      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (label: string) => {
          Text(label).fontSize(11).fontColor(this.themeColorTextTertiary).layoutWeight(1)
            .textAlign(TextAlign.Center)
        }, (label: string) => label)
      }.width('100%').margin({ bottom: 4 })
      Grid() {
        ForEach(this.calendarCells(), (cell: CalendarCell, index: number) => {
          GridItem() {
            Stack({ alignContent: Alignment.TopStart }) {
              Column().width('100%').height('100%')
                .backgroundColor(cell.dateKey.length > 0 && this.coverUriOf(cell.dateKey).length > 0
                  ? this.themeColorAccent : this.themeColorSurfaceTertiary)
                .borderRadius(6)
              if (cell.dateKey.length > 0 && this.coverUriOf(cell.dateKey).length > 0) {
                Image(this.coverUriOf(cell.dateKey)).width('100%').height('100%')
                  .objectFit(ImageFit.Cover).opacity(0.4).borderRadius(6)
              }
              if (cell.dayNumber.length > 0) {
                Text(cell.dayNumber).fontSize(11)
                  .fontWeight(cell.dateKey.length > 0 && this.coverUriOf(cell.dateKey).length > 0
                    ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(cell.dateKey.length > 0 && this.coverUriOf(cell.dateKey).length > 0
                    ? this.themeColorAccent : this.themeColorTextPrimary)
                  .margin({ left: 4, top: 3 })
              }
            }.aspectRatio(0.75).width('100%').padding(2)
          }
        }, (cell: CalendarCell, index: number) => `${index}_${cell.dateKey}`)
      }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(2).columnsGap(2).width('100%')
    }.width('100%').padding(14).backgroundColor(this.themeColorSurfaceElevated).borderRadius(16)
  }
}

/** 总览页本体。 */
@Component
export struct ReadRecordOverviewPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#6A6D77';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop details: ReadRecordDetail[] = [];
  @Prop summaries: ReadRecordSummary[] = [];
  @Prop books: Book[] = [];
  onBack: () => void = () => {};
  onOpenBook: (bookName: string, bookAuthor: string) => void = () => {};
  @State period: ReadPeriod = ReadPeriod.DAY;
  @State referenceDate: string = '';

  private tabs: PeriodTab[] = [
    { index: ReadPeriod.DAY, label: '日' },
    { index: ReadPeriod.WEEK, label: '周' },
    { index: ReadPeriod.MONTH, label: '月' },
    { index: ReadPeriod.YEAR, label: '年' },
    { index: ReadPeriod.ALL, label: '总' }
  ];

  aboutToAppear(): void {
    this.referenceDate = this.todayKey();
  }

  private todayKey(): string {
    const now = new Date();
    return `${now.getFullYear().toString()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;
  }

  private refDate(): Date {
    const parts = this.referenceDate.split('-');
    const year = Number(parts[0]);
    const month = Number(parts[1]) - 1;
    const day = Number(parts[2]);
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
      return new Date();
    }
    return new Date(year, month, day);
  }

  private toKey(date: Date): string {
    return `${date.getFullYear().toString()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  private bookProgress(): OverviewBookProgress[] {
    const result: OverviewBookProgress[] = [];
    for (const book of this.books) {
      const chapterCount = Number(book.chapterCount ?? '0');
      result.push({
        bookName: book.title,
        bookAuthor: book.author,
        totalChapterNum: chapterCount,
        durChapterIndex: book.chapterIndex ?? 0,
        durChapterPos: book.chapterProgress ?? 0
      });
    }
    return result;
  }

  /** 每次 build 重算：入参即数据、不查库，对应上游 invoke。 */
  private overview(): ReadRecordOverviewState {
    return computeReadRecordOverview(this.period, this.refDate(), this.details,
      this.summaries, this.bookProgress());
  }

  private setPeriod(index: ReadPeriod): void {
    this.period = index;
  }

  /** 上一档/下一档：按档位加减 1 天 / 1 周 / 1 月 / 1 年。 */
  private shiftDate(delta: number): void {
    const date = this.refDate();
    if (this.period === ReadPeriod.DAY) { date.setDate(date.getDate() + delta); }
    else if (this.period === ReadPeriod.WEEK) { date.setDate(date.getDate() + delta * 7); }
    else if (this.period === ReadPeriod.MONTH) { date.setDate(1); date.setMonth(date.getMonth() + delta); }
    else if (this.period === ReadPeriod.YEAR) { date.setFullYear(date.getFullYear() + delta); }
    this.referenceDate = this.toKey(date);
  }

  private dateLabel(): string {
    const date = this.refDate();
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    if (this.period === ReadPeriod.DAY) { return `${year}年${month}月${day}日`; }
    if (this.period === ReadPeriod.WEEK) {
      const weekday = date.getDay();
      const mondayOffset = weekday === 0 ? -6 : 1 - weekday;
      const start = new Date(date.getTime());
      start.setDate(start.getDate() + mondayOffset);
      const end = new Date(start.getTime());
      end.setDate(end.getDate() + 6);
      return `${start.getMonth() + 1}.${start.getDate()} - ${end.getMonth() + 1}.${end.getDate()}`;
    }
    if (this.period === ReadPeriod.MONTH) { return `${year}年${month}月`; }
    return `${year}年`;
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题。
      Row() {
        Text('返回').fontSize(14).fontColor(this.themeColorAccent)
          .onClick(() => this.onBack())
        Text('阅读总览').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(this.themeColorTextPrimary).layoutWeight(1).textAlign(TextAlign.Center)
        Text(' ').fontSize(14).width(28)
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 10 })

      // 周期选择器：日/周/月/年/总。
      Row() {
        ForEach(this.tabs, (tab: PeriodTab) => {
          Text(tab.label).fontSize(14)
            .fontWeight(this.period === tab.index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.period === tab.index ? this.themeColorAccent : this.themeColorTextTertiary)
            .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 8, bottom: 8 })
            .backgroundColor(this.period === tab.index ? this.themeColorSurfaceElevated : Color.Transparent)
            .borderRadius(10)
            .onClick(() => this.setPeriod(tab.index))
        }, (tab: PeriodTab) => tab.label)
      }.width('100%').padding({ left: 12, right: 12 })

      // 日期导航：ALL 档整块不渲染。
      if (this.period !== ReadPeriod.ALL) {
        Row() {
          Text('‹').fontSize(20).fontColor(this.themeColorAccent).width(40)
            .textAlign(TextAlign.Center).onClick(() => this.shiftDate(-1))
          Text(this.dateLabel()).fontSize(14).fontColor(this.themeColorTextPrimary)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Text('›').fontSize(20).fontColor(this.themeColorAccent).width(40)
            .textAlign(TextAlign.Center).onClick(() => this.shiftDate(1))
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }

      Scroll() {
        Column() {
          // 柱状图：ALL 档整卡不渲染。
          if (this.period !== ReadPeriod.ALL && this.overview().dailyTimeData.length > 0) {
            ReadTimeBarChartCard({ data: this.overview().dailyTimeData, period: this.period })
              .margin({ bottom: 12 })
          }
          StatsGridCard({
            totalTime: this.overview().totalTime,
            readingDays: this.overview().readingDays,
            totalBooks: this.overview().totalBooks,
            finishedBooks: this.overview().finishedBooks,
            readingBooks: this.overview().readingBooks
          }).margin({ bottom: 12 })
          // 跨书热力图：时长模式、不可点，数据用全部明细聚合值。
          Column() {
            Text('阅读热力图').fontSize(16).fontWeight(FontWeight.Medium)
              .fontColor(this.themeColorTextPrimary).width('100%').margin({ bottom: 10 })
            ReadRecordHeatmap({
              dailyReadCounts: this.overview().allReadCounts,
              dailyReadTimes: this.overview().allReadTimes,
              selectedDate: '',
              mode: 1,
              onDateSelected: (_date: string) => {}
            })
          }.width('100%').padding(14).backgroundColor(this.themeColorSurfaceElevated)
            .borderRadius(16).margin({ bottom: 12 })
          if (this.overview().topBooks.length > 0) {
            TopReadingListCard({
              topBooks: this.overview().topBooks,
              books: this.books,
              onOpenBook: (name: string, author: string) => this.onOpenBook(name, author)
            }).margin({ bottom: 12 })
          }
          ReadingCalendarCard({
            referenceDate: this.referenceDate.length > 0 ? this.referenceDate : this.todayKey(),
            dailyTopBook: this.overview().dailyTopBook,
            books: this.books
          }).margin({ bottom: 16 })
        }.width('100%').padding({ left: 12, right: 12, top: 8 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%')
      .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent
        : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}
