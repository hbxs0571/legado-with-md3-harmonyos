# HarmonyOS 资源来源与许可清单

核查日期：2026-10-24。核查对象是本仓库当前工程的实际随包资源；不包含上游 Android 工程或未随本仓库发布的私人素材。

## 当前数量与路径核对

当前 entry media 包含 **109 个 SVG** 和 **4 个 PNG**。旧记录称 91 个 SVG，并有图标条目重复，已经过期。逐项将 SVG 路径与上游 Android drawable 的 pathData（忽略空白、逗号）精确比较：**48 个**存在精确匹配；其中匹配只证明图形路径一致，不单独判定版权归属。

上游旧清单曾记录 GPL 来源图标、AndroidX Material Icons 的 Apache-2.0 图标及项目绘制图标。本次对旧清单逐项重核，按下表提供文件级状态；旧表外新增文件不凭图形相似自动套许可证。

| 文件 | 来源/许可审计状态 | 精确上游路径匹配 |
| --- | --- | --- |
| `about_cat.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_launcher_foreground.xml |
| `about_github.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_github.xml |
| `about_update.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `about_web.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_web_outline.xml |
| `app_access_time.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `app_add.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_add.xml |
| `app_anim_speed.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_speed.xml |
| `app_book.svg` | 上游旧清单记为 GPL-3.0；本次未能精确匹配 Android pathData | — |
| `app_bookmark.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_bookmark.xml |
| `app_bookshelf.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_bottom_books_e.xml; app/src/main/res/drawable/ic_shortcut_books.xml |
| `app_chart.svg` | 上游旧清单记为 GPL-3.0；本次未能精确匹配 Android pathData | — |
| `app_check.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_check.xml |
| `app_clock.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_history.xml; app/src/main/res/drawable/ic_restore.xml; app/src/main/res/drawable/ic_shortcut_recent.xml |
| `app_cloud.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_outline_cloud_24.xml |
| `app_cloud_download.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `app_cloud_sync.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `app_cloud_upload.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `app_code.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_code.xml |
| `app_daynight.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_daytime.xml |
| `app_discover.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_book_last.xml; app/src/main/res/drawable/ic_bottom_explore_e.xml |
| `app_download.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_download.xml |
| `app_edit.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_edit.xml |
| `app_favorite_star.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `app_folder.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_folder_open.xml; app/src/main/res/drawable/ic_folder_outline.xml |
| `app_goal.svg` | 上游旧清单记为 GPL-3.0；本次未能精确匹配 Android pathData | — |
| `app_group.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `app_home.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `app_icon.svg` | 工程记录为迁移期间项目绘制；GPL-3.0 衍生工程 | — |
| `app_info.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_cfg_about.xml |
| `app_label.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `app_list.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_chapter_list.xml |
| `app_locate.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_locate.xml |
| `app_logout.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_auto_page_stop.xml; app/src/main/res/drawable/ic_exit.xml |
| `app_moon.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `app_more.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_more.xml; app/src/main/res/drawable/ic_more_vert.xml |
| `app_padding.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_padding.xml |
| `app_pencil.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `app_previous.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_previous.xml; app/src/main/res/drawable/ic_skip_previous.xml |
| `app_profile.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_author.xml; app/src/main/res/drawable/ic_bottom_person_e.xml |
| `app_reduce.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_reduce.xml |
| `app_refresh.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_check_source.xml; app/src/main/res/drawable/ic_refresh.xml |
| `app_rule_subscription.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `app_search.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_search.xml; app/src/main/res/drawable/ic_search_hint.xml |
| `app_send.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_next.xml; app/src/main/res/drawable/ic_skip_next.xml |
| `app_settings.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_cfg_other.xml; app/src/main/res/drawable/ic_settings.xml |
| `app_share.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `app_sort.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_baseline_sort_24.xml; app/src/main/res/drawable/ic_sort.xml |
| `app_sparkles.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_award.xml |
| `app_star.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_star.xml |
| `app_stop_square.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_stop_black_24dp.xml |
| `app_subscription.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_bottom_rss_feed_e.xml |
| `app_swap.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_cfg_replace.xml; app/src/main/res/drawable/ic_swap_horiz.xml |
| `app_tag.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_bookmark_badge.xml |
| `app_visibility.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_visibility_on.xml |
| `app_web.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_web_outline.xml |
| `menu_bookmarks.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `menu_carousel.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `menu_grid.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `menu_link.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `menu_save.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `menu_upload_file.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `menu_wifi.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `nav_bookshelf_filled.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_bookshelf_outlined.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_explore_filled.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_explore_outlined.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_home_filled.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_home_outlined.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_profile_filled.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_profile_outlined.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `nav_rss.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_auto_awesome.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_bookmark.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_close.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_content_paste.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_delete.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_download.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_exit_to_app.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_expand_more.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_filter_alt.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_find_replace.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_folder.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_history.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_info.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_note_add.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_refresh.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_rule.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_running_with_errors.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_save.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_sell.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_settings.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_source.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_timeline.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `profile_web.svg` | 上游旧清单记为 AndroidX Material Icons / Apache-2.0；本次未能精确匹配 Android pathData | — |
| `reader_arrow_forward.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `reader_back.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_arrow_back.xml |
| `reader_drag_handle.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `reader_more.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_more.xml; app/src/main/res/drawable/ic_more_vert.xml |
| `reader_next.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_arrow_right.xml |
| `reader_pause.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_pause.xml |
| `reader_play.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_play.xml |
| `reader_reorder_down.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `reader_reorder_up.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `reader_search.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_search.xml; app/src/main/res/drawable/ic_search_hint.xml |
| `reader_settings.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_cfg_other.xml; app/src/main/res/drawable/ic_settings.xml |
| `reader_toc.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_toc.xml |
| `reader_translate.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_translate.xml |
| `reader_visibility_off.svg` | 本次源码快照新增且未能对应上游 Android pathData；来源未证实，需维护者确认 | — |
| `reader_voice.svg` | 与上游 Android GPL-3.0 drawable 路径精确匹配；衍生资源 | app/src/main/res/drawable/ic_volume_up.xml |

### 发行处置说明

本清单区分来源记录与本次可独立证明的路径匹配；未匹配不等于图标必然有问题，但也不能仅凭旧表或名称确认许可。新增且未证实来源的 SVG 在对应来源未确认前不应作为已完成的发行审计结论。若权利人/来源无法确认，应替换为有明确许可的图标并更新本表。

4 个 `file_picker_*.png` 来自上游 Android `FilePickerIcon.java` 的 FILE/FOLDER/UPDIR/ARROW 字节数组，按 GPL-3.0 上游来源记录。Google Material Design Icons 与 AndroidX Material 图标的 Apache-2.0 文本见 `licenses/Apache-2.0.txt`；Google 官方许可：[Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0)。

## 不包含的素材与依赖

本公开导出没有复制 `assets/original-project/`。其原有 33 个字体、图片、品牌参考素材仅用于内部参考，独立授权未被完整确认；不随仓库提供，也不进入 HAP。构建插件 `@ohos/hvigor-ohos-plugin` 固定在工程配置中；运行时 imports 使用 HarmonyOS SDK，oh-package 未声明第三方 NPM 运行时包。上游通知、GPL-3.0 文本及 Apache-2.0 文本分别保留。

若将来加入图片、字体、在线内容或其它依赖，应在分发前追加来源、版本、许可和 HAP 使用情况。
