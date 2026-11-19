# 朗读（TTS）九批实现批次报告

任务：按《朗读（TTS）实现任务书》在 `legado-with-md3-harmonyos` 分九批实现朗读，每批构建 + 装包 + 上机 + 单独提交。
口径：怎么还原上游怎么来；查出的不一致完整还原、不打补丁；不造「点了没反应」的控件；平台做不到的如实标注。
判定只用四个词：**做了 / 做不到 / 不接 / 顺延**，不写「已对齐上游 / 基本对齐 / 大部分支持」。

## 一、九批提交号

| 批 | 内容 | 提交号 |
| --- | --- | --- |
| 1 | 偏好仓库 + 14 键数据模型 + 备份互通 + 音色源过滤 | `9f12352` |
| 2 | 切段器 `SpeechSegmenter`（四档、标点切分） | `7f686eb` |
| 3 | 系统 TTS 封装 `SystemTtsPlayer` + 串行播放链 + 底栏入口 | `d2c92ab` |
| 4 | 朗读段高亮 + 位置回写 + 翻页跟随 | `04b40bb` |
| 5 | 朗读面板 12 处占位替换 + 三开关设置面板 | `b2e795a` |
| 6 | 朗读胶囊完整还原 + player 听书界面（同批合并） | `f5dd75d` |
| 7 | 后台长时任务 + AVSession 控制条 | `e7bd924` |
| 8 | HTTP TTS 源与音色目录（AVPlayer 合成播放） | `8129f26` |
| 9 | HTTP 合成缓存/并发限流/预合成 + ttsFollowSys | `bc9be38` |

九批代码提交后，另有文档收尾提交（本文档与 FEATURES/PROJECT/KNOWN-ISSUES/TXT-READER 的改动）单独提交。

## 二、9.1 逐条判定（16 条）

| # | 上游行为 | 判定 | 依据 / 做法 |
| --- | --- | --- | --- |
| 1 | 音频缓存 key 含源/语速/正文 | **做了** | `HttpTtsPlayer.cacheKey()`：`md5Hex32("${sourceKey}-\|-$speechRate-\|-$text")`，三要素齐备，对齐 `HttpReadAloudService.kt:1571`。批9 上机见 `cache=false`→`cache=true` 命中。 |
| 2 | 并发限流 coerceIn(1,8) | **做了** | `HttpTtsPlayer.acquire/release`：`Map<sourceId,active>` + FIFO 等待队列，`limitOf()` 取 `synthesisThreadCount` 夹 `1..8`。 |
| 3 | 409 重试 / 断流 | **做了（部分）** | `speak()` 的 `releaseOnce()` 配合 `generation` 保证每段配额只释放一次（对齐「close 只执行一次」意图）；**409 专用重试未做**——本地下载失败统一走 onError，未按状态码重试。 |
| 4 | 流式播放 useStreamPlayback | **做不到** | 系统 TTS `onData` 实测不回调（SDK `TextToSpeechEngine` 无流式输出）；HTTP 源虽可用 `AVPlayer.url` 播网络流，但朗读逐段合成、每段一请求，流式收益有限，未接。 |
| 5 | 预合成（下一段边念边合成） | **做了（仅 HTTP）** | `SystemTtsPlayer.speakCurrent()` 念当前段时调 `HttpTtsPlayer.preload()` 后台下载下一段并按三要素 key 缓存；上机见 `cache=true` 命中。系统 TTS 不产文件，预合成无意义。 |
| 6 | 预下载整章 audioPreDownloadNum | **顺延** | 需整章音频落盘 + 缓存清理，工作量与收益不成比例。 |
| 7 | 章节衔接（四判据） | **做了（基础版）** | 批4 `ReaderPage.onReadAloudSpanChanged` 按章号比对定位（见 9.2）；**未做「等待章 → 新章就绪自动续播」的显式 pending 状态机**，目前靠用户换章触发。 |
| 8 | 手动翻页跟随 + detach 提醒 | **做了（跟随）/ 不接（提醒）** | 跟随见 9.2；`readAloudDetachReminderEnabled` 的「回到朗读位置」提示未做，翻页后由下一次 span 变化重新定位。 |
| 9 | contentSelectSpeakMod | **不接** | 控制「长按朗读从当前段还是当前位置开始」，本地只有一个入口，无二选一。 |
| 10 | readAloudByPage 独立开关 | **不接** | 它是 `contentSplitMode=Page` 的旧表示，批2 已含 Page 档，不重复做开关。 |
| 11 | 34 个设置项 | **做一部分** | 见 9.3。 |
| 12 | 七个上游子页 | **大部分不接** | 见 9.4。 |
| 13 | defaultReadAloudInterface 两档 | **顺延** | 字段保留（`ReadAloudSettingsRepository`），player 已在批6 全屏浮层实现、classic 为现有面板，但未接成「按此偏好自动选默认界面」的开关。 |
| 14 | readAloudPlayerBgMode 四档 | **做了（视觉近似）** | 批6/player 已做纯色/封面模糊/流动光/透明四档（`ReadAloudPlayerPage.bgIndex`）；流动光是静态渐变近似，非 Compose shader。 |
| 15 | ttsFollowSys（HTTP 1.0x） | **做了（仅 HTTP）** | 批9 `Index.configureHttpSource` 入参 `settings.ttsFollowSys ? 5 : settings.ttsSpeechRate`，对齐 `HttpReadAloudService.kt:138`。 |
| 16 | 音效（正则角色命中放音频） | **不接** | 依赖角色识别 + AI 分配，范围之外。 |

## 三、9.2 章节衔接四判据（本地代码，`pages/ReaderPage.ets:3028-3066`）

```
const span = this.readAloudSpan;
if (span.start >= 0 && this.localReaderPages.length > 0) {
  const chapterIndex = this.getChapterIndex();
  const chapterPages: number[] = [];
  for (let i = 0; i < this.localReaderPages.length; i++) {
    const pg = this.localReaderPages[i];
    if (pg !== undefined && (pg.chapterIndex ?? 0) === chapterIndex) { chapterPages.push(i); }
  }
  let chapterOrdinal = 0;
  for (let k = 0; k < chapterPages.length; k++) {
    const idx = chapterPages[k] ?? -1;
    const pg = this.localReaderPages[idx];
    if (pg !== undefined && pg.endPosition > span.start) { break; }
    chapterOrdinal++;
  }
  if (this.usesCanvasScroll()) {
    this.seekReaderScrollAbsolute(Math.max(0, span.start));
  } else {
    const target = locateChapterPage(this.localReaderPages, chapterIndex, chapterOrdinal);
    if (target >= 0 && target !== this.currentPageIndex) { this.currentPageIndex = target; }
  }
  // 位置回写：段首语义坐标 → 源字符坐标 → 百分比 → 宿主落库
  const sourcePos = LocalTextSemantics.toSourcePosition(this.localSemanticDocument, renderPos);
  const progress = ...;
  this.emitReaderProgress(progress, sourcePos, true);
}
```

- 判据1「朗读仍在运行」：`span.start >= 0`（停止时 `clearSpan()` 置 -1）。
- 判据2「正在等章」：**未做显式 pending**，见 9.1-7。
- 判据3「新章已就绪」：用 `pg.chapterIndex === chapterIndex` **按章号比对**（不是只看 `length > 0`），避开上游「章节分页未完成静默放弃」的坑。
- 判据4「当前位置在章首附近」：`chapterOrdinal` 从该章第 0 页算起，换章后从第 0 段开始定位。

## 四、9.3 设置项判定（33 项：做 6 / 顺延 12 / 不接 15）

任务书称 34 项且统计「做11/顺延6/不接17」，但其表逐行只有 33 行且加总为「做11/顺延7/不接15」，自身矛盾。
本表按**实际代码状态**重判（任务书建议「做」但代码没 UI 的，如实落「顺延」）：

- **做了（6）**：`show_read_aloud_capsule`（批6）、`capsule_auto_collapse`（批6）、`reset_read_aloud_capsule_position`（批6）、`read_aloud_engines_and_voices`（批8）、`tts_paragraph_interval`（批3行为，批5三开关面板加 UI）、`pref_media_button_per_next`（批7 AVSession `playNext` 已注册）。
- **顺延（12）**：`default_read_aloud_interface`、`read_aloud_player_background`（已有 player 视觉四档但未接偏好自动选默认）、`sys_tts_config`、`tts_cache_manage`（缓存大小 + 清空按钮未做 UI）、`read_aloud_preload`、`tts_pre_synthesis_concurrency`（预合成行为已做，但并发数设置项 UI 未做）、`audio_cache_clean_time`、`clear_cache`（朗读专属清理 UI 未做）、`bgm_assign`、`cast_bgm_pool`、`cast_bgm_scene_table`、`read_aloud_content_split_mode`（四档切段行为已做，但设置页选择器未接）。
- **不接（15）**：`capsule_style_title`、`ignore_audio_focus_title`、`pause_read_aloud_while_phone_calls_title`、`read_aloud_wake_lock`、`read_aloud_keep_on_exit`、`read_aloud_android_media_control`、`system_media_control_compatibility_change`、`stream_read_aloud_audio`、`speech_analysis_mode`、`speech_analysis_reasoning_level`、`use_multi_speaker`、`multi_role_cast`、`read_aloud_character_casting`、`cast_voice_pool`、`ai_scene_assign_entry`。

结论：上游朗读设置面板超过半数依赖本地没有的 AI 角色体系、Android 专有能力或平台做不到的 audiofx，不接是如实判定而非遗漏。

## 五、9.4 七个上游子页判定

| 子页 | 行数 | 判定 |
| --- | --- | --- |
| 角色声音池 `VoicePoolScreen.kt` | 460 | **不接**（角色体系依赖 AI 分配） |
| 背景音乐池 `BgmPoolScreen.kt` | 689 | **顺延**（BGM 域） |
| 变声器 `VoiceEffectScreen.kt` | 468 | **不接**（平台无播放侧音频效果 API） |
| 朗读胶囊设置 `CastCapsuleStyleScreen.kt` | 774 | **不接**（外观定制，批6 只做显隐/位置/收起） |
| 朗读引擎与音色 `CloudTtsScreen.kt` | 1337 | **部分做**：批8 做了 HTTP 源与音色目录；七家云端 provider 不接（范围之外） |
| 多角色识别 `MultiRoleRecognitionScreen.kt` | 157 | **不接**（AI） |
| 正则角色管理 `RegexCastRuleScreen.kt` | 534 | **不接**（AI） |

## 六、未验证清单与原因

模拟器 127.0.0.1:5555 无扬声器，且系统 TTS 引擎在应用失焦后回调冻结，以下项**未通过设备验证**，不宣称已验证：

1. **真机出声**：无扬声器；所有链路只验到 `onComplete/onStart` 与合成请求到达（hilog + 本地 HTTP 服务器请求日志）。
2. **后台持续续播**：长时任务与 AVSession 激活有日志证实，但 HOME 后 TTS 回调冻结，未测到持续推进；grep 确认代码未主动 stop，属系统行为。
3. **通知栏媒体控制条**：系统发出 bgmode 通知后被 SystemUI 移除（`isShowStatusBarIcon:false`），模拟器通知栏不显示 AVSession 媒体卡片；代码侧 `setAVMetadata/setAVQueueItems/setAVQueueTitle/setLaunchAbility` 均调用成功。
4. **锁屏 30 秒续播**：模拟器无锁屏音频行为，未验证。
5. **外部真实 HTTP TTS 源**：无公网 TTS 凭据；用本地测试服务器（`tmp/b8_tts_server2.mjs`）验证了 URL 拼接、音色目录、播放链路与缓存。
6. **云端七家 provider / 角色体系 / BGM 域**：范围之外或未迁移，未做未验。

## 七、做不到项平台依据（SDK 文件:行号）

| 项 | 依据 |
| --- | --- |
| 系统 TTS 调速 | `@kit.CoreSpeechKit.d.ts` 的 `TextToSpeechEngine` 无 `setSpeechRate/setPitch/setVolume`；`onData` 实测不回调 |
| 跨应用悬浮窗胶囊 | `PermissionDefinitions.json:615`：`SYSTEM_FLOAT_WINDOW` 的 `level=system_basic`，三方不可申请 |
| 变声器音频效果 | `@ohos.multimedia.audio.d.ts` 仅有 `AudioLoopbackEqualizerPreset/AudioLoopbackReverbPreset`（回环），无播放侧 Equalizer/混响/变调 API；`@ohos.effectKit.d.ts` 是图像效果 |
| 流式播放（系统 TTS） | 系统 TTS 只吃文本、无流式音频输出 |
| AnalyzeUrl 模板/JS、loginCheckJs、jsLib | 鸿蒙 ArkTS 无 JS 引擎（Rhino 对应物），字段保留不执行 |
| 后台焦点/退出保留（ignoreAudioFocus / keepReadAloudOnExit） | 系统 TTS 不暴露音频焦点控制；鸿蒙无「退出应用后保留」对应位，靠长时任务 |

## 八、文档收尾

- `docs/KNOWN-ISSUES.md`：新增批13 三条（KI-ALOUD-RATE 调速 / KI-ALOUD-VOICEFX 变声器 / 胶囊并入批12），并修订批12 胶囊条目与听书界面节。
- `docs/FEATURES.md`：朗读章按九批实测重写（删除「零音频能力」「4 个 @State」「跟随系统开关」等失真表述）。
- `docs/PROJECT.md:42`：删「朗读链路 15 个文件」无出处数字、改正「8 处占位」（实测 0），改按实测判定口径。
- `docs/parity/TXT-READER.md`：两处「朗读不在范围」改判为「已纳入范围、按批推进」，与「在线服务纳入范围」决策一致。
- `docs/parity/` 七表本批未改（盘面数字须九批完成并上机后重算，不在本批范围）。
