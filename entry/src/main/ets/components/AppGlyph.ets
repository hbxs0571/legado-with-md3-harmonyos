export type AppGlyphName = 'home' | 'bookshelf' | 'discover' | 'subscription' | 'profile' | 'search' | 'searchPrecisionOn' | 'searchPrecisionOff' | 'more' | 'settings' | 'swap' | 'add' | 'goal' | 'book' | 'bookmark' | 'cloud' | 'cloudSync' | 'cloudUpload' | 'cloudDownload' | 'edit' | 'pencil' | 'delete' | 'share' | 'star' | 'ruleSubscription' | 'favoriteStar' | 'navHomeFilled' | 'navHomeOutlined' | 'navBookshelfFilled' | 'navBookshelfOutlined' | 'navExploreFilled' | 'navExploreOutlined' | 'navRss' | 'navProfileFilled' | 'navProfileOutlined' | 'profileWeb' | 'profileSource' | 'profileFindReplace' | 'profileRule' | 'profileSell' | 'profileAutoAwesome' | 'profileSettings' | 'profileBookmark' | 'profileHistory' | 'profileDownload' | 'profileFolder' | 'profileInfo' | 'profileExitToApp' | 'profileClose' | 'profileNoteAdd' | 'profileContentPaste' | 'profileRunningWithErrors' | 'profileSave' | 'profileCheck' | 'lock' | 'profileExpandMore' | 'profileTimeline' | 'profileFilterAlt' | 'profileRefresh' | 'selectAll' | 'clock' | 'accessTime' | 'chart' | 'folder' | 'tag' | 'list' | 'download' | 'info' | 'sparkles' | 'logout' | 'web' | 'locate' | 'arrowForward' | 'wifi' | 'grid' | 'carousel' | 'link' | 'uploadFile' | 'shuffle' | 'group' | 'brightness_medium' | 'light_mode' | 'dark_mode' | 'visibility' | 'visibilityOff' | 'bugReport' | 'clearAll' | 'deleteSweep' | 'playArrow' | 'stop' | 'replay' | 'unfoldMore';

@Component
export struct AppGlyph {
  @Prop name: AppGlyphName = 'home';
  @Prop glyphSize: number = 22;
  // 类型放宽到 ResourceColor：调用方既能传字面量，也能传 $r('app.color.*')，
  // 后者才会随 resources/dark 目录切换深浅色。
  @Prop tint: ResourceColor = '#C5C7D0';

  build() {
    if (this.name === 'home') {
      Image($r('app.media.app_home')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'book') {
      Image($r('app.media.app_book')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'bookshelf') {
      Image($r('app.media.app_bookshelf')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'discover') {
      Image($r('app.media.app_discover')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'subscription') {
      Image($r('app.media.app_subscription')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profile') {
      Image($r('app.media.app_profile')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'search') {
      Image($r('app.media.app_search')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'searchPrecisionOn') {
      Image($r('app.media.search_precision_on')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'searchPrecisionOff') {
      Image($r('app.media.search_precision_off')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'more') {
      Image($r('app.media.app_more')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'settings') {
      Image($r('app.media.app_settings')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'swap') {
      Image($r('app.media.app_swap')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'add') {
      Image($r('app.media.app_add')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'goal') {
      Image($r('app.media.app_goal')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'bookmark') {
      Image($r('app.media.app_bookmark')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'cloud') {
      Image($r('app.media.app_cloud')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'cloudSync') {
      Image($r('app.media.app_cloud_sync')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'cloudUpload') {
      Image($r('app.media.app_cloud_upload')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'cloudDownload') {
      Image($r('app.media.app_cloud_download')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'edit') {
      Image($r('app.media.app_edit')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'pencil') {
      Image($r('app.media.app_pencil')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'share') {
      Image($r('app.media.app_share')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'delete') {
      Image($r('app.media.profile_delete')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'star') {
      Image($r('app.media.app_star')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'ruleSubscription') {
      Image($r('app.media.app_rule_subscription')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'favoriteStar') {
      Image($r('app.media.app_favorite_star')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navHomeFilled') {
      Image($r('app.media.nav_home_filled')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navHomeOutlined') {
      Image($r('app.media.nav_home_outlined')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navBookshelfFilled') {
      Image($r('app.media.nav_bookshelf_filled')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navBookshelfOutlined') {
      Image($r('app.media.nav_bookshelf_outlined')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navExploreFilled') {
      Image($r('app.media.nav_explore_filled')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navExploreOutlined') {
      Image($r('app.media.nav_explore_outlined')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navRss') {
      Image($r('app.media.nav_rss')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navProfileFilled') {
      Image($r('app.media.nav_profile_filled')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'navProfileOutlined') {
      Image($r('app.media.nav_profile_outlined')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileWeb') {
      Image($r('app.media.profile_web')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileSource') {
      Image($r('app.media.profile_source')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileFindReplace') {
      Image($r('app.media.profile_find_replace')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileRule') {
      Image($r('app.media.profile_rule')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileSell') {
      Image($r('app.media.profile_sell')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileAutoAwesome') {
      Image($r('app.media.profile_auto_awesome')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileSettings') {
      Image($r('app.media.profile_settings')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileBookmark') {
      Image($r('app.media.profile_bookmark')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileHistory') {
      Image($r('app.media.profile_history')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileDownload') {
      Image($r('app.media.profile_download')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileFolder') {
      Image($r('app.media.profile_folder')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileInfo') {
      Image($r('app.media.profile_info')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileExitToApp') {
      Image($r('app.media.profile_exit_to_app')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileClose') {
      Image($r('app.media.profile_close')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileNoteAdd') {
      Image($r('app.media.profile_note_add')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileContentPaste') {
      Image($r('app.media.profile_content_paste')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileRunningWithErrors') {
      Image($r('app.media.profile_running_with_errors')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileSave') {
      Image($r('app.media.profile_save')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileCheck') {
      Image($r('app.media.app_check')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'lock') {
      Image($r('app.media.app_lock')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileExpandMore') {
      Image($r('app.media.profile_expand_more')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileTimeline') {
      Image($r('app.media.profile_timeline')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileFilterAlt') {
      Image($r('app.media.profile_filter_alt')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileRefresh') {
      Image($r('app.media.profile_refresh')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'selectAll') {
      Image($r('app.media.app_select_all')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'clock') {
      Image($r('app.media.app_clock')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'accessTime') {
      Image($r('app.media.app_access_time')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'chart') {
      Image($r('app.media.app_chart')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'folder') {
      Image($r('app.media.app_folder')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'tag') {
      Image($r('app.media.app_tag')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'list') {
      Image($r('app.media.app_list')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'download') {
      Image($r('app.media.app_download')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'info') {
      Image($r('app.media.app_info')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'sparkles') {
      Image($r('app.media.app_sparkles')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'logout') {
      Image($r('app.media.app_logout')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'locate') {
      Image($r('app.media.app_locate')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'wifi') {
      // 上游 `Icons.Default.Wifi`（书架更多菜单「远程书籍」）。
      Image($r('app.media.menu_wifi')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'grid') {
      // 上游 `Icons.Default.GridView`（书架更多菜单「布局设置」）。
      Image($r('app.media.menu_grid')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'carousel') {
      // 上游 `Icons.Outlined.ViewCarousel`（书架更多菜单「分组管理」）。
      Image($r('app.media.menu_carousel')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'link') {
      // 上游 `Icons.Default.Link`（书架更多菜单「添加网址」）。
      Image($r('app.media.menu_link')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'uploadFile') {
      // 上游 `Icons.Default.UploadFile`（书架更多菜单「导出书单」）。改前与「添加本地」共用 profileSave，
      // 两行图标撞车，视觉上容易被当成重复行。
      Image($r('app.media.menu_upload_file')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'group') {
      Image($r('app.media.app_group')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'shuffle') {
      // 上游 `Icons.Default.Shuffle`：详情页书架卡在「疑似重复」时用它。
      Image($r('app.media.app_shuffle')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'brightness_medium') {
      // 上游 `Icons.Default.BrightnessMedium`：外观页「跟随系统」档。
      Image($r('app.media.app_brightness_medium')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'light_mode') {
      // 上游 `Icons.Default.LightMode`：外观页「浅色」档，复用已有的太阳图标。
      Image($r('app.media.reader_brightness')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'dark_mode') {
      // 上游 `Icons.Default.DarkMode`：外观页「深色」档，复用已有的月牙图标。
      Image($r('app.media.app_moon')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'arrowForward') {
      // 上游 `Icons.AutoMirrored.Filled.ArrowForward`（欢迎页按钮尾部箭头）。
      Image($r('app.media.reader_arrow_forward')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'visibility') {
      // 密码可见性切换的「明文」态（:381 WebDAV 账号密码面板），复用已有图标资源。
      Image($r('app.media.app_visibility')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'visibilityOff') {
      // 「打码」态。
      Image($r('app.media.reader_visibility_off')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'web') {
      // 上游 `Icons.Default.Web`（MyScreen.kt:268「网页」入口）：与 web 成员同名。
      Image($r('app.media.app_web')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'bugReport') {
      // 上游 `Icons.Default.BugReport`（编辑页「保存并调试」）：pathData 来自 ic_bug_report.xml。
      Image($r('app.media.app_bug_report')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'clearAll') {
      // 上游 `Icons.Default.ClearAll`（调试页「清空日志」）：pathData 来自 ic_clear_all.xml。
      Image($r('app.media.app_clear_all')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'deleteSweep') {
      // 上游 `Icons.Default.DeleteSweep`（日志弹层「清除」）：本地新增 app_delete_sweep.svg，
      // 路径取自 Material DeleteSweep（垃圾桶 + 三条递减横线），与上游语义一致。
      Image($r('app.media.app_delete_sweep')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'playArrow') {
      // 上游 `Icons.Default.PlayArrow`（BookSourceDebugScreen.kt:93「开始调试」）。
      // 不能复用 reader_play：那个是阅读器的「播放」图标，pathData 带镂空三角，与 Material
      // PlayArrow 的实心三角不同。本地 app_play_arrow.svg 的 path 由官方 pathData
      // `M8 5v14l11-7z`（viewBox 24）等比换算到 960 视口：M320,200 L320,760 L760,480 Z。
      Image($r('app.media.app_play_arrow')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'stop') {
      // 上游 `Icons.Default.Stop`（BookSourceDebugScreen.kt:93「停止」）。
      // app_stop_square.svg 的 pathData `M240,720L240,240L720,240L720,720L240,720Z` 与上游
      // ic_stop_black_24dp.xml 逐字节相同，直接复用即可。
      Image($r('app.media.app_stop_square')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'replay') {
      // 上游 `Icons.Default.Replay`（BookInfoEditScreen.kt:207 封面「还原封面」、:529 标签「重置」）。
      // 本地新增 app_replay.svg，pathData 取自 Material Icons Filled.Replay（viewBox 24）。
      Image($r('app.media.app_replay')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'unfoldMore') {
      // 上游 `Icons.Default.UnfoldMore`（登录表单 select 型尾部的「展开更多」）：本地新增 app_unfold_more.svg。
      Image($r('app.media.app_unfold_more')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else {
      // 兜底：联合类型新增成员却忘了写分支时会落到这里。
      // 渲染成网页图标而不是空白，便于在界面上看见；覆盖度由 scripts/icon-glyph-coverage.py 守。
      Image($r('app.media.app_web')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    }
  }
}
