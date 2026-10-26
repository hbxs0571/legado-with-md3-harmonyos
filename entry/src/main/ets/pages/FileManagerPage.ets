import { fileIo } from '@kit.CoreFileKit';
import { AppGlyph, AppGlyphName } from '../components/AppGlyph';
import { Book } from '../model/Book';

interface ManagedFileEntry {
  name: string;
  path: string;
  isDirectory: boolean;
  size: number;
}

interface FileBreadcrumb {
  title: string;
  path: string;
}

@Component
export struct FileManagerPage {
  @Prop rootPath: string = '';
  @Prop books: Book[] = [];
  onBack: () => void = () => {};
  onOpenBook: (book: Book) => void = (_book: Book) => {};
  onUnavailableAction: (message: string) => void = (_message: string) => {};
  @State currentPath: string = '';
  @State entries: ManagedFileEntry[] = [];
  @State showSearch: boolean = false;
  @State searchQuery: string = '';
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    if (this.rootPath.length === 0) {
      this.onUnavailableAction('应用文件目录暂不可用');
      return;
    }
    this.currentPath = this.rootPath;
    this.loadDirectory(this.rootPath);
  }

  private async loadDirectory(path: string): Promise<void> {
    this.isLoading = true;
    try {
      const names = await fileIo.listFile(path);
      const loaded: ManagedFileEntry[] = [];
      for (let index = 0; index < names.length; index++) {
        const name = names[index];
        if (name === undefined || name === '.' || name === '..') { continue; }
        const fullPath = `${path}/${name}`;
        const stat = await fileIo.lstat(fullPath);
        if (stat.isSymbolicLink()) { continue; }
        loaded.push({ name: name, path: fullPath, isDirectory: stat.isDirectory(), size: stat.size });
      }
      loaded.sort((left: ManagedFileEntry, right: ManagedFileEntry) => {
        if (left.isDirectory !== right.isDirectory) { return left.isDirectory ? -1 : 1; }
        return left.name.localeCompare(right.name);
      });
      this.currentPath = path;
      this.entries = loaded;
    } catch (_error) {
      this.entries = [];
      this.onUnavailableAction('读取应用文件目录失败');
    } finally {
      this.isLoading = false;
    }
  }

  private getVisibleEntries(): ManagedFileEntry[] {
    const query = this.searchQuery.trim().toLocaleLowerCase();
    const rootEntries = this.currentPath === this.rootPath
      ? this.entries.filter((entry: ManagedFileEntry) => entry.name === 'cache' || entry.name === 'files')
      : this.entries;
    if (query.length === 0) { return rootEntries; }
    return rootEntries.filter((entry: ManagedFileEntry) => entry.name.toLocaleLowerCase().includes(query));
  }

  private getBreadcrumbs(): FileBreadcrumb[] {
    const breadcrumbs: FileBreadcrumb[] = [{ title: 'root', path: this.rootPath }];
    const relative = this.currentPath.substring(this.rootPath.length).split('/').filter((part: string) => part.length > 0);
    let path = this.rootPath;
    for (let index = 0; index < relative.length; index++) {
      const part = relative[index];
      if (part === undefined) { continue; }
      path = `${path}/${part}`;
      breadcrumbs.push({ title: part, path: path });
    }
    return breadcrumbs;
  }

  private openParent(): void {
    if (this.currentPath === this.rootPath) {
      this.onBack();
      return;
    }
    const parentEnd = this.currentPath.lastIndexOf('/');
    const parentPath = parentEnd < this.rootPath.length ? this.rootPath : this.currentPath.substring(0, parentEnd);
    this.loadDirectory(parentPath);
  }

  private findImportedBook(entry: ManagedFileEntry): Book | undefined {
    const fileName = entry.name.toLocaleLowerCase();
    const fileId = fileName.endsWith('.txt') ? entry.name.substring(0, entry.name.length - 4) : '';
    return this.books.find((book: Book) => book.contentPath === entry.path || (fileId.length > 0 && book.id === fileId));
  }

  private getDisplayName(entry: ManagedFileEntry): string {
    return this.findImportedBook(entry)?.title ?? entry.name;
  }

  private selectEntry(entry: ManagedFileEntry): void {
    if (entry.isDirectory) {
      this.searchQuery = '';
      this.loadDirectory(entry.path);
      return;
    }
    const matchingBook = this.findImportedBook(entry);
    if (matchingBook !== undefined) {
      this.onOpenBook(matchingBook);
      return;
    }
    this.onUnavailableAction('该文件尚未导入为可阅读书籍');
  }

  private formatSize(size: number): string {
    if (size >= 1024 * 1024) { return `${(size / (1024 * 1024)).toFixed(1)} MB`; }
    if (size >= 1024) { return `${(size / 1024).toFixed(1)} KB`; }
    return `${size} B`;
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          Image($r('app.media.reader_back')).width(20).height(20).fillColor('#D8D9E0')
        }.width(40).height(40).onClick(() => this.openParent())
        Text('筛选 • 文件管理').fontSize(16).fontColor('#D8D9E0').layoutWeight(1).margin({ left: 8 })
        Stack({ alignContent: Alignment.Center }) {
          Row().width(32).height(32).backgroundColor('#1B1C22').borderRadius(16)
          AppGlyph({ name: 'search', glyphSize: 20, tint: '#D8D9E0' })
        }.width(40).height(40).onClick(() => {
          this.showSearch = !this.showSearch;
          if (!this.showSearch) { this.searchQuery = ''; }
        })
      }.width('100%').height(48).padding({ left: 11, right: 12 })

      if (this.showSearch) {
        Row() {
          AppGlyph({ name: 'search', glyphSize: 16, tint: '#C5C7D0' }).margin({ right: 8 })
          TextInput({ placeholder: '筛选 • 文件管理', text: this.searchQuery })
            .fontSize(14).fontColor('#D8D9E0').placeholderColor('#92949E')
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .id('my_file_manager_search')
            .onAppear(() => focusControl.requestFocus('my_file_manager_search'))
            .onChange((value: string) => this.searchQuery = value)
        }.width('calc(100% - 32vp)').height(48).padding({ left: 14, right: 14 })
          .margin({ left: 16, right: 16, top: 4, bottom: 4 }).backgroundColor('#1B1C22').borderRadius(24)
      }

      Scroll() {
        Column() {
          Scroll() {
            Row() {
              ForEach(this.getBreadcrumbs(), (crumb: FileBreadcrumb, index: number) => {
                Row() {
                  Text(crumb.title).fontSize(13).fontColor(index === this.getBreadcrumbs().length - 1 ? '#E3E4E8' : '#AFC2FF')
                    .onClick(() => { this.searchQuery = ''; this.loadDirectory(crumb.path); })
                  Image($r('app.media.file_picker_arrow')).width(16).height(16)
                    .margin({ left: 5, right: 5 })
                }
              })
            }.height(24).padding({ left: 10, right: 10 })
          }.height(24).scrollBar(BarState.Off)

          if (this.isLoading) {
            FileManagerEmpty({ icon: 'folder', title: '正在读取目录', detail: '' }).layoutWeight(1)
          } else if (this.getVisibleEntries().length === 0) {
            Text(this.searchQuery.length > 0 ? '没有匹配的文件' : '内容为空')
              .fontSize(14).fontColor('#92949E').textAlign(TextAlign.Center).width('100%')
              .layoutWeight(1).alignSelf(ItemAlign.Center).padding(16)
          } else {
            Column() {
              if (this.currentPath !== this.rootPath) {
                ManagedFileRow({ name: '..', detail: '上一级目录', icon: 'updir', onSelect: () => this.openParent(), onLongSelect: () => {} })
              }
              ForEach(this.getVisibleEntries(), (entry: ManagedFileEntry) => {
                ManagedFileRow({
                  name: this.getDisplayName(entry),
                  detail: entry.isDirectory ? '文件夹' : this.formatSize(entry.size),
                  icon: this.getIcon(entry),
                  onSelect: () => this.selectEntry(entry),
                  onLongSelect: (): void => { this.onUnavailableAction('文件删除尚未迁移'); }
                })
              }, (entry: ManagedFileEntry) => entry.path)
            }.width('100%').padding({ left: 16, right: 16, bottom: 20 })
          }
        }.width('100%').height('100%')
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#111217')
  }

  private getIcon(entry: ManagedFileEntry): 'folder' | 'file' {
    return entry.isDirectory ? 'folder' : 'file';
  }
}

@Component
struct FileManagerEmpty {
  @Prop icon: AppGlyphName = 'folder';
  @Prop title: string = '';
  @Prop detail: string = '';
  build() {
    Column() {
      AppGlyph({ name: this.icon, glyphSize: 34, tint: '#AFC2FF' }).margin({ bottom: 14 })
      Text(this.title).fontSize(15).fontColor('#D8D9E0')
      Text(this.detail).fontSize(12).fontColor('#858792').textAlign(TextAlign.Center)
        .margin({ left: 34, right: 34, top: 8 })
    }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}
@Component
struct ManagedFileRow {
  @Prop name: string = '';
  @Prop detail: string = '';
  @Prop icon: 'folder' | 'file' | 'updir' = 'folder';
  onSelect: () => void = () => {};
  onLongSelect: () => void = () => {};
  build() {
    Row() {
      if (this.icon === 'folder') {
        Image($r('app.media.file_picker_folder')).width(24).height(24)
      } else if (this.icon === 'updir') {
        Image($r('app.media.file_picker_updir')).width(24).height(24)
      } else {
        Image($r('app.media.file_picker_file')).width(24).height(24)
      }
      Text(this.name).fontSize(16).fontColor('#D8D9E0').maxLines(1).layoutWeight(1).margin({ left: 8 })
    }.width('100%').height(42).padding({ left: 8, right: 8 })
      .border({ width: { bottom: 1 }, color: '#26272D' })
      .priorityGesture(LongPressGesture({ duration: 500 }).onAction((_event: GestureEvent): void => { this.onLongSelect(); }))
      .onClick(() => this.onSelect())
  }
}
