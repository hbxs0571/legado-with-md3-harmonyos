import { Book } from '../model/Book';
import { BookRepository } from '../data/BookRepository';
import { LocalTextSemantics } from '../data/LocalTextSemantics';
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
  @State chapterContents: string[] = [];
  @State searching: boolean = false;
  @State regexMode: boolean = false;
  @State searchError: string = '';
  onBack: () => void = () => {};
  private searchGeneration: number = 0;
  private searchTimer: number = -1;

  aboutToDisappear(): void {
    this.searchGeneration++;
    if (this.searchTimer >= 0) {
      clearTimeout(this.searchTimer);
      this.searchTimer = -1;
    }
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
    try {
      this.chapterContents = await BookRepository.readAllChapters(this.book);
      this.onReplaceRulesChanged();
      this.searchChapterBatch(generation, 0, []);
    } catch (_) {
      if (generation === this.searchGeneration) {
        this.searching = false;
        this.searchError = '读取本书正文失败，搜索已停止';
      }
    }
  }

  private searchChapterBatch(generation: number, startIndex: number, existing: ReaderSearchMatch[]): void {
    if (generation !== this.searchGeneration) { return; }
    const chapterTitles = this.book.chapterTitles ?? [];
    const keyword = this.query.trim();
    if (keyword.length === 0) {
      this.searching = false;
      return;
    }
    const results = existing.slice();
    let chapterIndex = startIndex;
    let scannedChapters = 0;
    try {
      while (chapterIndex < chapterTitles.length && scannedChapters < 12 && results.length < 200) {
        const chapterTitle = chapterTitles[chapterIndex];
        if (chapterTitle !== undefined) {
          const rawContent = this.chapterContents[chapterIndex] ?? '';
          const content = LocalTextSemantics.fromRawBody(rawContent);
          const hits: ReaderSearchHit[] = [];
          if (this.regexMode) {
            try {
              const matcher = new RegExp(keyword, 'g');
              let match = matcher.exec(content);
              while (match !== null && hits.length < 200) {
                const length = match[0].length;
                if (length > 0) {
                  hits.push({ position: match.index, length: length });
                }
                if (length === 0) { matcher.lastIndex++; }
                match = matcher.exec(content);
              }
            } catch (_) {
              this.searching = false;
              this.searchError = '正则表达式无效';
              return;
            }
          } else {
            let position = content.indexOf(keyword);
            while (position >= 0 && hits.length < 200) {
              hits.push({ position: position, length: keyword.length });
              position = content.indexOf(keyword, position + Math.max(1, keyword.length));
            }
          }
          for (let hitIndex = 0; hitIndex < hits.length && results.length < 200; hitIndex++) {
            const hit = hits[hitIndex];
            if (hit === undefined) { continue; }
            const start = Math.max(0, hit.position - 28);
            const end = Math.min(content.length, hit.position + hit.length + 48);
            const excerpt = content.substring(start, end).replace(/\n/g, ' ').trim();
            results.push({
              key: chapterIndex.toString() + '-' + hit.position.toString(),
              chapterIndex: chapterIndex,
              chapterTitle: chapterTitle,
              position: hit.position,
              excerpt: excerpt
            });
          }
        }
        chapterIndex++;
        scannedChapters++;
      }
      if (generation !== this.searchGeneration) { return; }
      this.matches = results;
      if (chapterIndex < chapterTitles.length && results.length < 200) {
        this.searchTimer = setTimeout(() => {
          this.searchTimer = -1;
          this.searchChapterBatch(generation, chapterIndex, results);
        }, 0);
      } else {
        this.searching = false;
      }
    } catch (_) {
      if (generation === this.searchGeneration) {
        this.searching = false;
        this.searchError = '读取本地章节失败，搜索已停止';
      }
    }
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.reader_back')).width(22).height(22).fillColor('#E4E5EA')
        }.width(40).height(40).backgroundColor('#1B1C22').borderRadius(22).onClick(() => this.onBack())
        Blank()
        Image($r('app.media.app_refresh')).width(20).height(20).fillColor('#D8D9E0').width(38)
          .onClick(() => this.scheduleSearch(''))
        Image($r('app.media.app_code')).width(18).height(18).fillColor('#D8D9E0').width(42)
          .fillColor(this.regexMode ? '#AFC2FF' : '#D8D9E0').onClick(() => this.toggleRegexMode())
      }.padding({ left: 16, right: 16, top: 14, bottom: 18 })

      Text('搜索内容').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#E5E6EA')
        .alignSelf(ItemAlign.Start).margin({ left: 18, bottom: 12 })
      Row() {
        AppSearchGlyph()
        TextInput({ placeholder: '搜索本书…', text: this.query })
          .fontSize(14).fontColor('#E3E4E8').placeholderColor('#8C8E98')
          .backgroundColor(Color.Transparent).layoutWeight(1)
          .onChange((value: string) => this.scheduleSearch(value))
      }.padding({ left: 14, right: 14, top: 7, bottom: 7 }).backgroundColor('#1B1C22').borderRadius(24)
        .margin({ left: 16, right: 16 })

      Row() {
        Text(this.searching ? '正在搜索本书章节…' : '本书正文 · 最多200条')
          .fontSize(12).fontColor('#AFC2FF')
        Blank()
        Row() {
          Image($r('app.media.app_book')).width(13).height(13).fillColor('#25262C')
          Text('本书').fontSize(11).fontColor('#25262C').margin({ left: 5 })
        }.padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F0F1F5').borderRadius(16)
      }.padding({ left: 18, right: 18, top: 13, bottom: 8 })

      if (this.searchError.length > 0) {
        Column() {
          Text(this.searchError).fontSize(14).fontColor('#BFC0C8')
          Text(this.bookTitle).fontSize(11).fontColor('#777984').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.query.trim().length === 0) {
        Column() {
          Text('(つ﹏⊂)').fontSize(27).fontColor('#E3E4E8')
          Text('输入关键词搜索本书正文').fontSize(11).fontColor('#B4B5BC').margin({ top: 8 })
          Text(this.bookTitle).fontSize(10).fontColor('#747680').margin({ top: 18 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.matches.length === 0 && this.searching) {
        Column() {
          LoadingProgress().width(24).height(24).color('#AFC2FF')
          Text('正在搜索本书正文').fontSize(12).fontColor('#B4B5BC').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.matches.length === 0) {
        Column() {
          Text('没有找到匹配内容').fontSize(14).fontColor('#BFC0C8')
          Text(this.bookTitle).fontSize(11).fontColor('#777984').margin({ top: 8 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.matches, (match: ReaderSearchMatch) => {
            ListItem() {
              Column() {
                Text(match.chapterTitle).fontSize(13).fontColor('#AFC2FF').maxLines(1)
                Text(match.excerpt).fontSize(13).fontColor('#D9DAE0')
                  .maxLines(3).margin({ top: 6 })
              }.width('100%').padding(14).backgroundColor('#1B1C22').borderRadius(12)
            }.margin({ left: 16, right: 16, bottom: 8 })
              .onClick(() => this.onOpenResult(match.chapterIndex, match.position))
          }, (match: ReaderSearchMatch) => match.key)
        }.layoutWeight(1).scrollBar(BarState.Off)
      }
    }.width('100%').height('100%').backgroundColor('#111217')
  }
}

@Component
struct AppSearchGlyph {
  build() {
    Image($r('app.media.reader_search')).width(20).height(20).fillColor('#C9CAD2').width(30)
  }
}
