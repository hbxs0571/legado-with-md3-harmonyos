import { Book, BookChapter } from '../model/Book';
import { ReaderSearchHistoryEntry } from '../model/ReaderSearchHistory';
import { BookRepository } from '../data/BookRepository';
import { LocalTextSemantics } from '../data/LocalTextSemantics';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { ReaderSearchHistoryRepository } from '../data/ReaderSearchHistoryRepository';
import { ReaderSearchRegex } from '../data/ReaderSearchRegex';
import { ReaderSearchNavItem } from '../model/ReaderSearchNav';
import { AppGlyph } from '../components/AppGlyph';

interface ReaderSearchHit {
  position: number;
  length: number;
}

interface ReaderSearchMatch {
  key: string;
  chapterIndex: number;
  chapterTitle: string;
  position: number;
  excerpt: string;
  excerptMatchStart: number;
  matchLength: number;
  progressPercent: number;
  isCurrentChapter: boolean;
}

/**
 * 结果安全上限。上游 SearchContentRepository.kt:112-160 全文无 take/limit，
 * 搜多少出多少；本地保留一个大得多的兜底值，防止正则全命中把内存打爆。
 */
const SEARCH_RESULT_LIMIT: number = 5000;

@Component
export struct ReaderSearchPage {
  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#1B1C22';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#2E3038';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#3F5BD9';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#F5F6F8';
  @StorageProp('themeColorSurfaceTertiary') themeColorSurfaceTertiary: string = '#F0F1F5';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#FFFFFF';
  // 批6：上游搜索高亮/顶栏选中态走 primaryContainer，原先降级用 surfaceElevated；
  // 现改读主题真色位 themeColorPrimaryContainer，默认值取草野夜档真值。
  @StorageProp('themeColorPrimaryContainer') themeColorPrimaryContainer: string = '#354E16';
  @StorageProp('appTopInset') appTopInset: number = 0;
  @StorageProp('themeAppBackground') themeAppBackground: string = '';
  @StorageProp('themePureBlack') themePureBlack: boolean = false;
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0, isLocal: true
  };
  @Prop bookTitle: string = '';
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onReplaceRulesChanged: () => void = () => {};
  /**
   * 打开一条搜索结果。除了章号与位置，还把整份结果集与当前下标一并交出去：
   * 跳进正文后搜索页会被卸载，正文两侧的「上一个/下一个」与底部结果条要靠它。
   */
  onOpenResult: (chapterIndex: number, position: number,
    items: ReaderSearchNavItem[], index: number) => void =
    (_index: number, _position: number, _items: ReaderSearchNavItem[], _at: number) => {};
  @State query: string = '';
  @State matches: ReaderSearchMatch[] = [];
  @State searchHistory: ReaderSearchHistoryEntry[] = [];
  @State searching: boolean = false;
  @State regexMode: boolean = false;
  @State replaceEnabled: boolean = false;
  @State historyOnlyThisBook: boolean = true;
  @State searchProgress: number = 0;
  @State searchError: string = '';
  /** 因正则超时被跳过的章节数（本地无展示点，仅计数；上游也不提示超时章数）。 */
  @State timedOutChapterCount: number = 0;
  /**
   * 顶栏动作按钮的 1 秒文字提示（上游 `TopBarAnimatedActionButton`：点击后
   * AnimatedActionButtonCore 显示 activeText/inactiveText，1 秒后收起）。
   */
  @State actionHint: string = '';
  private actionHintTimer: number = -1;
  onBack: () => void = () => {};
  private searchGeneration: number = 0;
  private searchTimer: number = -1;
  private resultScroller: Scroller = new Scroller();
  private historyContext: Context | undefined = undefined;
  private historyGeneration: number = 0;
  /** 目录行，打开页面时从 chapters 表读一次；搜索结果的章节名从这里取。 */
  @State chapterRows: BookChapter[] = [];

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      this.historyContext = context;
      this.reloadSearchHistory();
      this.loadChapterRows(context);
    }
    // 上游 SearchBar.kt:74-84 默认 autoFocus=true：进页面即 requestFocus + 弹键盘。
    // 这里延后一拍，等首帧布局完成后再抢焦点，否则焦点会被外层容器吃掉。
    setTimeout(() => {
      try {
        this.getUIContext().getFocusController().requestFocus('readerSearchInput');
      } catch (_) {
      }
    }, 200);
  }

  private async loadChapterRows(context: Context): Promise<void> {
    try {
      this.chapterRows = await BookRepository.loadChapters(context, this.book);
    } catch (_) {
      this.chapterRows = [];
    }
  }

  aboutToDisappear(): void {
    this.searchGeneration++;
    this.historyGeneration++;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    if (this.actionHintTimer >= 0) {
      clearTimeout(this.actionHintTimer);
      this.actionHintTimer = -1;
    }
  }

  /** 顶栏动作按钮的 1 秒文字提示，对齐上游 `AnimatedActionButtonCore.kt:49-54` 的 delay(1000)。 */
  private showActionHint(text: string): void {
    this.actionHint = text;
    if (this.actionHintTimer >= 0) {
      clearTimeout(this.actionHintTimer);
    }
    this.actionHintTimer = setTimeout(() => {
      this.actionHint = '';
      this.actionHintTimer = -1;
    }, 1000);
  }

  private visibleHistory(): ReaderSearchHistoryEntry[] {
    if (!this.historyOnlyThisBook) {
      return this.searchHistory;
    }
    // 上游 search_content_history 没有 bookId 列，按书名 + 作者过滤（同上游 getByBook）
    return this.searchHistory.filter((entry: ReaderSearchHistoryEntry) =>
      entry.bookName === this.book.title && entry.bookAuthor === this.book.author);
  }

  private async reloadSearchHistory(): Promise<void> {
    const context = this.historyContext;
    const generation = ++this.historyGeneration;
    if (context === undefined) { return; }
    const entries = await ReaderSearchHistoryRepository.load(context);
    if (generation === this.historyGeneration) {
      this.searchHistory = entries;
    }
  }

  private async submitSearch(): Promise<void> {
    const keyword = this.query.trim();
    if (keyword.length === 0) { return; }
    this.scheduleSearch(keyword);
    const context = this.historyContext;
    if (context === undefined) { return; }
    try {
      const entries = await ReaderSearchHistoryRepository.saveQuery(context, this.book, keyword);
      this.searchHistory = entries;
    } catch (_) {
      this.onUnavailableAction('搜索历史保存失败');
    }
  }

  private async deleteSearchHistory(entry: ReaderSearchHistoryEntry): Promise<void> {
    const context = this.historyContext;
    if (context === undefined) { return; }
    try {
      this.searchHistory = await ReaderSearchHistoryRepository.delete(context, entry.id);
    } catch (_) {
      this.onUnavailableAction('删除搜索历史失败');
    }
  }

  private async clearSearchHistory(): Promise<void> {
    const context = this.historyContext;
    if (context === undefined) { return; }
    try {
      this.searchHistory = await ReaderSearchHistoryRepository.clear(
        context, this.book.title, this.book.author, this.historyOnlyThisBook
      );
    } catch (_) {
      this.onUnavailableAction('清除搜索历史失败');
    }
  }

  private selectHistory(entry: ReaderSearchHistoryEntry): void {
    this.scheduleSearch(entry.query);
  }

  private toggleReplaceMode(): void {
    this.replaceEnabled = !this.replaceEnabled;
    // 上游 TopBarAnimatedActionButton：点击后按钮旁展开「替换开启/关闭」1 秒。
    this.showActionHint(this.replaceEnabled ? '替换开启' : '替换关闭');
    if (this.query.trim().length > 0) {
      this.scheduleSearch(this.query);
    }
  }

  private stopSearch(): void {
    this.searchGeneration++;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    this.searching = false;
  }

  private toggleRegexMode(): void {
    this.regexMode = !this.regexMode;
    this.showActionHint(this.regexMode ? '正则开启' : '正则关闭');
    if (this.query.trim().length > 0) {
      this.scheduleSearch(this.query);
    }
  }

  private scheduleSearch(value: string): void {
    this.query = value;
    this.searchGeneration++;
    const generation = this.searchGeneration;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
    this.matches = [];
    this.searchProgress = 0;
    this.searchError = '';
    this.timedOutChapterCount = 0;
    const keyword = value.trim();
    if (keyword.length === 0) {
      this.searching = false;
      return;
    }
    if (this.book.contentPath === undefined || this.chapterRows.length === 0) {
      this.searching = false;
      this.searchError = '这本书没有可搜索的本地正文';
      return;
    }
    this.searching = true;
    this.searchTimer = setTimeout(() => {
      this.searchTimer = -1;
      this.loadChaptersAndSearch(generation);
    }, 260);
  }

  private async loadChaptersAndSearch(generation: number): Promise<void> {
    if (generation !== this.searchGeneration) { return; }
    const keyword = this.query.trim();
    const results: ReaderSearchMatch[] = [];
    const chapterCount = this.chapterRows.length;
    try {
      await BookRepository.forEachChapter(this.book,
        async (content: string, chapterIndex: number): Promise<boolean> => {
          if (generation !== this.searchGeneration || results.length >= SEARCH_RESULT_LIMIT) { return false; }
          const chapterTitle = this.chapterRows[chapterIndex]?.title ?? this.book.lastChapter;
          const semanticContent = LocalTextSemantics.fromRawBody(content);
          const chapterMatches: ReaderSearchMatch[] = [];
          const hits: ReaderSearchHit[] = [];
          if (this.regexMode) {
            // 正则匹配丢到 worker 线程并带 500ms 预算（上游 REGEX_MATCH_TIMEOUT_MILLIS）：
            // 灾难性回溯的正则最多卡这一章 500ms，界面不冻，超时就跳过本章继续搜。
            try {
              const regexResult = await ReaderSearchRegex.run(semanticContent, keyword, SEARCH_RESULT_LIMIT - results.length);
              if (regexResult.timedOut) {
                this.timedOutChapterCount++;
                this.searchProgress = chapterIndex + 1;
                return generation === this.searchGeneration && results.length < SEARCH_RESULT_LIMIT;
              }
              for (let hitIndex = 0; hitIndex < regexResult.hits.length; hitIndex++) {
                const hit = regexResult.hits[hitIndex];
                if (hit === undefined) { continue; }
                hits.push({ position: hit.position, length: hit.length });
              }
            } catch (_) {
              this.searching = false;
              this.searchError = '正则表达式无效';
              return false;
            }
          } else {
            let position = semanticContent.indexOf(keyword);
            while (position >= 0 && hits.length + results.length < SEARCH_RESULT_LIMIT) {
              hits.push({ position: position, length: keyword.length });
              position = semanticContent.indexOf(keyword, position + Math.max(1, keyword.length));
            }
          }
          for (let hitIndex = 0; hitIndex < hits.length && results.length < SEARCH_RESULT_LIMIT; hitIndex++) {
            const hit = hits[hitIndex];
            if (hit === undefined) { continue; }
            const excerptStart = Math.max(0, hit.position - 12);
            const excerptEnd = Math.min(semanticContent.length, hit.position + hit.length + 12);
            chapterMatches.push({
              key: chapterIndex.toString() + '-' + hit.position.toString(),
              chapterIndex: chapterIndex,
              chapterTitle: chapterTitle,
              position: hit.position,
              excerpt: semanticContent.substring(excerptStart, excerptEnd).replace(/\n/g, ' ').trim(),
              excerptMatchStart: hit.position - excerptStart,
              matchLength: hit.length,
              progressPercent: chapterCount > 0 ? (chapterIndex + 1) / chapterCount * 100 : 0,
              isCurrentChapter: chapterIndex === (this.book.chapterIndex ?? -1)
            });
          }
          results.push(...chapterMatches);
          this.searchProgress = chapterIndex + 1;
          this.matches = results.slice();
          return generation === this.searchGeneration && results.length < SEARCH_RESULT_LIMIT;
        }, this.replaceEnabled);
      if (generation === this.searchGeneration) {
        this.searching = false;
      }
    } catch (_) {
      if (generation === this.searchGeneration) {
        this.searching = false;
        this.searchError = '读取本地章节失败，搜索已停止';
      }
    }
  }

  private locateCurrentChapter(): void {
    const currentChapter = this.book.chapterIndex ?? -1;
    const targetIndex = this.matches.findIndex((match: ReaderSearchMatch) =>
      match.chapterIndex === currentChapter);
    if (targetIndex >= 0) {
      this.resultScroller.scrollToIndex(targetIndex, true);
    }
  }

  @Builder
  private highlightedExcerpt(match: ReaderSearchMatch) {
    Text() {
      if (match.excerptMatchStart > 0) {
        Span(match.excerpt.substring(0, match.excerptMatchStart)).fontColor(this.themeColorTextSecondary);
      }
      if (Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength) > match.excerptMatchStart) {
        // 上游 SearchResult.kt:61-65：高亮 = accentColor 前景 + primaryContainer 背景 + Bold。
        Span(match.excerpt.substring(
          match.excerptMatchStart,
          Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength)
        ))
          .fontColor(this.themeColorAccent)
          .backgroundColor(this.themeColorPrimaryContainer)
          .fontWeight(FontWeight.Bold);
      }
      if (Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength) < match.excerpt.length) {
        Span(match.excerpt.substring(
          Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength)
        )).fontColor(this.themeColorTextSecondary);
      }
    }
    .fontSize(13)
    .maxLines(3)
    .margin({ top: 6 })
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(22).height(22).fillColor('#E4E5EA')
        }.width(40).height(40).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(22).onClick(() => this.onBack())
        Blank()
        // 上游两个 TopBarAnimatedActionButton 都是 36×36 盒 + 20dp 图标
        // （`SeriesIconButton.kt:54-55`），选中态底色 primaryContainer。
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.profile_find_replace')).width(20).height(20)
            .fillColor(this.replaceEnabled ? this.themeColorAccent : this.themeColorTextSecondary)
        }.width(36).height(36).borderRadius(18)
          .backgroundColor(this.replaceEnabled ? this.themeColorPrimaryContainer : Color.Transparent)
          .onClick(() => this.toggleReplaceMode())
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.app_code')).width(20).height(20)
            .fillColor(this.regexMode ? this.themeColorAccent : this.themeColorTextSecondary)
        }.width(36).height(36).borderRadius(18)
          .backgroundColor(this.regexMode ? this.themeColorPrimaryContainer : Color.Transparent)
          .onClick(() => this.toggleRegexMode())
        // 上游点击后按钮旁展开 1 秒文字；本地放在按钮右侧同一行。
        if (this.actionHint.length > 0) {
          Text(this.actionHint).fontSize(12).fontColor(this.themeColorAccent).margin({ left: 4 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 + this.appTopInset, bottom: 18 })

      Text(this.query.trim().length > 0 && this.matches.length > 0
        ? '共 ' + this.matches.length.toString() + ' 条结果' : '搜索内容')
        .fontSize(23).fontWeight(FontWeight.Bold).fontColor('#E5E6EA')
        .alignSelf(ItemAlign.Start).margin({ left: 18, bottom: 12 })

      Row() {
        AppSearchGlyph()
        TextInput({ placeholder: '搜索…', text: this.query })
          .id('readerSearchInput')
          .fontSize(14).fontColor(this.themeColorTextPrimary).placeholderColor('#8C8E98')
          .backgroundColor(Color.Transparent).layoutWeight(1)
          .defaultFocus(true)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => this.scheduleSearch(value))
          .onSubmit(() => this.submitSearch())
        if (this.query.length > 0) {
          Image($r('app.media.profile_close')).width(18).height(18).fillColor('#AEB0B9')
            .width(30).onClick(() => this.scheduleSearch(''))
        }
      }.padding({ left: 14, right: 10, top: 7, bottom: 7 }).backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary)).borderRadius(24)
        .margin({ left: 16, right: 16 })

      if (this.query.trim().length === 0) {
        // 上游 SearchContentScreen.kt:365-386：标题在 Box 里 align=Center 绝对居中，
        // 「仅本书」开关叠在 CenterEnd 同一行；文案恒定「仅本书」，图标 checked=Book /
        // unchecked=CollectionsBookmark。本地用 Stack 复刻这个叠放关系。
        Stack({ alignContent: Alignment.Center }) {
          Text('搜索历史').fontSize(12).fontColor(this.themeColorAccent)
          Row() {
            Row() {
              AppGlyph({ name: this.historyOnlyThisBook ? 'book' : 'bookshelf', glyphSize: 13, tint: this.themeColorTextPrimary })
              Text('仅本书')
                .fontSize(11).fontColor(this.themeColorTextPrimary).margin({ left: 5 })
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.historyOnlyThisBook ? this.themeColorSurfaceElevated : this.themeColorSurfaceTertiary)
            .borderRadius(16)
            .onClick(() => this.historyOnlyThisBook = !this.historyOnlyThisBook)
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 13, bottom: 8 })
      } else if (this.searching) {
        // 上游顶栏 title 已经是「共 N 条结果」，搜索结束后不再重复计数；
        // 搜索中的进度行是本地新增的（上游只用顶栏进度条表示），保留。
        Row() {
          Text('正在搜索 ' + this.searchProgress.toString() + '/' + this.chapterRows.length.toString())
            .fontSize(12).fontColor(this.themeColorAccent)
        }.width('100%').padding({ left: 16, right: 16, top: 13, bottom: 8 })
      }

      // 上游搜索中在顶栏下画一条 AppLinearProgressIndicator（SearchContentScreen.kt:247-249）。
      if (this.searching) {
        Progress({ value: this.searchProgress, total: Math.max(1, this.chapterRows.length), type: ProgressType.Linear })
          .width('calc(100% - 32vp)').height(2).margin({ left: 16, right: 16, top: 4 })
          .color(this.themeColorAccent)
          .backgroundColor(this.themeColorSurfaceTertiary)
      }

      if (this.searchError.length > 0) {
        Column() {
          Text(this.searchError).fontSize(14).fontColor('#BFC0C8')
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.query.trim().length === 0) {
        if (this.visibleHistory().length === 0) {
          Column() {
            Text('(つ＿⊂)').fontSize(27).fontColor(this.themeColorTextPrimary)
            Text('暂无搜索历史').fontSize(11).fontColor('#B4B5BC').margin({ top: 8 })
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.visibleHistory(), (entry: ReaderSearchHistoryEntry) => {
              ListItem() {
                Row() {
                  AppGlyph({ name: 'profileHistory', glyphSize: 18, tint: this.themeColorAccent })
                    .margin({ right: 12 })
                  Column() {
                    Text(entry.query).fontSize(14).fontColor('#D9DAE0').maxLines(1)
                    if (!this.historyOnlyThisBook) {
                      Text(entry.bookName + ' · ' + entry.bookAuthor)
                        .fontSize(10).fontColor('#81838D').maxLines(1).margin({ top: 3 })
                    }
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .onClick(() => this.selectHistory(entry))
                  AppGlyph({ name: 'profileClose', glyphSize: 17, tint: '#B0B1BA' })
                    .padding(8)
                    .onClick(() => this.deleteSearchHistory(entry))
                }
                .width('100%')
                .padding({ left: 14, right: 8, top: 12, bottom: 12 })
                .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
                .borderRadius(12)
              }.margin({ left: 16, right: 16, bottom: 7 })
            }, (entry: ReaderSearchHistoryEntry) => entry.id)
            ListItem() {
              Row() {
                AppGlyph({ name: 'delete', glyphSize: 18, tint: '#C5C7D0' })
                  .margin({ right: 8 })
                Text('清除搜索历史').fontSize(13).fontColor('#D9DAE0')
              }
              .padding({ left: 18, right: 18, top: 10, bottom: 10 })
              .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
              .borderRadius(20)
              .onClick(() => this.clearSearchHistory())
            }.align(Alignment.Center).margin({ top: 14, bottom: 20 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      } else if (this.matches.length === 0 && this.searching) {
        Column() {
          Text('正在搜索本书正文').fontSize(12).fontColor('#B4B5BC')
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.matches.length === 0) {
        Column() {
          Text('没有找到相关内容！').fontSize(14).fontColor('#BFC0C8')
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.BottomEnd }) {
          List({ scroller: this.resultScroller }) {
            ForEach(this.matches, (match: ReaderSearchMatch, matchIndex: number) => {
              ListItem() {
                // 上游角标是 Box 内 Modifier.align(Alignment.TopEnd) 的绝对定位行
                // （SearchContentScreen.kt:491-517），不是排在正文后面，所以这里用 Stack 叠放。
                Stack({ alignContent: Alignment.TopEnd }) {
                  Column() {
                    Row() {
                      // 上游 SearchResultItem：章名 titleSmall(14sp Medium) primary 色。
                      Text(match.chapterTitle).fontSize(14).fontWeight(FontWeight.Medium)
                        .fontColor(this.themeColorAccent)
                        .layoutWeight(1).maxLines(1)
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Top)
                    // 上游章名与摘录之间有 HorizontalDivider(surface 色)。
                    Divider().color(this.themeColorSurfacePrimary).margin({ top: 8, bottom: 8 })
                    this.highlightedExcerpt(match)
                  }
                  .width('100%')
                  // 上游角标圆角 8、padding 4/2，百分比一位小数且 >0 才显示。
                  Row() {
                    if (match.isCurrentChapter) {
                      Text('当前章节').fontSize(10).fontColor(this.themeColorTextPrimary)
                        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                        .backgroundColor(this.themeColorSurfaceElevated).borderRadius(8)
                    }
                    if (match.progressPercent > 0) {
                      Text(match.progressPercent.toFixed(1) + '%')
                        .fontSize(10).fontColor(this.themeColorTextPrimary)
                        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                        .backgroundColor(this.themeColorSurfaceElevated).borderRadius(8).margin({ left: 4 })
                    }
                  }
                }
                .width('100%')
                .padding(16)
                .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#0A0A0A' : this.themeColorSurfaceTertiary))
                .borderRadius(12)
                .onClick(() => this.onOpenResult(match.chapterIndex, match.position,
                  this.matches.map((item: ReaderSearchMatch): ReaderSearchNavItem => {
                    return {
                      chapterIndex: item.chapterIndex,
                      position: item.position,
                      chapterTitle: item.chapterTitle
                    } as ReaderSearchNavItem;
                  }), matchIndex))
              }
              .margin({ left: 16, right: 16, bottom: 8 })
            }, (match: ReaderSearchMatch) => match.key)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          // 上游 FAB 显示条件：(isSearching || results.isNotEmpty()) && query.isNotBlank()。
          if ((this.searching || this.matches.length > 0) && this.query.trim().length > 0) {
            Stack({ alignContent: Alignment.Center }) {
              if (this.searching) {
                AppGlyph({ name: 'profileClose', glyphSize: 22, tint: this.themeColorTextPrimary })
              } else {
                Image($r('app.media.app_locate')).width(22).height(22).fillColor(this.themeColorTextPrimary)
              }
            }
            .width(48)
            .height(48)
            .backgroundColor(this.themeColorSurfaceElevated)
            .borderRadius(26)
            .margin({ right: 20, bottom: 20 })
            .onClick(() => {
              if (this.searching) { this.stopSearch(); }
              else { this.locateCurrentChapter(); }
            })
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeAppBackground.length > 0 ? Color.Transparent : (this.themePureBlack ? '#000000' : this.themeColorSurfacePrimary))
  }
}

@Component
struct AppSearchGlyph {
  build() {
    Image($r('app.media.reader_search')).width(20).height(20).fillColor('#C9CAD2').width(30)
  }
}
