import { Book } from '../model/Book';
import { BookGroup } from '../model/BookGroup';
import { BookRepository } from '../data/BookRepository';
import { LocalBookRestorePlanner } from '../data/LocalBookRestorePlanner';
import { AppGlyph } from '../components/AppGlyph';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Context } from '@kit.AbilityKit';

/**
 * 书架管理页（:447–:475）。上游是 BookshelfManageScreen.kt，本地原先整页未建。
 *
 * 与上游的差异（逐行写进 BOOKSHELF.md 差异说明）：
 * - 上游「下载 / 停止」类按钮服务在线书的章节抓取；本地书正文本来就在磁盘上
 *   （readBookRow 把 isLocal 写死 true），本页不放下载入口（:450/:454/:461 判不接）。
 * - 上游右侧徽标显示「已缓存 N/M 章」；本地恒显示「本地书」。
 * - 本地 Book 没有 origin/originName，第三行左半用 groupNames、右半用 androidOriginalPath 的文件名。
 * - 导出走鸿蒙 DocumentViewPicker.save()，每本弹一次系统保存框（:471）。
 * - 删除用自绘 bindSheet（系统 AlertDialog 放不下勾选框），复用批5 的 BookRepository.deleteBooks。
 * - 独立 EPUB 导出打包器、书源选择/换源面板本批不做（顺延），菜单里不放点了没反应的项。
 */

@Component
export struct BookshelfManagePage {
  @Prop books: Book[] = [];
  @Prop groups: BookGroup[] = [];
  /** 进页时的分组名；空串或「全部」都表示全部。 */
  @Prop initialGroupName: string = '';
  onBack: () => void = () => {};
  onOpenBookInfo: (book: Book) => void = (_book: Book) => {};
  /** 批量改动后通知 Index 重载书架。 */
  onLibraryChanged: () => Promise<void> = async () => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};

  @StorageProp('themeColorTextPrimary') themeColorTextPrimary: string = '#F1F2F6';
  @StorageProp('themeColorTextSecondary') themeColorTextSecondary: string = '#AEB0BA';
  @StorageProp('themeColorTextTertiary') themeColorTextTertiary: string = '#858792';
  @StorageProp('themeColorAccent') themeColorAccent: string = '#B9C6FF';
  @StorageProp('themeColorSurfacePrimary') themeColorSurfacePrimary: string = '#17181E';
  @StorageProp('themeColorSurfaceElevated') themeColorSurfaceElevated: string = '#23242C';

  @State currentGroupName: string = '';
  @State isSearchMode: boolean = false;
  @State searchKey: string = '';
  @State selectionMode: boolean = false;
  /** 键用 bookUrl + id；book.id 是文件名派生的，同名异目录会撞键。 */
  @State selectedBookKeys: Set<string> = new Set<string>();
  @State showDeleteConfirm: boolean = false;
  @State deleteOriginalFile: boolean = false;
  @State pendingDeleteKeys: string[] = [];
  @State showExportSheet: boolean = false;
  @State showExportSettings: boolean = false;
  @State exportBooks: Book[] = [];
  @State exportMsgByKey: Map<string, string> = new Map<string, string>();
  @State exportCharset: string = 'UTF-8';
  @State exportCustomCharset: string = '';
  @State exportFileNameTemplate: string = '{title}';
  @State exportWithChapterName: boolean = true;
  @State showGroupSelect: boolean = false;
  @State groupSelectBookKeys: string[] = [];
  @State preselectedGroupName: string = '';
  @State rowMenuKey: string = '';

  private listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.currentGroupName = this.initialGroupName;
  }

  /** 书目的主键路径，与 deleteBook / setBooksGroup 同口径（contentPath 优先）。 */
  private bookKey(book: Book): string {
    return LocalBookRestorePlanner.bookUrlOf(book);
  }

  /**
   * 复合键：缺正文备份书的 bookUrl 可能是空串，拼上 id 才不重复；
   * 再拼分组名与私密标记，否则移组 / 改私密后 key 不变，ForEach 会复用旧卡片、
   * 第三行分组文案不刷新（批6 bookCardKey 缺 isPrivate 同款坑）。
   */
  private rowKey(book: Book): string {
    return this.bookKey(book) + '_' + book.id + '_' + (book.groupNames ?? []).join('、')
      + '_' + (book.isPrivate === true ? '1' : '0');
  }

  private pageTitle(): string {
    return this.currentGroupName.length > 0 && this.currentGroupName !== '全部'
      ? this.currentGroupName : '离线缓存';
  }

  private groupOptions(): string[] {
    const names: string[] = ['全部'];
    this.groups.forEach((group: BookGroup) => {
      if (group.groupId > 0 && group.groupName.length > 0 && !names.includes(group.groupName)) {
        names.push(group.groupName);
      }
    });
    return names;
  }

  private moveGroupOptions(): string[] {
    const names: string[] = ['无分组'];
    this.groups.forEach((group: BookGroup) => {
      if (group.groupId > 0 && group.groupName.length > 0 && !names.includes(group.groupName)) {
        names.push(group.groupName);
      }
    });
    return names;
  }

  private effectiveGroup(): string {
    return this.currentGroupName.length > 0 ? this.currentGroupName : '全部';
  }

  /**
   * 当前分组 + 搜索关键字过滤。与上游 BookCacheManageScreen 的位与分组判定不同：
   * 本地 Book 只有 groupNames 名字数组，没有 group 位掩码，所以用 includes。
   * 搜索只比书名与作者，大小写不敏感。
   */
  private filteredBooks(): Book[] {
    const keyword = this.searchKey.trim().toLowerCase();
    return this.books.filter((book: Book) => {
      let matchesGroup = this.effectiveGroup() === '全部';
      if (!matchesGroup) {
        matchesGroup = (book.groupNames ?? []).includes(this.currentGroupName);
      }
      const matchesSearch = keyword.length === 0 ||
        book.title.toLowerCase().includes(keyword) ||
        book.author.toLowerCase().includes(keyword);
      return matchesGroup && matchesSearch;
    });
  }

  private isSelected(book: Book): boolean {
    return this.selectedBookKeys.has(this.rowKey(book));
  }

  private toggleBookSelection(book: Book): void {
    const key = this.rowKey(book);
    const next = new Set<string>(this.selectedBookKeys);
    if (next.has(key)) { next.delete(key); } else { next.add(key); }
    this.selectedBookKeys = next;
    if (next.size === 0) { this.selectionMode = false; }
  }

  /** 全选只作用当前列表可见的书，不是全库（上游 SelectVisibleBooks 同义）。 */
  private selectAllVisible(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.filteredBooks().forEach((book: Book) => next.add(this.rowKey(book)));
    this.selectedBookKeys = next;
  }

  private invertVisibleSelection(): void {
    const next = new Set<string>(this.selectedBookKeys);
    this.filteredBooks().forEach((book: Book) => {
      const key = this.rowKey(book);
      if (next.has(key)) { next.delete(key); } else { next.add(key); }
    });
    this.selectedBookKeys = next;
    if (next.size === 0) { this.selectionMode = false; }
  }

  private clearSelection(): void {
    this.selectedBookKeys = new Set<string>();
    this.selectionMode = false;
    this.rowMenuKey = '';
  }

  private selectedBooks(): Book[] {
    return this.books.filter((book: Book) => this.isSelected(book));
  }

  /** 跨分组多选时把不在当前列表的本数写出来（上游 selectionTitle 同义）。 */
  private selectionTitle(): string {
    const total = this.selectedBookKeys.size;
    const inView = this.filteredBooks().filter((book: Book) => this.isSelected(book)).length;
    const outOfView = total - inView;
    if (outOfView > 0) {
      return `已选 ${total} 本（${outOfView} 本不在当前列表）`;
    }
    return `已选 ${total}/${this.filteredBooks().length}`;
  }

  private groupLabelOf(book: Book): string {
    const names = book.groupNames ?? [];
    return names.length > 0 ? names.join('、') : '无分组';
  }

  private sourceFileLabelOf(book: Book): string {
    const path = book.androidOriginalPath ?? '';
    if (path.length === 0) { return '本地文件'; }
    const parts = path.split('/');
    return parts[parts.length - 1];
  }

  /** 模板占位符 {title}/{author}/{index}；空模板回落 {title}。 */
  private exportFileName(book: Book, index: number): string {
    const template = this.exportFileNameTemplate.trim().length > 0
      ? this.exportFileNameTemplate.trim() : '{title}';
    const name = template
      .replace(/\{title\}/g, book.title)
      .replace(/\{author\}/g, book.author.length > 0 ? book.author : '未知作者')
      .replace(/\{index\}/g, String(index + 1));
    const safe = name.replace(/[\/\\:*?"<>|]/g, '_');
    return safe.endsWith('.txt') ? safe : safe + '.txt';
  }

  private exportCharsetValue(): string {
    return this.exportCustomCharset.trim().length > 0 ? this.exportCustomCharset.trim() : this.exportCharset;
  }

  /**
   * 按指定字符集导出文本。utf-8 走字符串直写（全仓既有写法）；
   * 其它字符集用 TextEncoder 编成 ArrayBuffer 再写：SDK 的 writeSync 收
   * ArrayBuffer | string，直接把 Uint8Array 传进去在模拟器上会报 13900020（EINVAL）。
   * 当前 SDK 不支持的字符集编码失败时回落字符串直写，避免整批导出中断。
   */
  private async saveExportText(context: Context, fileName: string, content: string,
                               charset: string): Promise<boolean> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [fileName];
    options.fileSuffixChoices = ['TXT 文本|.txt'];
    const uris = await new picker.DocumentViewPicker(context).save(options);
    const uri = uris[0];
    if (uri === undefined) { return false; }
    const target = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
    try {
      const normalized = charset.trim().toLowerCase();
      if (normalized.length === 0 || normalized === 'utf-8' || normalized === 'utf8') {
        fileIo.writeSync(target.fd, content);
      } else {
        let buffer: ArrayBuffer | undefined = undefined;
        try {
          const encoded: Uint8Array = util.TextEncoder.create(charset.trim()).encodeInto(content);
          buffer = encoded.buffer as ArrayBuffer;
        } catch (error) {
          buffer = undefined;
        }
        if (buffer !== undefined) { fileIo.writeSync(target.fd, buffer); }
        else { fileIo.writeSync(target.fd, content); }
      }
    } finally {
      fileIo.closeSync(target);
    }
    return true;
  }

  /** Map 原地 set 不触发 @State 刷新，一律整体替换。 */
  private putExportMsg(key: string, text: string): void {
    const next = new Map<string, string>(this.exportMsgByKey);
    next.set(key, text);
    this.exportMsgByKey = next;
  }

  private exportMsgOf(book: Book): string {
    return this.exportMsgByKey.get(this.rowKey(book)) ?? '';
  }

  private openExportSheet(books: Book[]): void {
    if (books.length === 0) { this.onUnavailableAction('当前没有可导出的书籍'); return; }
    this.exportBooks = books;
    this.exportMsgByKey = new Map<string, string>();
    this.showExportSettings = false;
    this.showExportSheet = true;
  }

  private async runExport(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地文件'); return; }
    this.showExportSheet = false;
    const total = this.exportBooks.length;
    for (let i = 0; i < total; i++) {
      const book = this.exportBooks[i];
      if (book === undefined) { continue; }
      const key = this.rowKey(book);
      this.putExportMsg(key, `第 ${i + 1} / 共 ${total} 本，正在选择保存位置…`);
      const body = BookRepository.readBookContentForPreview(book);
      if (body.length === 0) {
        this.putExportMsg(key, '没有可导出的纯文本正文');
        continue;
      }
      // 上游「导出包含章节名」控制是否插章节标题行；本地整本导出时章节名本就在正文里，
      // 这个开关只额外加一行书名/作者抬头（:468）。
      const header = this.exportWithChapterName ? `${book.title}\n${book.author}\n\n` : '';
      let message = '已导出';
      try {
        const saved = await this.saveExportText(context, this.exportFileName(book, i),
          header + body, this.exportCharsetValue());
        if (!saved) { message = '已取消'; }
      } catch (error) {
        message = '导出失败';
      }
      this.putExportMsg(key, message);
    }
  }

  /** 每次打开删除框都从「未勾选」起步，不沿用上一次。 */
  private requestDelete(keys: string[]): void {
    if (keys.length === 0) { return; }
    this.pendingDeleteKeys = keys;
    this.deleteOriginalFile = false;
    this.showDeleteConfirm = true;
  }

  /** 勾选框只在待删集合里有本地书时出现；本地书 isLocal 恒真。 */
  private hasLocalBookIn(keys: string[]): boolean {
    return this.books.some((book: Book) => keys.includes(this.rowKey(book)) && book.isLocal);
  }

  private async confirmDelete(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地书架'); return; }
    const targets = this.books.filter((book: Book) => this.pendingDeleteKeys.includes(this.rowKey(book)));
    this.showDeleteConfirm = false;
    if (targets.length === 0) { this.clearSelection(); return; }
    try {
      // 复用批5 的 deleteBooks：逐本 deleteBook（清章节表与书目）+ 可选清应用内导入副本。
      // 它是窄 DELETE，不会把刚删的书又 upsert 回去，因此这里不需要再 saveImportedBooks。
      await BookRepository.deleteBooks(context, targets, this.deleteOriginalFile);
      await this.onLibraryChanged();
      this.clearSelection();
      this.onUnavailableAction(`已删除 ${targets.length} 本书`);
    } catch (error) {
      this.onUnavailableAction('删除失败，请重试');
    }
    this.pendingDeleteKeys = [];
  }

  private openGroupSelect(keys: string[]): void {
    if (keys.length === 0) { return; }
    this.groupSelectBookKeys = keys;
    // 所有选中书的 groupNames 排序后 join 完全一致才预选那个分组名，否则不预选。
    const selected = this.books.filter((book: Book) => keys.includes(this.rowKey(book)));
    let common = '';
    if (selected.length > 0) {
      const first = [...(selected[0].groupNames ?? [])].sort().join('、');
      const same = selected.every((book: Book) =>
        [...(book.groupNames ?? [])].sort().join('、') === first);
      common = same ? first : '';
    }
    this.preselectedGroupName = common;
    this.showGroupSelect = true;
  }

  private async applyGroup(groupName: string): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (context === undefined) { this.onUnavailableAction('无法访问本地书架'); return; }
    this.showGroupSelect = false;
    const keys = this.groupSelectBookKeys;
    const targets = this.books.filter((book: Book) => keys.includes(this.rowKey(book)));
    if (targets.length === 0) { return; }
    try {
      // group 列是位掩码；setBooksGroup 内部用 maskFromNames（加法，不用 32 位会被截断的位或）。
      await BookRepository.setBooksGroup(context, targets.map((book: Book) => this.bookKey(book)), groupName);
      await this.onLibraryChanged();
      this.clearSelection();
      this.onUnavailableAction(groupName.length > 0 ? `已移入「${groupName}」` : '已移出分组');
    } catch (error) {
      this.onUnavailableAction('修改分组失败');
    }
  }

  // ---------------------------------------------------------------- 菜单

  @Builder
  private GroupFilterMenu() {
    Menu() {
      ForEach(this.groupOptions(), (name: string) => {
        MenuItem({ content: name === this.effectiveGroup() ? `✓ ${name}` : name }).height(44)
          .onClick(() => this.currentGroupName = name)
      }, (name: string) => name)
    }.backgroundColor('#17181E').fontColor('#F1F2F6').radius(20)
  }

  /** 顶栏「更多」本批只放「导出全部」；下载全部(:450)与日志(:452)不做，菜单里不放占位项。 */
  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ content: '导出全部' }).height(44)
        .onClick(() => this.openExportSheet(this.filteredBooks()))
    }.backgroundColor('#17181E').fontColor('#F1F2F6').radius(20)
  }

  @Builder
  private SelectionMenu() {
    Menu() {
      MenuItem({ content: '全选' }).height(44).onClick(() => this.selectAllVisible())
      MenuItem({ content: '反选' }).height(44).onClick(() => this.invertVisibleSelection())
      MenuItem({ content: '移入分组' }).height(44).onClick(() => {
        const keys = this.selectedBooks().map((book: Book) => this.rowKey(book));
        this.openGroupSelect(keys);
      })
    }.backgroundColor('#17181E').fontColor('#F1F2F6').radius(20)
  }

  @Builder
  private ExportCharsetMenu() {
    Menu() {
      ForEach(['UTF-8', 'GBK', 'GB2312', 'GB18030', 'Big5', 'UTF-16'], (charset: string) => {
        MenuItem({ content: charset === this.exportCharset ? `✓ ${charset}` : charset }).height(44)
          .onClick(() => this.exportCharset = charset)
      }, (charset: string) => charset)
    }.backgroundColor('#17181E').fontColor('#F1F2F6').radius(20)
  }

  // ---------------------------------------------------------------- 书籍行

  @Builder
  private BookRow(book: Book) {
    Column() {
      Row() {
        Column() {
          Text(book.title).fontSize(15).fontColor(this.themeColorTextPrimary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => this.onOpenBookInfo(book))
          Text(book.author.length > 0 ? book.author : '作者未知').fontSize(12)
            .fontColor(this.themeColorTextSecondary).margin({ top: 2 }).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.groupLabelOf(book)} · ${this.sourceFileLabelOf(book)}`).fontSize(11)
            .fontColor(this.themeColorAccent).margin({ top: 2 }).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.exportMsgOf(book).length > 0) {
            Text(this.exportMsgOf(book)).fontSize(11).fontColor(this.themeColorTextTertiary)
              .margin({ top: 2 }).maxLines(1)
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text('本地书').fontSize(11).fontColor('#B9C6FF')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 }).borderRadius(8)
          .backgroundColor(this.themeColorSurfaceElevated)
        if (this.selectionMode) {
          Stack({ alignContent: Alignment.Center }) {
            Column().width(18).height(18).borderRadius(9)
              .backgroundColor(this.isSelected(book) ? '#C4D1FF' : '#00000000')
              .border({ width: 1.5, color: this.isSelected(book) ? '#C4D1FF' : '#7A7D88' })
            if (this.isSelected(book)) {
              AppGlyph({ name: 'profileCheck', glyphSize: 12, tint: '#1A1B21' })
            }
          }.width(26).height(26).margin({ left: 8 })
        }
      }.width('100%')
      // 行内三个等宽按钮：去掉上游的「下载/停止」(:454 判不接)。
      Row() {
        Text('导出').fontSize(11).fontColor(this.themeColorAccent).layoutWeight(1).height(30)
          .textAlign(TextAlign.Center).onClick(() => this.openExportSheet([book]))
        Text('分组').fontSize(11).fontColor(this.themeColorAccent).layoutWeight(1).height(30)
          .textAlign(TextAlign.Center).onClick(() => this.openGroupSelect([this.rowKey(book)]))
        Text('更多').fontSize(11).fontColor(this.themeColorAccent).layoutWeight(1).height(30)
          .textAlign(TextAlign.Center)
          .onClick(() => this.rowMenuKey = this.rowMenuKey === this.rowKey(book) ? '' : this.rowKey(book))
      }.width('100%').margin({ top: 6 })
      // 「更多」展开的小菜单：本批只放「删除书籍」一项（换源归批13、清缓存判不接）。
      if (this.rowMenuKey === this.rowKey(book)) {
        Row() {
          Text('删除书籍').fontSize(12).fontColor('#FF6B6B').padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => {
              this.rowMenuKey = '';
              this.requestDelete([this.rowKey(book)]);
            })
          Text('取消').fontSize(12).fontColor(this.themeColorTextSecondary)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .onClick(() => this.rowMenuKey = '')
        }.width('100%').justifyContent(FlexAlign.End)
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor(this.isSelected(book) ? '#2A2D3A' : this.themeColorSurfacePrimary)
    // 长按与短按必须互斥：onClick 与 gesture 并存时长按会顺带触发点击，
    // 表现是刚进选择模式就被又 toggle 一次、选中立刻消失（批7 封面同款坑）。
    .gesture(GestureGroup(GestureMode.Exclusive,
      LongPressGesture({ duration: 500 }).onAction(() => {
        this.selectionMode = true;
        this.toggleBookSelection(book);
      }),
      TapGesture({ count: 1 }).onAction(() => {
        if (this.selectionMode) { this.toggleBookSelection(book); }
      })
    ))
  }

  // ---------------------------------------------------------------- 三个 sheet

  @Builder
  private DeleteConfirmContent() {
    Column() {
      Text('删除书籍').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 8 })
      Text(`已选 ${this.pendingDeleteKeys.length} 本。删除后应用内副本会被清理，Android 兼容归档不会更改。`)
        .fontSize(14).lineHeight(21).fontColor('#AEB0BA').width('100%')
      if (this.hasLocalBookIn(this.pendingDeleteKeys)) {
        Row() {
          Toggle({ type: ToggleType.Checkbox, isOn: this.deleteOriginalFile })
            .onChange((value: boolean) => this.deleteOriginalFile = value)
          Text('删除源文件（应用内导入副本）').fontSize(14).fontColor('#D0D2DB').margin({ left: 8 })
        }.width('100%').margin({ top: 12 })
      }
      Row() {
        Text('取消').fontSize(15).fontColor('#C5C7D0').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
          .onClick(() => this.showDeleteConfirm = false)
        Text('删除').fontSize(15).fontColor('#101116').textAlign(TextAlign.Center)
          .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
          .margin({ left: 10 }).onClick(async () => { await this.confirmDelete(); })
      }.width('100%').margin({ top: 20 })
    }.width('100%')
  }

  @Builder
  private ExportSettingsContent() {
    Column() {
      Row() {
        Text('导出格式').fontSize(14).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text('TXT（EPUB 打包器未接入）').fontSize(12).fontColor(this.themeColorTextTertiary)
      }.width('100%').padding({ top: 8, bottom: 8 })
      Row() {
        Text('导出字符集').fontSize(14).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Text(this.exportCharset).fontSize(13).fontColor(this.themeColorAccent)
          .bindMenu(this.ExportCharsetMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ top: 8, bottom: 8 })
      Row() {
        Text('自定义字符集').fontSize(14).fontColor(this.themeColorTextPrimary).width(110)
        TextInput({ text: this.exportCustomCharset, placeholder: '留空用上面选的字符集' })
          .layoutWeight(1).height(36).fontSize(13)
          .onChange((value: string) => this.exportCustomCharset = value)
      }.width('100%').padding({ top: 8, bottom: 8 })
      Row() {
        Text('导出文件名').fontSize(14).fontColor(this.themeColorTextPrimary).width(110)
        TextInput({ text: this.exportFileNameTemplate, placeholder: '{title}' })
          .layoutWeight(1).height(36).fontSize(13)
          .onChange((value: string) => this.exportFileNameTemplate = value)
      }.width('100%').padding({ top: 8, bottom: 8 })
      Text('占位符：{title} {author} {index}，空模板回落 {title}')
        .fontSize(11).fontColor(this.themeColorTextTertiary).width('100%')
      Row() {
        Text('导出包含章节名').fontSize(14).fontColor(this.themeColorTextPrimary).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.exportWithChapterName })
          .onChange((value: boolean) => this.exportWithChapterName = value)
      }.width('100%').padding({ top: 8, bottom: 8 })
    }.width('100%')
  }

  @Builder
  private ExportSheetContent() {
    Column() {
      Row() {
        Text(this.showExportSettings ? '导出设置' : '导出').fontSize(18)
          .fontWeight(FontWeight.Medium).fontColor('#ECEEF2').layoutWeight(1)
        Text(this.showExportSettings ? '返回' : '导出设置').fontSize(13).fontColor(this.themeColorAccent)
          .onClick(() => this.showExportSettings = !this.showExportSettings)
      }.width('100%')
      if (this.showExportSettings) {
        this.ExportSettingsContent()
      } else {
        Text(`本次导出（${this.exportBooks.length} 本）`).fontSize(13)
          .fontColor(this.themeColorTextSecondary).width('100%').margin({ top: 12 })
        ForEach(this.exportBooks, (book: Book) => {
          Text(book.title).fontSize(14).fontColor(this.themeColorTextPrimary).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%').padding({ top: 5, bottom: 5 })
        }, (book: Book) => this.rowKey(book))
        Row() {
          Text('取消').fontSize(15).fontColor('#C5C7D0').textAlign(TextAlign.Center)
            .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
            .onClick(() => this.showExportSheet = false)
          Text('导出').fontSize(15).fontColor('#101116').textAlign(TextAlign.Center)
            .layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor('#B9C6FF').borderRadius(14)
            .margin({ left: 10 }).onClick(async () => { await this.runExport(); })
        }.width('100%').margin({ top: 20 })
      }
    }.width('100%')
  }

  @Builder
  private GroupSelectContent() {
    Column() {
      Text('移入分组').fontSize(18).fontWeight(FontWeight.Medium).fontColor('#ECEEF2')
        .width('100%').margin({ bottom: 8 })
      if (this.preselectedGroupName.length > 0) {
        Text(`当前预选：${this.preselectedGroupName}`).fontSize(12)
          .fontColor(this.themeColorTextTertiary).width('100%')
      }
      ForEach(this.moveGroupOptions(), (name: string) => {
        Row() {
          Text(name).fontSize(14).fontColor(this.themeColorTextPrimary).layoutWeight(1)
          if (name === (this.preselectedGroupName.length > 0 ? this.preselectedGroupName : '无分组')) {
            AppGlyph({ name: 'profileCheck', glyphSize: 16, tint: this.themeColorAccent })
          }
        }.width('100%').padding({ top: 10, bottom: 10 })
          .onClick(() => this.applyGroup(name === '无分组' ? '' : name))
      }, (name: string) => name)
      Text('取消').fontSize(15).fontColor('#C5C7D0').textAlign(TextAlign.Center)
        .width('100%').padding({ top: 12, bottom: 12 }).backgroundColor('#2A2B33').borderRadius(14)
        .margin({ top: 12 }).onClick(() => this.showGroupSelect = false)
    }.width('100%')
  }

  /** 同一组件只挂一个 bindSheet，按状态分发内容（批3 同款，避免多个 bindSheet 只有最后生效）。 */
  @Builder
  private ManageSheet() {
    Column() {
      if (this.showDeleteConfirm) {
        this.DeleteConfirmContent()
      } else if (this.showExportSheet) {
        this.ExportSheetContent()
      } else if (this.showGroupSelect) {
        this.GroupSelectContent()
      }
    }.width('100%').padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(14).fontColor(this.themeColorAccent)
          .onClick(() => this.onBack())
        Text(this.pageTitle()).fontSize(18).fontWeight(FontWeight.Medium)
          .fontColor(this.themeColorTextPrimary).margin({ left: 12 }).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        AppGlyph({ name: 'search', glyphSize: 20, tint: this.themeColorTextPrimary })
          .width(40).height(40).onClick(() => this.isSearchMode = !this.isSearchMode)
          .accessibilityText('搜索')
        AppGlyph({ name: 'profileFilterAlt', glyphSize: 20, tint: this.themeColorTextPrimary })
          .width(40).height(40).onClick(() => {})
          .bindMenu(this.GroupFilterMenu, { placement: Placement.BottomRight })
          .accessibilityText('分组筛选')
        AppGlyph({ name: 'more', glyphSize: 20, tint: this.themeColorTextPrimary })
          .width(40).height(40).onClick(() => {})
          .bindMenu(this.MoreMenu, { placement: Placement.BottomRight })
      }.width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 })
      if (this.isSearchMode) {
        Row() {
          TextInput({ text: this.searchKey, placeholder: '筛选书名/作者' })
            .layoutWeight(1).height(40).fontSize(14)
            .onChange((value: string) => this.searchKey = value)
          Text('清除').fontSize(12).fontColor(this.themeColorAccent)
            .onClick(() => this.searchKey = '')
        }.width('100%').padding({ left: 16, right: 16 })
      }
      Scroll(this.listScroller) {
        Column() {
          ForEach(this.filteredBooks(), (book: Book) => {
            this.BookRow(book)
          }, (book: Book) => this.rowKey(book))
          if (this.filteredBooks().length === 0) {
            Text('没有符合条件的书籍').fontSize(14).fontColor(this.themeColorTextSecondary)
              .width('100%').textAlign(TextAlign.Center).margin({ top: 60 })
          }
        }.width('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
      if (this.selectionMode) {
        Row() {
          Text(this.selectionTitle()).fontSize(12).fontColor('#DCDDE4').layoutWeight(1)
          Text('操作').fontSize(12).fontColor('#C4D1FF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(8)
            .backgroundColor(this.themeColorSurfaceElevated)
            .bindMenu(this.SelectionMenu, { placement: Placement.BottomRight })
          Text('完成').fontSize(12).fontColor('#C4D1FF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(8)
            .backgroundColor(this.themeColorSurfaceElevated)
            .onClick(() => this.clearSelection())
        }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
    }.width('100%').height('100%').backgroundColor(this.themeColorSurfacePrimary)
      .bindSheet(this.showDeleteConfirm || this.showExportSheet || this.showGroupSelect,
        this.ManageSheet(), {
          height: SheetSize.FIT_CONTENT, dragBar: true, showClose: false, backgroundColor: '#17181E',
          onDisappear: () => {
            this.showDeleteConfirm = false;
            this.showExportSheet = false;
            this.showGroupSelect = false;
          }
        })
  }
}
