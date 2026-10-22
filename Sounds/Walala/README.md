# 角色对白音效更新（2026-10-22）

对白已接入 Dillon Becker 的 Super Dialogue Audio Pack，使用五位演员的 15 个短人声音节。此包采用 CC BY 4.0，免费商用但需要署名，区别于下文历史 CC0 音源。授权、改编说明、重建和验证流程见 [Dialogue/README.md](Dialogue/README.md)。主角、向导和居民按稳定头像 ID 分配音色，受现有角色音量控制；跳过、关闭与回看及时停声，快速显示不集中补播。

# 场景音频补充（2026-10-20）

新增家、码头、森林 / 湿地三首配乐，鸟鸣、虫鸣、水声、炉火、烹饪五种环境音，以及开关木门各两个变体。素材均在本次重新在线核查为 CC0，接入现有 FMOD、音量、静音和暂停系统，按地点、天气及烹饪状态切换。来源、混音、重建与隔离验证见 [World/README.md](World/README.md)，逐文件清单在 `World/manifest.json`。以下旧记录中的“所有地点共享昼夜音乐”“晴天无环境声”以此次新配置为准。

# 采集音效更新（2026-10-11）

已将植物采集、砍伐、开采和钓鱼替换为网上核查过的 CC0 原始素材。Kenney [Impact Sounds](https://kenney.nl/assets/impact-sounds) 提供木材与矿石撞击；rubberduck [水花音效包](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) 提供落水、咬钩和收鱼；TinyWorlds [材质声音包](https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud) 的树叶沙沙声用于植物与农田交互。复用项目中已下载的原始 ZIP，逐文件核对原包字节。另行寻找的树叶录音因下载连接失败未采用。

| 事件 | 选用原素材 | 变体数 | 播放增益 |
| --- | --- | --- | --- |
| 植物采集 / 农田 | leaves01 / leaves02 | 2 | +16 / +22 dB |
| 砍伐命中 | impactWood_medium_000–002 | 3 | −6 dB |
| 开采命中 | impactMining_000–002 | 3 | −8 dB |
| 浮漂落水 / 农田补水 | splash_02 / splash_03 | 2 | −3 dB |
| 咬钩 | bubble_02 | 1 | −5 dB |
| 收鱼成功 | splash_06 / splash_08 | 2 | −5 dB |

13 个 OGG 共 226,719 字节，原始音频没有裁剪、重编码或合成。树叶原录音很轻，分别补偿增益后，默认音量的 RMS 约 −39 dBFS；其他声音约 −36 至 −43 dBFS。单音在最大音量下仍保留峰值余量。采集成功和命中才发声；浮漂落水在抛竿后 0.45 秒播放，取消抛竿不会提前响。不同变体避免连续重复，除固定咬钩提示外，音高在 0.97–1.03 范围轻微变化。沿用 8 个声部、全局 / 角色音效音量和静音逻辑，音量更新保持每类声音的增益；满员不抢占，恢复音量不补播。

运行映射在 `harvest_audio.gd`，逐文件来源、下载 URL、原包路径、SHA-256、大小和增益在 `Harvest/manifest.json`。旧合成 WAV 和 `gather.ogg` 保留，但不再被采集播放器加载。资源使用显式 preload，游戏运行时不联网。游戏内鸣谢与 `CREDITS.txt` 已更新。

~~~powershell
python Sounds/Walala/prepare_harvest.py
python Sounds/Walala/run_harvest_audio.py import
python Sounds/Walala/run_harvest_audio.py backend
python Sounds/Walala/run_harvest_audio.py headless
python Sounds/Walala/run_harvest_audio.py audio
python Sounds/Walala/run_harvest_audio.py harvest
python Sounds/Walala/run_harvest_audio.py farm
python Sounds/Walala/run_harvest_audio.py settings
~~~

导入仅在 `output/harvest_audio/` 下的小型 Godot 项目处理这 13 个文件，再复制导入缓存，避免扫描或写入 `MyArt/`。验证使用隔离设置和存档，原稿哈希与开始时对照；日志与 PCM 响度指标在该输出目录。当前工作区使用 FMOD 播放后端，验证实际声道的增益、音高、自然结束和暂停尾音，同时通过 Godot 独立解码检查完整 PCM 与峰值余量。`backend` 为独立声音验证；`headless` / `audio` 还检查真实采集入口的成功、失败与触发时机，均不打开窗口。未进行人工耳机试听或导出包测试。

验证结果：独立声音后端 64 项、完整采集音效无窗口 80 项、WASAPI 模式 80 项，以及既有采集玩法回归 87 项全部通过。回归测试已同步当前日落进入餐厅准备、选菜单后确认营业的流程；只修改验证断言，不改变经营或输入逻辑。

以下保留此前音频接入记录，采集映射以上述最新配置为准。

# Walala 音频实装

## FMOD 播放（2026-10-11）

主菜单、昼夜音乐、天气、经营与采集动作、脚步和 UI 音效统一使用 **FMOD Core 2.03.06** 播放现有 OGG/WAV。现有五项音量、旧设置继承、静音、默认混音、素材变体与音高、0.8 秒日夜渐变保持原接口；玩家界面文案和输入映射没有调整。当前无需制作 FMOD Studio bank。

`fmod_voice.gd` 是场景持有的原生 FMOD 通道适配器；Godot 音频资源只提供路径、循环标记和测试所用的时长，解码、混音、循环和输出由 FMOD 完成。`fmod_runtime.gd` 作为 `WalalaFmod` 自动加载，暂停期间继续更新 FMOD，并按引用数共享、释放音频文件。音乐、天气、UI 和已开始的动作声持续播放；脚步遵循所在世界的暂停状态。退出与场景交接通过统一的 `stop()` 停止声音。

`addons/fmod/` 包含 Utopia-rise [6.1.0-4.5.0 官方发布包](https://github.com/utopia-rise/fmod-gdextension/releases/tag/6.1.0-4.5.0)的原生库、GDExtension 配置及图标，保留原始字节。安装时核对官方压缩包 SHA-256：`8796f6cd1cb38bf7ff4da2648f8af2695244ffdb80a7ac4ab8a171ca44895713`。来源与许可分别见 `addons/fmod/UPSTREAM.json`、`addons/fmod/LICENSE`；FMOD 原生库使用其独立许可。没有安装本项目当前不使用的 Studio 编辑器面板脚本。

已启用的 `addons/walala_fmod/` 插件使用上游原生导出器，把 FMOD 需要的原始音频字节加入 PCK；GDExtension 同时携带对应平台的动态库。Live Update 默认关闭，避免游戏和测试实例争用调试端口。当前已验证 Godot 4.7.2 与 Windows x86_64 正式模板；其他平台尚未执行导出验证。

~~~powershell
python Sounds/Walala/run_fmod.py native
python Sounds/Walala/run_fmod.py export
python Sounds/Walala/run_audio_settings.py headless
python Sounds/Walala/run_audio_settings.py headless --backpack
python Sounds/Walala/run_music_refresh.py audio
~~~

测试使用 `output/` 下的独立配置和存档。FMOD 原生测试覆盖真实通道、原生音量与音高、混音、自然结束、三首完整音乐跨尾循环、当前全部音效入口和引用释放；Windows 导出测试创建独立的最小项目，并从只含正式 EXE、PCK 和动态库的目录运行，验证离开编辑器和原始工程后仍能播放。上游 Core 绑定没有播放位置与 seek 接口，测试使用真实通道身份检查连续播放，使用源时长和原生音高检查自然结束及循环，没有模拟播放位置。

本次独立验证：原生 FMOD 53 项、五项音量 75 项、隔离背包暂停 38 项、音乐 28 项、Windows 正式包 9 项通过。完整城镇暂停测试的音频断言通过，但场景仍报告农田 `unplantable` 数据与负矩形错误；旧 UI 综合测试还依赖现已不存在的 `quest_list`，因此这两项完整场景回归没有记作通过。日志见 `output/fmod/`、`output/audio_settings/` 和 `output/fmod_music_runner.log`。`MyArt/` 的文件名和内容哈希核对未变。

## 暂停时保留背景音频（2026-10-11）

音乐与环境音播放器在场景暂停期间继续播放，日夜切歌的 0.8 秒淡入淡出也继续完成。暂停菜单、设置、背包和四季手记均保留当前背景音频；游戏时钟、移动与角色动作仍保持暂停，已开始的一次性音效自然播完。室内不会额外开启天气音，音乐、环境音和全局音量的即时调整与静音仍然生效。

背包和木箱格子接入共用的悬停与键盘焦点音效，拿取、放置保留每次有效操作一次的点击音。打开、关闭及格子交互使用独立 UI 音量，世界暂停期间继续播放；角色音效静音不会关闭背包 UI 音效。

~~~powershell
python Sounds/Walala/run_audio_settings.py headless --pause
python Sounds/Walala/run_audio_settings.py audio --pause
python Sounds/Walala/run_audio_settings.py headless --backpack
python Sounds/Walala/run_audio_settings.py audio --backpack
~~~

`verify_pause_audio.gd` 在引擎初始化阶段设置独立的设置与存档路径，使用固定的旧版室内测试布局。验证实际暂停菜单开关、雨声与雪天风声、暂停中淡入淡出与滑杆静音、背包的键盘与快捷栏入口、格子悬停与焦点、物品拿取与放置音效、恢复后的连续播放，以及时间和移动保持冻结；WASAPI 模式还检查音乐、环境音、背包点击和动作音效的实际播放进度与结束。日志位于 `output/audio_settings/pause_*.log`。

`--backpack` 使用 `verify_backpack_audio.gd` 独立加载真实 HUD、背包与音频脚本，以最小测试世界隔离城镇素材和其他场景的改动。雨天、雪天重复打开背包的 WASAPI 38 项、无声模式 24 项验证通过，日志位于 `output/audio_settings/backpack_*.log`。

## 五项音量设置（2026-10-11）

主菜单和局内暂停菜单的声音页共用五条滑杆：全局音量、音乐、角色音效、环境音效、UI音效，显示 0–100 数值，0 为静音，调整后即时生效并自动保存。滑杆使用项目现有像素主题与字体；鼠标和既有方向键导航继续可用，玩家界面不增加操作提示。

`audio_settings.gd` 统一加载、保存与恢复默认值；全局音量乘以分类音量后应用到已有播放器，不修改全局音频总线。角色音效包含脚步和经营、采集、钓鱼动作，环境音效包含雨声与雪天风声，`ui` 和 `ui_*` 反馈由独立 UI 播放器处理，暂停时仍可调整。音乐音量与全局音量在切歌淡入淡出期间调整也会保持生效。一次性音效静音时停止，不在恢复音量后重播。

沿用原有安静的默认混音：全局 100、音乐 22、其余三项 35。旧 `effects_volume` 会分别继承为三个音效分类；旧静音值显示为 0，调整某一分类不会意外开启其他已静音分类。设置与旧开发工具的整体静音接口保持兼容。

~~~powershell
python Localization/build_catalog.py
python Sounds/Walala/run_audio_settings.py headless
python Sounds/Walala/run_audio_settings.py audio
python Sounds/Walala/run_audio_settings.py capture
python Scenes/MainMenu/run_verification.py headless
~~~

五项验证使用 `output/` 下按进程隔离的设置与存档路径，覆盖实际鼠标和键盘输入、数值更新、声道隔离、全局静音、旧配置、暂停及切歌中调音、设置继承、恢复本页与四种语言标签宽度；`capture` 输出四种语言的界面到 `output/audio_settings/`。

验证结果：五项音量逻辑及 WASAPI 模式各 75 项、四语言截图 79 项、主菜单含场景交接 41 项、音乐回归 24 项、WASAPI UI 音频回归 70 项全部通过；天气与脚步回归通过。脚步测试采样点已同步当前小镇的土路、斜向石路与自动出口，碰撞边界稳定后检查静止脚步，未改变移动或出口逻辑。词库重新生成并通过覆盖检查。另修正现有字体脚本的斜体 `Transform2D` 构造参数，保留原样式。

## UI 音效重配（2026-10-20 polished-v2）

基础 UI 反馈改用同一套项目内生成的调性短音：悬停和滑条使用轻量高音，普通点击与开关使用柔和双音，面板开合使用三音上行 / 下行，确认使用带低音根音的四音和弦，错误使用下行双音。所有提示音都采用 44.1 kHz 单声道 PCM、短淡入淡出和小于 0.4 秒的尾巴，默认 UI 音量下不会压过背景音乐。手记打开、合上和翻页继续使用原来的 RPG Audio 书本素材。

生成器为 `UI/generate_polished_ui.gd`，运行时映射在 `ui_audio.gd`，逐文件字节哈希和增益在 `UI/manifest.json`；上一版完整清单保存在 `UI/manifest_20261011.json`，旧版清单仍保留为 `UI/manifest_20261010.json`。素材不写入 `MyArt/`，运行时不联网。

~~~powershell
& 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --path . --headless --script res://Sounds/Walala/UI/generate_polished_ui.gd
python Sounds/Walala/run_ui_audio.py headless
python Sounds/Walala/run_ui_audio.py audio
~~~

## 音乐与 UI 换装历史（2026-10-11）

本次重新在线检索后，背景音乐改用 Juhani Junkala / SubspaceAudio 的 [JRPG Pack 4 Calm](https://opengameart.org/content/jrpg-pack-4-calm)，素材页与包内 `INFO.txt` 都明确为 CC0。三首原始 OGG 保存在 `Music/`：

| 使用位置 | 曲目 | 时长 |
| --- | --- | --- |
| 主菜单 | A Place I Call Home | 46.45 秒 |
| 白天小镇、野外与室内 | Peaceful Days | 64 秒 |
| 夜间、餐厅营业与结算 | Summer Memories | 65.45 秒 |

主菜单与局内共用 `music_library.gd`，沿用默认音乐 22%、额外 -6 dB、引擎循环、0.8 秒日夜交叉淡入淡出，以及同曲目跨地点不重播。选择来自同一作者的舒缓 JRPG 循环包；网页描述与解码检测用于筛选，未做人工耳机试听。

当时 UI 重新选用 Kenney 本人在 OpenGameArt 发布的 [51 UI sound effects](https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks)，素材页为 CC0，包内说明允许个人与商业使用。六个有机 WAV 覆盖悬停、点击、面板开合、开关与滑条；确认、错误改用已核查 Interface Sounds 原包的 `confirmation_003` / `error_004`。这版替换了八类提示音，手记开合和翻页继续使用原本的三个 RPG Audio 书本素材；后续 polished-v2 已接管基础八类提示音。

当时逐文件来源、下载地址、包内路径、SHA-256、大小与增益分别记录在 `Music/manifest.json` 和 `UI/manifest.json`；原音乐与旧 UI 文件保留为归档。原下载包为 `Archives/jrpg_calm.zip` 和 `Archives/organic_ui.zip`；许可网页保存在 `Licenses/*_20261011.html`，作者说明保存在 `Music/LICENSE.txt` 和 `UI/Organic/LICENSE.txt`。游戏内鸣谢与 `CREDITS.txt` 已同步更新。

重新运行项目即可加载新素材，运行时不依赖网络。可复现验证命令：

~~~powershell
python Sounds/Walala/prepare_refresh.py
python Sounds/Walala/run_music_refresh.py audio
python Sounds/Walala/run_ui_audio.py audio
python Sounds/Walala/run_ui_audio.py headless
~~~

测试使用项目 `output/` 下独立的临时设置和存档。`audio` 模式使用 Windows WASAPI 实际驱动并保持无窗口，验证完整 PCM 解码、尾部回绕、日夜切歌、快速连续切歌、音量/静音、设置继承，以及暂停中的 UI 输入与播放；Dummy 驱动模式只检查逻辑，不判定真实播放位置。结果与响度指标保存在 `output/music_refresh_*.log`、`output/ui_audio_*.log` 和 `output/music_refresh_metrics.json`。未进行人工扬声器试听或导出包验证。

本次验证结果：Godot 导入成功；WASAPI 音乐验证 28 项、UI 音频与交互验证 70 项、Dummy 无窗口 UI 验证 69 项均通过；3 首音乐和当前 11 个 UI 素材的原包字节校验通过。

以下为此前接入记录，当前选曲与映射以上述清单为准。

## UI 音效（2026-10-10 新增）

已在网上核查并选用 Kenney 的 [Interface Sounds](https://kenney.nl/assets/interface-sounds) 与 [RPG Audio](https://kenney.nl/assets/rpg-audio)，两者均为 CC0，可用于个人与商业项目。复用本项目已下载的原始资源包，从中新增导入 11 个 OGG，共 87,486 字节；保持原始音频字节，播放时降低音量。网络搜索也比较了 OpenGameArt 的 GUI / RPG 素材，最终采用同一作者的两套资源保持统一。

| 交互 | 原包素材 |
| --- | --- |
| 鼠标悬停、方向键 / Tab 移动焦点 | tick_001 |
| 普通点击、丢弃料理 | click_003 |
| 面板打开 / 关闭 | open_001 / close_001 |
| 选存档进入游戏、手动保存成功 | confirmation_001 |
| 存档失败、交易失败 | error_001 |
| 设置开关、菜单菜品勾选 | toggle_002 |
| 音量滑条调整 | tick_002 |
| 手记筛选、任务选择、对话推进 / 回看 | bookFlip2 |
| 手记打开 / 合上 | bookOpen / bookClose |

F5 运行项目即可体验：主菜单设置、开始游戏后的 J 手记 / B 背包 / H 对话，以及 Esc 暂停菜单中的保存、声音 / 鸣谢。局内点击底部物品格也会打开背包；商店 E 开合柜台有反馈。沿用主菜单和局内共享的音效音量与静音存储，音效音量为 0 或静音会立即停止当前 UI 声音，恢复后不补播。音乐音量独立。自动保存、逐字显示和每帧刷新不发提示音；禁用按钮不发选择音。

ui_audio.gd 是主菜单和局内共用的播放器，4 个可复用声部，暂停世界时继续处理 UI；悬停与滑条每类最多每 90ms 响一次，其他同类反馈间隔 40ms。低优先级提示不会抢占正在播放的确认音。返回标题和退出前留 0.3 秒完成短确认音，开始游戏沿用 0.3 秒淡出。保留原 play_event("ui") 兼容接口和原游戏交互声部。

逐文件来源、原包路径、SHA-256、大小、事件和增益见 [UI/manifest.json](UI/manifest.json)，两包原始授权保存在 UI/*_LICENSE.txt，游戏内鸣谢也已更新。所有声音离线运行。

验证入口（项目根目录）：

~~~powershell
python Sounds/Walala/run_ui_audio.py headless
python Sounds/Walala/run_ui_audio.py audio
python Sounds/Walala/run_ui_audio.py menu
python Sounds/Walala/run_ui_audio.py hud
python Sounds/Walala/run_ui_audio.py saves
~~~

音频模式使用 headless 显示加 Windows WASAPI 实际驱动，不打开游戏窗口。验证 OGG 解码、非零 PCM、播放与暂停中的推进、鼠标和键盘交互、节流、声部上限、静音、音量继承、存档成败和商店开合；每次使用独立临时存档、设置和日志。主菜单、HUD、存档回归全部通过。已完成程序验证，未做人工扬声器 / 耳机试听或导出包验证。

以下为较早的音频接入记录，界面入口以当前 Esc 菜单为准。


天气与脚步的新增接入、操作和验证见 [WEATHER_FOOTSTEPS.md](WEATHER_FOOTSTEPS.md)。以下为原音频接入记录；当前版本另有 13 个脚步音效，并沿用主菜单的声音设置保存。

## 使用
F5/F6运行原LanternLane，右下「声音 / 鸣谢」开关设置面板。音乐与音效/环境分别有滑条、静音；0也静音。面板不暂停营业，开着时暂遮右侧菜单，点击同一入口关闭。鸣谢可滚动、可关闭，不打开外部网页。没有新增快捷键，没有修改InputMap或project.godot。音量只在本次运行保留。

默认音乐22%、音效35%，音乐另减6dB，雨另减12dB。雪天风声现已按素材响度校准为 +6 dB（2026-10-11 修复；原 −24 dB 导致默认输出几乎无声），默认输出约 −40 dBFS，仍受环境音效与全局音量控制；详见 `WEATHER_FOOTSTEPS.md`。白天各地点共享Town（64秒），夜晚及结算Town 3（99秒）；0.8秒双播放器交叉淡入淡出。相同曲目不重启；四个长声音使用引擎loop。音乐不是作者明确标注的无缝曲，已验证回绕，但接缝主观听感未确认。雨作者明确提供可循环实录。

采集/加工/做菜/上菜只在原函数返回成功时触发；金币仅正收入结算的阶段边沿触发。音效8个有限声部，满员丢弃新音，不创建无界节点。UI点击在菜单和阶段按钮及设置入口触发。每帧只核对上下文/音量，不逐帧play；天气晴、进入餐厅或结算停止环境。音量/静音不影响库存、顾客用餐状态、经营计时。

## 资源与许可
10个音频文件共4,616,789字节，所有素材已核查实际素材页CC0 1.0链接，Kenney还核查压缩包License.txt。署名非强制但仍提供游戏内与CREDITS.txt。没有NC、授权不明、原作游戏音轨或生成替代。音乐依素材页小镇/古典/古典吉他分类选用，尚未人工试听，不能保证轻快/温馨的主观效果。

逐文件标题、作者、源页面完整URL、直接下载URL、包内路径、许可证、改动说明、SHA-256和字节数见manifest.json。所有文件保留原音频字节，只有重命名与播放设置；10个哈希复核一致。Licenses保存素材HTML证据和Kenney文本，Archives保存4个原下载包，声音目录含证据约10.3MB。证据HTML仅存档，不执行。下载脚本有限24MB请求上限、45秒超时、拒绝覆盖选用文件，不写外部目录。

来源：
- Town — Alex McCulloch / Pro Sensory: https://opengameart.org/content/town
- Town 3 — Alex McCulloch / Pro Sensory: https://opengameart.org/content/town-3
- Interface Sounds 1.0 — Kenney: https://kenney.nl/assets/interface-sounds （pluck_001、confirmation_001、click_001）
- RPG Audio — Kenney Vleugels / Kenney: https://kenney.nl/assets/rpg-audio （chop、metalPot1、handleCoins）
- Rain (loopable) — Ylmir: https://opengameart.org/content/rain-loopable （1.ogg）
- Wind — IgnasD: https://opengameart.org/content/wind （Wind.ogg）
- 全部许可：https://creativecommons.org/publicdomain/zero/1.0/
- 法律全文：https://creativecommons.org/publicdomain/zero/1.0/legalcode

## 改动边界
新增声音目录、Audio管理器、许可清单、独立测试。仅修改Scenes/Gameplay/game_loop.gd接入；loop_state.gd、play_area.gd、原顾客美术/用餐功能、verify_loop.gd、天气、LanternLane和project.godot均未改，关键文件hash对照开始时一致。没有安装、注册、付费、提交或覆盖旧资源/截图。Godot产生声音.import和本地缓存属导入行为。

## 验证
在项目根目录：
```
python Sounds/Walala/run_tests.py audio
python Sounds/Walala/run_tests.py regression
python Sounds/Walala/run_tests.py gui
python Sounds/Walala/run_tests.py lane
python Sounds/Walala/run_tests.py weather
```
Godot4.7.2 Windows Compatibility/OpenGL真实窗口，WASAPI音频驱动。audio验证每文件非零PCM解码、播放位置推进、日夜fade、长声音接近末尾真实回绕、单次声部启动、失败不响、不逐帧重播、环境停止、静音/音量及鼠标设置入口/静音/滑条/鸣谢开关。日志和截图全部新存Verification。音频测试显式停止临时解码playback、释放场景后退出。

两天headless 95项，真实窗口109项（含14张新截图）通过，音效累计成功计数一致；每天12累计24、进入第3天、库存与边界正常。原角色/小镇50项、天气16项通过。Headless回归退出曾提示2个ObjectDB实例泄漏（没有脚本错误/经营失败）；窗口两天日志无此提示。音频首次原生AcceptDialog触发引擎accessibility错误，改用Canvas内可滚动不透明面板后无该错误。面板透明透字及入口底边裁切经截图检查修复。

局限：未实际人工试听或录音回听，解码与WASAPI状态不等于扬声器/耳机主观听感验收；未验证导出包、跨平台或实体键盘连续两天。导出需包含CREDITS.txt（现有镇布局JSON也仍需包含）；音频文件会正常作为资源被引用。不新增设置存档。没有实时联网依赖。
