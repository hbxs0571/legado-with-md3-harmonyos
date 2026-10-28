# HarmonyOS 资源来源与许可清单

核查日期：2026-10-28。核查对象为公开源码快照中实际随 Entry 模块打包的资源；不包含上游 Android 工程或私人素材。

当前包含 **133 个 SVG** 和 **4 个 PNG**。逐项将 SVG 的 `d` 路径与 Android drawable XML 的 `android:pathData` 归一化（忽略空白、逗号）比较，**50 个**存在精确匹配；精确匹配只能证明图形路径一致，不单独判定版权归属。原清单中 15 个阅读菜单/搜索精度图标有 AndroidX Compose Material Icons 1.7.8 来源记录；此前核验的 16 个与该版本路径精确匹配。本轮指定的 10 个资源已追溯到原 Android 实际调用：8 个复用 AndroidX 原始矢量（Apache-2.0），2 个由原 Android 上下箭头 VectorDrawable 转换（GPL-3.0，作为重排方向近似图标）。

旧资源清单称 91 个 SVG，不能作为当前统计。以下保留每个文件的状态；旧清单条目来源于迁移工程文档，未精确匹配的行不视为新做的权利证明。

| 文件 | 来源/许可状态 | Android 路径匹配 |
| --- | --- | --- |
| `about_cat.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_launcher_foreground.xml |
| `about_github.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_github.xml |
| `about_update.svg` | 原工程资源清单记为 GPL-3.0 衍生资源；未能精确匹配 Android pathData | — |
| `about_web.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_web_outline.xml |
| `app_access_time.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.AccessTime` 原始向量；原 Android `HomeScreen.kt` 直接调用；Apache-2.0 | — |
| `app_add.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_add.xml |
| `app_anim_speed.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_speed.xml |
| `app_book.svg` | 原工程资源清单记为 GPL-3.0 衍生资源；未能精确匹配 Android pathData | — |
| `app_bookmark.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_bookmark.xml |
| `app_bookshelf.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_bottom_books_e.xml; app/src/main/res/drawable/ic_shortcut_books.xml |
| `app_chart.svg` | 原工程资源清单记为 GPL-3.0 衍生资源；未能精确匹配 Android pathData | — |
| `app_check.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_check.xml |
| `app_clock.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_history.xml; app/src/main/res/drawable/ic_restore.xml; app/src/main/res/drawable/ic_shortcut_recent.xml |
| `app_cloud.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_outline_cloud_24.xml |
| `app_cloud_download.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.CloudDownload`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `app_cloud_sync.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.CloudSync`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `app_cloud_upload.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.CloudUpload`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `app_code.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_code.xml |
| `app_daynight.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_daytime.xml |
| `app_discover.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_book_last.xml; app/src/main/res/drawable/ic_bottom_explore_e.xml |
| `app_download.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_download.xml |
| `app_edit.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_edit.xml |
| `app_favorite_star.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `app_folder.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_folder_open.xml; app/src/main/res/drawable/ic_folder_outline.xml |
| `app_goal.svg` | 原工程资源清单记为 GPL-3.0 衍生资源；未能精确匹配 Android pathData | — |
| `app_group.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `app_home.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `app_icon.svg` | 工程记录为迁移期间项目绘制；GPL-3.0 衍生工程 | — |
| `app_info.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_cfg_about.xml |
| `app_label.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `app_list.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_chapter_list.xml |
| `app_locate.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_locate.xml |
| `app_logout.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_auto_page_stop.xml; app/src/main/res/drawable/ic_exit.xml |
| `app_moon.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `app_more.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_more.xml; app/src/main/res/drawable/ic_more_vert.xml |
| `app_padding.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_padding.xml |
| `app_pencil.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Edit`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `app_previous.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_previous.xml; app/src/main/res/drawable/ic_skip_previous.xml |
| `app_profile.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_author.xml; app/src/main/res/drawable/ic_bottom_person_e.xml |
| `app_reduce.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_reduce.xml |
| `app_refresh.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_check_source.xml; app/src/main/res/drawable/ic_refresh.xml |
| `app_rule_subscription.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `app_search.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_search.xml; app/src/main/res/drawable/ic_search_hint.xml |
| `app_send.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_next.xml; app/src/main/res/drawable/ic_skip_next.xml |
| `app_settings.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_cfg_other.xml; app/src/main/res/drawable/ic_settings.xml |
| `app_share.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `app_sort.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_baseline_sort_24.xml; app/src/main/res/drawable/ic_sort.xml |
| `app_sparkles.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_award.xml |
| `app_star.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_star.xml |
| `app_stop_square.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_stop_black_24dp.xml |
| `app_subscription.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_bottom_rss_feed_e.xml |
| `app_swap.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_cfg_replace.xml; app/src/main/res/drawable/ic_swap_horiz.xml |
| `app_tag.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_bookmark_badge.xml |
| `app_visibility.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_visibility_on.xml |
| `app_web.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_web_outline.xml |
| `menu_bookmarks.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Bookmarks` 原始向量；原 Android `BookshelfScreen.kt` 直接调用；Apache-2.0 | — |
| `menu_carousel.svg` | AndroidX Compose Material Icons 1.7.8 `Outlined.ViewCarousel` 原始向量；原 Android `BookshelfScreen.kt` 直接调用；Apache-2.0 | — |
| `menu_grid.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.GridView` 原始向量；原 Android `BookshelfScreen.kt` 直接调用；Apache-2.0 | — |
| `menu_link.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Link`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `menu_save.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Save` 原始向量；原 Android `BookshelfScreen.kt` 直接调用；Apache-2.0 | — |
| `menu_upload_file.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.UploadFile` 原始向量；原 Android `BookshelfScreen.kt` 直接调用；Apache-2.0 | — |
| `menu_wifi.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Wifi`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `nav_bookshelf_filled.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_bookshelf_outlined.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_explore_filled.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_explore_outlined.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_home_filled.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_home_outlined.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_profile_filled.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_profile_outlined.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `nav_rss.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_auto_awesome.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_bookmark.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_close.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_content_paste.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_delete.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_download.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_exit_to_app.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_expand_more.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_filter_alt.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_find_replace.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_folder.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_history.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_info.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_note_add.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_refresh.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_rule.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_running_with_errors.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_save.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_sell.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_settings.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_source.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_timeline.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `profile_web.svg` | 原工程资源清单记为 AndroidX Material Icons / Apache-2.0；未能精确匹配 Android pathData | — |
| `reader_arrow_forward.svg` | AndroidX Compose Material Icons 1.7.8 `AutoMirrored.Filled.ArrowForward`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_back.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_arrow_back.xml |
| `reader_drag_handle.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Menu`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_align_center.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.AlignHorizontalCenter`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_align_left.svg` | AndroidX Compose Material Icons 1.7.8 `AutoMirrored.Filled.AlignHorizontalLeft`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_align_right.svg` | AndroidX Compose Material Icons 1.7.8 `AutoMirrored.Filled.AlignHorizontalRight`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_color_text.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.FormatColorText`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_format_size.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.FormatSize`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_heading.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.ViewHeadline`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_minimize.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Minimize`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_info_palette.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.Palette` 原始向量；原 Android `TypographyTabs.kt` 直接调用；Apache-2.0 | — |
| `reader_info_text_fields.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.TextFields`，与上游矢量路径精确匹配；Apache-2.0 | — |
| `reader_more.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_more.xml; app/src/main/res/drawable/ic_more_vert.xml |
| `reader_next.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_arrow_right.xml |
| `reader_pause.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_pause.xml |
| `reader_play.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_play.xml |
| `reader_reorder_down.svg` | 原 Android `ic_arrow_down.xml` VectorDrawable 路径转换；GPL-3.0。原版以拖动重排，本图是方向箭头近似映射 | app/src/main/res/drawable/ic_arrow_down.xml |
| `reader_reorder_up.svg` | 原 Android `ic_arrow_up.xml` VectorDrawable 路径转换；GPL-3.0。原版以拖动重排，本图是方向箭头近似映射 | app/src/main/res/drawable/ic_arrow_up.xml |
| `reader_search.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_search.xml; app/src/main/res/drawable/ic_search_hint.xml |
| `reader_settings.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_cfg_other.xml; app/src/main/res/drawable/ic_settings.xml |
| `reader_toc.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_toc.xml |
| `reader_translate.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_translate.xml |
| `reader_visibility_off.svg` | AndroidX Compose Material Icons 1.7.8 `Filled.VisibilityOff` 原始向量；原 Android `TextSelectMenuConfigSheet.kt` 直接调用；Apache-2.0 | — |
| `reader_voice.svg` | 与 Android GPL-3.0 drawable 路径精确匹配 | app/src/main/res/drawable/ic_volume_up.xml |
| `reader_menu_book.svg` | AndroidX Compose Material Icons `AutoMirrored.Outlined.MenuBook` 原始路径；Apache-2.0 | — |
| `reader_menu_bookmark.svg` | AndroidX Compose Material Icons `Outlined.Bookmark` 原始路径；Apache-2.0 | — |
| `reader_menu_border_color.svg` | AndroidX Compose Material Icons `Outlined.BorderColor` 原始路径；Apache-2.0 | — |
| `reader_menu_copy.svg` | AndroidX Compose Material Icons `Outlined.ContentCopy` 原始路径；Apache-2.0 | — |
| `reader_menu_edit.svg` | AndroidX Compose Material Icons `Outlined.Edit` 原始路径；Apache-2.0 | — |
| `reader_menu_find_replace.svg` | AndroidX Compose Material Icons `Outlined.FindReplace` 原始路径；Apache-2.0 | — |
| `reader_menu_language.svg` | AndroidX Compose Material Icons `Outlined.Language` 原始路径；Apache-2.0 | — |
| `reader_menu_playlist_add.svg` | AndroidX Compose Material Icons `Outlined.PlaylistAdd` 原始路径；Apache-2.0 | — |
| `reader_menu_queue_music.svg` | AndroidX Compose Material Icons `Outlined.QueueMusic` 原始路径；Apache-2.0 | — |
| `reader_menu_search.svg` | AndroidX Compose Material Icons `Outlined.Search` 原始路径；Apache-2.0 | — |
| `reader_menu_share.svg` | AndroidX Compose Material Icons `Outlined.Share` 原始路径；Apache-2.0 | — |
| `reader_menu_smart_toy.svg` | AndroidX Compose Material Icons `Outlined.SmartToy` 原始路径；Apache-2.0 | — |
| `reader_menu_volume_up.svg` | AndroidX Compose Material Icons `AutoMirrored.Outlined.VolumeUp` 原始路径；Apache-2.0 | — |
| `search_precision_off.svg` | AndroidX Compose Material Icons `Filled.LocationSearching` 原始路径；Apache-2.0 | — |
| `search_precision_on.svg` | AndroidX Compose Material Icons `Filled.MyLocation` 原始路径；Apache-2.0 | — |

## 本轮核验方法与证据

此前 16 个图标通过绝对几何路径归一化与 AndroidX Compose Material Icons 1.7.8 source JAR 精确匹配。本轮 8 个 SVG 进一步由原 Android 页面实际调用的 Compose Material Icons 矢量源重新生成，并核对 source JAR 内 DSL 路径与 SVG 路径一致；另 2 个排序方向 SVG 转换自原项目 `ic_arrow_up.xml`、`ic_arrow_down.xml`，属于 UI 近似映射，清单不声称它们是原版重排控件的同一图形。完整文件、调用点、依赖版本、上游源文件及本仓库资源的 SHA-256 记录见[资源来源与哈希清单](RESOURCE-SOURCES-SHA256-2026-10-26.csv)。AndroidX 1.7.8 来源包校验值为 `77B7E782A519A3E074FC91E09D59334AC1B815EDD87D2E89C0C9CA7C95678E93`；版本可在 [AndroidX Compose Material 1.7.8](https://developer.android.com/jetpack/androidx/releases/compose-material#1.7.8) 核验。许可依据为随本仓库保留的 Apache-2.0 与 GPL-3.0 全文。来源匹配证据不构成法律意见，也不替代各文件的版权核查。

## PNG 与第三方许可

4 个 `file_picker_*.png` 来自上游 Android `FilePickerIcon.java` 的 FILE/FOLDER/UPDIR/ARROW 字节数组，保留 GPL-3.0 上游来源。Material 图标使用的 Apache-2.0 完整文本见 `licenses/Apache-2.0.txt`，许可官方文本：[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)。

## 待核资源与不包含素材

此前 26 个新增 SVG 的来源核对现已收口：16 个与 AndroidX Compose Material Icons 1.7.8 精确匹配；本轮余下 10 个中，8 个对应原 Android 代码直接使用的 AndroidX 图标，2 个转换自原 Android 上下箭头资源并明确标为近似映射。

`assets/original-project/` 中的参考素材（字体、背景、封面和品牌图）不在本仓库公开树，也不随 HAP 打包。运行时 imports 来自 HarmonyOS SDK；oh-package 未声明第三方 NPM 运行时包。仓库不包含 DevEco SDK / Hvigor 的二进制。

新增图片、字体或其它第三方资源时，应在分发前记录来源、版本、许可和 HAP 使用情况。


## 内置 TXT 目录规则数据

`entry/src/main/resources/rawfile/txttoc/builtin-rules.json` 包含 27 条内置 TXT 目录规则。该文件与 [HapeLee/legado-with-MD3 的默认规则 JSON](https://github.com/HapeLee/legado-with-MD3/blob/main/app/src/main/assets/defaultData/txtTocRule.json) 逐字节一致；对应上游项目按 GPL-3.0 发布，本仓库随 GPL-3.0 许可分发。来源文件与本仓库文件的 SHA-256 均为 `a9b612ea996485bb99f67b3e25792602a8354d4abbc4fa74537395dc38375394`。
