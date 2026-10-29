export type AppGlyphName = 'home' | 'bookshelf' | 'discover' | 'subscription' | 'profile' | 'search' | 'searchPrecisionOn' | 'searchPrecisionOff' | 'more' | 'settings' | 'swap' | 'add' | 'goal' | 'book' | 'bookmark' | 'cloud' | 'cloudSync' | 'cloudUpload' | 'cloudDownload' | 'edit' | 'pencil' | 'delete' | 'share' | 'star' | 'ruleSubscription' | 'favoriteStar' | 'navHomeFilled' | 'navHomeOutlined' | 'navBookshelfFilled' | 'navBookshelfOutlined' | 'navExploreFilled' | 'navExploreOutlined' | 'navRss' | 'navProfileFilled' | 'navProfileOutlined' | 'profileWeb' | 'profileSource' | 'profileFindReplace' | 'profileRule' | 'profileSell' | 'profileAutoAwesome' | 'profileSettings' | 'profileBookmark' | 'profileHistory' | 'profileDownload' | 'profileFolder' | 'profileInfo' | 'profileExitToApp' | 'profileClose' | 'profileNoteAdd' | 'profileContentPaste' | 'profileRunningWithErrors' | 'profileSave' | 'profileCheck' | 'profileExpandMore' | 'profileTimeline' | 'profileFilterAlt' | 'profileRefresh' | 'clock' | 'accessTime' | 'chart' | 'folder' | 'tag' | 'list' | 'download' | 'info' | 'sparkles' | 'logout' | 'web' | 'locate';

@Component
export struct AppGlyph {
  @Prop name: AppGlyphName = 'home';
  @Prop glyphSize: number = 22;
  @Prop tint: string = '#C5C7D0';

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
    } else if (this.name === 'profileExpandMore') {
      Image($r('app.media.profile_expand_more')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileTimeline') {
      Image($r('app.media.profile_timeline')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileFilterAlt') {
      Image($r('app.media.profile_filter_alt')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    } else if (this.name === 'profileRefresh') {
      Image($r('app.media.profile_refresh')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
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
    } else {
      Image($r('app.media.app_web')).width(this.glyphSize).height(this.glyphSize).fillColor(this.tint)
    }
  }
}
