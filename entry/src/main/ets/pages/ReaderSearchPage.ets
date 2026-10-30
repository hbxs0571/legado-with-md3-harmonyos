import { Book } from '../model/Book';
import { ReaderSearchHistoryEntry } from '../model/ReaderSearchHistory';
import { BookRepository } from '../data/BookRepository';
import { LocalTextSemantics } from '../data/LocalTextSemantics';
import { ReplaceRuleRepository } from '../data/ReplaceRuleRepository';
import { ReaderSearchHistoryRepository } from '../data/ReaderSearchHistoryRepository';
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

@Component
export struct ReaderSearchPage {
  @Prop book: Book = {
    id: '', title: '', author: '', category: '', lastChapter: '', progress: 0,
    coverColor: '#000000', coverMark: '', isLocal: true
  };
  @Prop bookTitle: string = '';
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  onReplaceRulesChanged: () => void = () => {};
  onOpenResult: (chapterIndex: number, position: number) => void = (_index: number, _position: number) => {};
  @State query: string = '';
  @State matches: ReaderSearchMatch[] = [];
  @State searchHistory: ReaderSearchHistoryEntry[] = [];
  @State searching: boolean = false;
  @State regexMode: boolean = false;
  @State replaceEnabled: boolean = false;
  @State historyOnlyThisBook: boolean = true;
  @State searchProgress: number = 0;
  @State searchError: string = '';
  onBack: () => void = () => {};
  private searchGeneration: number = 0;
  private searchTimer: number = -1;
  private resultScroller: Scroller = new Scroller();
  private historyContext: Context | undefined = undefined;
  private historyGeneration: number = 0;

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext();
    if (context !== undefined) {
      this.historyContext = context;
      this.reloadSearchHistory();
    }
  }

  aboutToDisappear(): void {
    this.searchGeneration++;
    this.historyGeneration++;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
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
    const keyword = value.trim();
    if (keyword.length === 0) {
      this.searching = false;
      return;
    }
    if (this.book.contentPath === undefined || this.book.chapterTitles === undefined) {
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
    const chapterCount = this.book.chapterTitles?.length ?? 0;
    try {
      await BookRepository.forEachChapter(this.book,
        async (content: string, chapterIndex: number): Promise<boolean> => {
          if (generation !== this.searchGeneration || results.length >= 200) { return false; }
          const chapterTitle = this.book.chapterTitles?.[chapterIndex] ?? this.book.lastChapter;
          const semanticContent = LocalTextSemantics.fromRawBody(content);
          const chapterMatches: ReaderSearchMatch[] = [];
          const hits: ReaderSearchHit[] = [];
          if (this.regexMode) {
            try {
              const matcher = new RegExp(keyword, 'g');
              let match = matcher.exec(semanticContent);
              while (match !== null && hits.length + results.length < 200) {
                const length = match[0].length;
                if (length > 0) {
                  hits.push({ position: match.index, length: length });
                }
                if (length === 0) { matcher.lastIndex++; }
                match = matcher.exec(semanticContent);
              }
            } catch (_) {
              this.searching = false;
              this.searchError = '正则表达式无效';
              return false;
            }
          } else {
            let position = semanticContent.indexOf(keyword);
            while (position >= 0 && hits.length + results.length < 200) {
              hits.push({ position: position, length: keyword.length });
              position = semanticContent.indexOf(keyword, position + Math.max(1, keyword.length));
            }
          }
          for (let hitIndex = 0; hitIndex < hits.length && results.length < 200; hitIndex++) {
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
          return generation === this.searchGeneration && results.length < 200;
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
        Span(match.excerpt.substring(0, match.excerptMatchStart)).fontColor('#D9DAE0');
      }
      if (Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength) > match.excerptMatchStart) {
        Span(match.excerpt.substring(
          match.excerptMatchStart,
          Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength)
        ))
          .fontColor('#FFFFFF')
          .backgroundColor('#454B62')
          .fontWeight(FontWeight.Medium);
      }
      if (Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength) < match.excerpt.length) {
        Span(match.excerpt.substring(
          Math.min(match.excerpt.length, match.excerptMatchStart + match.matchLength)
        )).fontColor('#D9DAE0');
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
        }.width(40).height(40).backgroundColor('#1B1C22').borderRadius(22).onClick(() => this.onBack())
        Blank()
        Image($r('app.media.profile_find_replace')).width(20).height(20)
          .fillColor(this.replaceEnabled ? '#AFC2FF' : '#D8D9E0').width(38)
          .onClick(() => this.toggleReplaceMode())
        Image($r('app.media.app_code')).width(18).height(18).fillColor('#D8D9E0').width(42)
          .fillColor(this.regexMode ? '#AFC2FF' : '#D8D9E0').onClick(() => this.toggleRegexMode())
      }.padding({ left: 16, right: 16, top: 14, bottom: 18 })

      Text(this.query.trim().length > 0 && this.matches.length > 0
        ? '共 ' + this.matches.length.toString() + ' 条结果' : '搜索内容')
        .fontSize(23).fontWeight(FontWeight.Bold).fontColor('#E5E6EA')
        .alignSelf(ItemAlign.Start).margin({ left: 18, bottom: 12 })

      Row() {
        AppSearchGlyph()
        TextInput({ placeholder: '搜索本书…', text: this.query })
          .fontSize(14).fontColor('#E3E4E8').placeholderColor('#8C8E98')
          .backgroundColor(Color.Transparent).layoutWeight(1)
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => this.scheduleSearch(value))
          .onSubmit(() => this.submitSearch())
        if (this.query.length > 0) {
          Image($r('app.media.profile_close')).width(18).height(18).fillColor('#AEB0B9')
            .width(30).onClick(() => this.scheduleSearch(''))
        }
      }.padding({ left: 14, right: 10, top: 7, bottom: 7 }).backgroundColor('#1B1C22').borderRadius(24)
        .margin({ left: 16, right: 16 })

      if (this.query.trim().length === 0) {
        Row() {
          Text('搜索历史').fontSize(12).fontColor('#AFC2FF')
          Blank()
          Row() {
            AppGlyph({ name: this.historyOnlyThisBook ? 'book' : 'bookshelf', glyphSize: 13, tint: '#25262C' })
            Text(this.historyOnlyThisBook ? '仅本书' : '全部')
              .fontSize(11).fontColor('#25262C').margin({ left: 5 })
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F0F1F5')
          .borderRadius(16)
          .onClick(() => this.historyOnlyThisBook = !this.historyOnlyThisBook)
        }.padding({ left: 18, right: 18, top: 13, bottom: 8 })
      } else {
        Row() {
          Text(this.searching
            ? '正在搜索 ' + this.searchProgress.toString() + '/' + (this.book.chapterTitles?.length ?? 0).toString()
            : '本书正文 · 最多200条')
            .fontSize(12).fontColor('#AFC2FF')
          if (this.searching) {
            Text('停止').fontSize(12).fontColor('#AFC2FF').margin({ left: 12 })
              .onClick(() => this.stopSearch())
          }
        }.padding({ left: 18, right: 18, top: 13, bottom: 8 })
      }

      if (this.searchError.length > 0) {
        Column() {
          Text(this.searchError).fontSize(14).fontColor('#BFC0C8')
          Text(this.bookTitle).fontSize(11).fontColor('#777984').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.query.trim().length === 0) {
        if (this.visibleHistory().length === 0) {
          Column() {
            Text('(つ＿⊂)').fontSize(27).fontColor('#E3E4E8')
            Text('暂无搜索历史').fontSize(11).fontColor('#B4B5BC').margin({ top: 8 })
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.visibleHistory(), (entry: ReaderSearchHistoryEntry) => {
              ListItem() {
                Row() {
                  AppGlyph({ name: 'profileHistory', glyphSize: 18, tint: '#AFC2FF' })
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
                .backgroundColor('#1B1C22')
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
              .backgroundColor('#1B1C22')
              .borderRadius(20)
              .onClick(() => this.clearSearchHistory())
            }.align(Alignment.Center).margin({ top: 14, bottom: 20 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      } else if (this.matches.length === 0 && this.searching) {
        Column() {
          LoadingProgress().width(24).height(24).color('#AFC2FF')
          Text('正在搜索本书正文').fontSize(12).fontColor('#B4B5BC').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.matches.length === 0) {
        Column() {
          Text('没有找到相关内容！').fontSize(14).fontColor('#BFC0C8')
          Text(this.bookTitle).fontSize(11).fontColor('#777984').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.BottomEnd }) {
          List({ scroller: this.resultScroller }) {
            ForEach(this.matches, (match: ReaderSearchMatch) => {
              ListItem() {
                Column() {
                  Row() {
                    Text(match.chapterTitle).fontSize(13).fontColor('#AFC2FF')
                      .layoutWeight(1).maxLines(1)
                    if (match.isCurrentChapter) {
                      Text('当前章').fontSize(10).fontColor('#25262C')
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                        .backgroundColor('#C8D3FF').borderRadius(12)
                    }
                    Text(Math.round(match.progressPercent).toString() + '%')
                      .fontSize(10).fontColor('#D9DAE0')
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor('#303139').borderRadius(12).margin({ left: 6 })
                  }
                  .width('100%')
                  this.highlightedExcerpt(match)
                }
                .width('100%')
                .padding(14)
                .backgroundColor('#1B1C22')
                .borderRadius(12)
                .onClick(() => this.onOpenResult(match.chapterIndex, match.position))
              }
              .margin({ left: 16, right: 16, bottom: 8 })
            }, (match: ReaderSearchMatch) => match.key)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          if (this.searching || this.matches.length > 0) {
            Stack({ alignContent: Alignment.Center }) {
              if (this.searching) {
                AppGlyph({ name: 'profileClose', glyphSize: 22, tint: '#ECEEF2' })
              } else {
                Image($r('app.media.app_locate')).width(22).height(22).fillColor('#ECEEF2')
              }
            }
            .width(48)
            .height(48)
            .backgroundColor('#454B62')
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
    .backgroundColor('#111217')
  }
}

@Component
struct AppSearchGlyph {
  build() {
    Image($r('app.media.reader_search')).width(20).height(20).fillColor('#C9CAD2').width(30)
  }
}
