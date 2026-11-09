/**
 * 阅读记录总览的计算层。
 *
 * 口径照抄上游 GetReadRecordOverviewUseCase.kt（176 行）：入参即数据、不查 DAO，
 * 周期范围、阅读时间、天数、书本数、排行、柱状图数据、热力图数据都在这里算。
 * 页面组件只负责把算好的结构画出来。
 */

import { ReadRecordDetail, ReadRecordSummary } from '../model/ReadRecord';

/** 周期五档，与上游 ReadPeriod 同名同序。 */
export enum ReadPeriod {
  DAY = 0,
  WEEK = 1,
  MONTH = 2,
  YEAR = 3,
  ALL = 4
}

/** 柱状图的一根柱子：日期键 + 时长（毫秒）。 */
export interface DailyTimePoint {
  /** yyyy-MM-dd（DAY/WEEK/MONTH）或 yyyy-MM（YEAR）。 */
  date: string;
  time: number;
}

/** 排行条目，对应上游 ReadBookRanking。 */
export interface ReadBookRanking {
  bookName: string;
  bookAuthor: string;
  readTime: number;
}

/** 总览页的全部计算结果，对应上游 ReadRecordOverviewUiState。 */
export interface ReadRecordOverviewState {
  period: ReadPeriod;
  /** 参考日期的 yyyy-MM-dd。 */
  referenceDate: string;
  totalTime: number;
  readingDays: number;
  totalBooks: number;
  finishedBooks: number;
  readingBooks: number;
  dailyTimeData: DailyTimePoint[];
  topBooks: ReadBookRanking[];
  /** 每天读得最多的书，用全部明细算，不按周期过滤。 */
  dailyTopBook: Map<string, string>;
  allReadTimes: Map<string, number>;
  allReadCounts: Map<string, number>;
}

/** 参与统计的一本书的进度信息，页面从 Book[] 转换后传入。 */
export interface OverviewBookProgress {
  bookName: string;
  bookAuthor: string;
  totalChapterNum: number;
  durChapterIndex: number;
  durChapterPos: number;
}

function parseDate(key: string): Date | undefined {
  const parts = key.split('-');
  if (parts.length !== 3) { return undefined; }
  const year = Number(parts[0]);
  const month = Number(parts[1]);
  const day = Number(parts[2]);
  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) { return undefined; }
  const date = new Date(year, month - 1, day);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    return undefined;
  }
  return date;
}

function dateKey(date: Date): string {
  const year = date.getFullYear().toString();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  const day = date.getDate().toString().padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function monthKey(date: Date): string {
  const year = date.getFullYear().toString();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  return `${year}-${month}`;
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date.getTime());
  next.setDate(next.getDate() + days);
  return next;
}

function addMonths(date: Date, months: number): Date {
  const next = new Date(date.getTime());
  next.setDate(1);
  next.setMonth(next.getMonth() + months);
  return next;
}

/** 周期区间：日=当天、周=周一到周日、月=月初到月末、年=年初到年末、总=不过滤。 */
export function overviewPeriodRange(period: ReadPeriod, refDate: Date): [Date, Date] {
  if (period === ReadPeriod.DAY) { return [refDate, refDate]; }
  if (period === ReadPeriod.WEEK) {
    const weekday = refDate.getDay();
    const mondayOffset = weekday === 0 ? -6 : 1 - weekday;
    return [addDays(refDate, mondayOffset), addDays(refDate, mondayOffset + 6)];
  }
  if (period === ReadPeriod.MONTH) {
    const start = new Date(refDate.getFullYear(), refDate.getMonth(), 1);
    const end = new Date(refDate.getFullYear(), refDate.getMonth() + 1, 0);
    return [start, end];
  }
  if (period === ReadPeriod.YEAR) {
    return [new Date(refDate.getFullYear(), 0, 1), new Date(refDate.getFullYear(), 11, 31)];
  }
  return [new Date(1900, 0, 1), new Date(2100, 11, 31)];
}

function inRange(key: string, start: Date, end: Date): boolean {
  const date = parseDate(key);
  if (date === undefined) { return false; }
  return date.getTime() >= start.getTime() && date.getTime() <= end.getTime();
}

/** 统计格「阅读时间」文案：只到分钟，对应上游 hourMinuteDuration + 三个 format 字符串。 */
export function hourMinuteLabel(millis: number): string {
  const minutes = Math.floor(millis / 60000);
  const hours = Math.floor(minutes / 60);
  const restMinutes = minutes % 60;
  if (hours > 0 && restMinutes > 0) { return `${hours}小时${restMinutes}分钟`; }
  if (hours > 0) { return `${hours}小时`; }
  return `${restMinutes}分钟`;
}

/**
 * 柱状图顶端刻度：按上游 ReadRecordCharts.kt:45-53 的五档向上取整。
 * 不足 1 分钟取 1 分钟；10 分钟内按 1 分钟；1 小时内按 5 分钟；
 * 12 小时内按 1 小时；超过 12 小时按 4 小时。
 */
export function roundedMaxTime(data: DailyTimePoint[]): number {
  let raw = 1;
  for (const point of data) { raw = Math.max(raw, point.time); }
  const minute = 60 * 1000;
  if (raw < minute) { return minute; }
  if (raw < 10 * minute) { return Math.ceil(raw / minute) * minute; }
  if (raw < 60 * minute) { return Math.ceil(raw / (5 * minute)) * 5 * minute; }
  if (raw < 12 * 3600 * 1000) { return Math.ceil(raw / (3600 * 1000)) * 3600 * 1000; }
  return Math.ceil(raw / (4 * 3600 * 1000)) * 4 * 3600 * 1000;
}

/**
 * 总览计算入口：入参即数据，不查库。
 * 对齐上游 GetReadRecordOverviewUseCase.invoke(period, refDate, details, latestRecords, allBooks)。
 */
export function computeReadRecordOverview(
  period: ReadPeriod,
  refDate: Date,
  details: ReadRecordDetail[],
  latestRecords: ReadRecordSummary[],
  books: OverviewBookProgress[]
): ReadRecordOverviewState {
  // ArkTS 不支持数组解构声明（arkts-no-destruct-decls），区间按下标取。
  const range = overviewPeriodRange(period, refDate);
  const start = range[0];
  const end = range[1];
  const filteredDetails = period === ReadPeriod.ALL
    ? details
    : details.filter((item: ReadRecordDetail) => inRange(item.date, start, end));

  // 「总」模式用合并后的汇总（含无每日详情来源的旧版遗留时长），周期模式按明细统计。
  const totalTime = period === ReadPeriod.ALL
    ? latestRecords.reduce((total: number, item: ReadRecordSummary) => total + item.readTime, 0)
    : filteredDetails.reduce((total: number, item: ReadRecordDetail) => total + item.readTime, 0);
  const readingDays = new Set<string>(filteredDetails.map((item: ReadRecordDetail) => item.date)).size;

  const periodBooks: Map<string, number> = new Map<string, number>();
  for (const item of filteredDetails) {
    const key = `${item.bookName}\u0000${item.bookAuthor}`;
    periodBooks.set(key, (periodBooks.get(key) ?? 0) + item.readTime);
  }
  const totalBooks = periodBooks.size;

  const shelfKeys: Set<string> = new Set<string>();
  for (const item of latestRecords) {
    shelfKeys.add(`${item.bookName}\u0000${item.bookAuthor}`);
  }
  const progressByKey: Map<string, OverviewBookProgress> = new Map<string, OverviewBookProgress>();
  for (const book of books) {
    progressByKey.set(`${book.bookName}\u0000${book.bookAuthor}`, book);
  }
  let readingBooks = 0;
  let finishedBooks = 0;
  for (const key of periodBooks.keys()) {
    if (shelfKeys.has(key)) { readingBooks += 1; }
    const book = progressByKey.get(key);
    if (book !== undefined && book.totalChapterNum > 0 &&
      book.durChapterIndex >= book.totalChapterNum - 1 && book.durChapterPos !== 0) {
      finishedBooks += 1;
    }
  }

  const topBooks: ReadBookRanking[] = [];
  periodBooks.forEach((time: number, key: string) => {
    const parts = key.split('\u0000');
    topBooks.push({ bookName: parts[0], bookAuthor: parts[1], readTime: time });
  });
  topBooks.sort((left: ReadBookRanking, right: ReadBookRanking) => right.readTime - left.readTime);

  // 全部明细按天取 readTime 最大的一本，供月历格子铺封面。
  const dailyTopBook: Map<string, string> = new Map<string, string>();
  const dailyBest: Map<string, number> = new Map<string, number>();
  for (const item of details) {
    const previous = dailyBest.get(item.date) ?? -1;
    if (item.readTime > previous) {
      dailyBest.set(item.date, item.readTime);
      dailyTopBook.set(item.date, `${item.bookName}\u0000${item.bookAuthor}`);
    }
  }

  const allReadTimes: Map<string, number> = new Map<string, number>();
  const allReadCounts: Map<string, number> = new Map<string, number>();
  for (const item of details) {
    if (parseDate(item.date) === undefined) { continue; }
    allReadTimes.set(item.date, (allReadTimes.get(item.date) ?? 0) + item.readTime);
    allReadCounts.set(item.date, (allReadCounts.get(item.date) ?? 0) + 1);
  }

  const dailyTimeData: DailyTimePoint[] = [];
  if (period !== ReadPeriod.ALL) {
    if (period === ReadPeriod.YEAR) {
      for (let month = 0; month < 12; month += 1) {
        const key = monthKey(new Date(refDate.getFullYear(), month, 1));
        let time = 0;
        for (const item of filteredDetails) {
          if (item.date.startsWith(key)) { time += item.readTime; }
        }
        dailyTimeData.push({ date: key, time: time });
      }
    } else {
      let cursor = start;
      while (cursor.getTime() <= end.getTime()) {
        const key = dateKey(cursor);
        let time = 0;
        for (const item of filteredDetails) {
          if (item.date === key) { time += item.readTime; }
        }
        dailyTimeData.push({ date: key, time: time });
        cursor = addDays(cursor, 1);
      }
    }
  }

  return {
    period: period,
    referenceDate: dateKey(refDate),
    totalTime: totalTime,
    readingDays: readingDays,
    totalBooks: totalBooks,
    finishedBooks: finishedBooks,
    readingBooks: readingBooks,
    dailyTimeData: dailyTimeData,
    topBooks: topBooks.slice(0, 10),
    dailyTopBook: dailyTopBook,
    allReadTimes: allReadTimes,
    allReadCounts: allReadCounts
  };
}
