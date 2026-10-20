# 场景音乐、环境音与门声（2026-10-20）

新增 12 个运行时 OGG，共 9,114,318 字节，全部来自公开的 CC0 素材。游戏离线播放。已在本次任务重新访问作者发布页核查许可；已有下载包直接复用原始文件，没有重新下载重复的大包。原有标题、城镇昼夜、UI、脚步、采集和经营声音继续使用。

| 场景 / 事件 | 素材与作者 | 行为 |
| --- | --- | --- |
| 家中白天 | Childhood Friends — Juhani Junkala / SubspaceAudio | 舒缓 JRPG 循环 |
| 码头白天 | Sand Castles — Juhani Junkala / SubspaceAudio | 独立水边主题 |
| 萤灯森林、莲雾湿地白天 | Forest Whisper Theme — Cleyton Kauffman | 木笛、弦乐与铃声的舒缓配乐 |
| 晴天小镇、农场、普通野外和森林 | Ambient Bird Sounds — isaiah658 | 鸟鸣环境录音 |
| 晴朗夜间户外 | Crickets Ambient Noise — Wolfgang_ / Ted Kerr | 虫鸣循环 |
| 码头、莲雾湿地 | Water loop 02 — rubberduck | 水声；雨雪中仍保留 |
| 铁匠铺 | Fireplace Sound Loop — PagDev | 持续炉火声 |
| 餐厅正在烹饪时 | Boiling Water Loops — TinyWorlds | 沸水循环，完成后淡出 |
| 成功进入 / 离开室内 | RPG Audio — Kenney Vleugels | 开门 / 关门各 2 个变体，不连续重复 |

音乐与场景环境音都使用 0.8 秒渐变，同一曲目或同一环境声的每帧上下文更新不重启声音。下雨、下雪时停用鸟鸣和虫鸣，沿用项目雨声 / 风声；水声、炉火和烹饪由地点与活动决定。家、商店和未烹饪的餐厅不添加室外环境声。结算时停用环境层，保留原夜间音乐。

背景声暂停菜单、背包和设置期间继续，脚步与世界活动仍遵循原有暂停规则。场景环境音使用原“环境音效”与“全局音量”，木门使用“角色音效”；静音、音量归零及旧音效静音接口即时生效。门声只在成功的正常场景交接触发，不在存档恢复、开场布景或普通户外换场时播放。

新音乐默认输出 RMS 约 −39 至 −40 dBFS，环境声约 −41 至 −44 dBFS。森林原录音较轻，以播放增益 +5 dB 对齐，其余新音乐为 −6 dB；所有新声音的最大分类音量均保留峰值余量。多个声源相加仍受现有整体混音影响。

逐文件 URL、作者、CC0 许可链接、原始来源路径、包内文件名、SHA-256、大小、转换记录、时长与响度见 [manifest.json](manifest.json)。`Sources/` 保存新下载的原始音频；`Licenses/` 保存本次获取的发布页和包内作者说明。两目录有 `.gdignore`，不会成为游戏资源。9 个运行时文件保留原始字节；鸟鸣、虫鸣与炉火转换为 Vorbis，并对首尾作 120 毫秒循环交叠，原始声音仍保留。

发布页：

- [JRPG Pack 4 Calm](https://opengameart.org/content/jrpg-pack-4-calm)
- [Forest Whisper Theme](https://opengameart.org/content/forest-whisper-theme)
- [Ambient Bird Sounds](https://opengameart.org/content/ambient-bird-sounds)
- [Crickets Ambient Noise](https://opengameart.org/content/crickets-ambient-noise-loopable)
- [Fireplace Sound Loop](https://opengameart.org/content/fireplace-sound-loop)
- [Boiling Water Loops](https://opengameart.org/content/boiling-water-loops)
- [40 CC0 Water / Splash / Slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx)
- [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)

重建需要 Python、numpy 与 soundfile；游戏运行不需要这些工具。生成器只写 `Sounds/Walala/World/`，存在不同内容时拒绝覆盖。导入器在 `output/audio_world/` 的小项目中导入选中的 12 个 OGG，再复制对应缓存，不启动主项目编辑器扫描。

```powershell
python Sounds/Walala/prepare_world_audio.py
python Sounds/Walala/run_world_audio.py import
python Sounds/Walala/run_world_audio.py world
python Sounds/Walala/run_world_audio.py gameplay
python Sounds/Walala/run_world_audio.py settings
python Sounds/Walala/run_world_audio.py backpack
python Sounds/Walala/run_world_audio.py music
python Localization/build_catalog.py
```

验证使用按进程隔离的设置、存档和引擎日志；每次对照 `MyArt/` 文件名和内容哈希。检查完整 PCM、最大音量峰值、FMOD 实际通道跨尾循环、暂停期间播放、日夜和地点渐变、快速换场、音量 / 静音、门声变体与自然结束、活动结束和场景释放。实际世界验证经过家、农场、码头、森林、湿地、铁匠铺和餐厅，并检查真实场景交接的门声。日志在 `output/audio_world/`。环境中的 Windows 根证书读取诊断保留在日志中，离线音频检查仅豁免这一条宿主诊断，其他引擎错误均判为失败。

验证结果：新音频 74 项、真实场景 10 项、五项音量设置 75 项、背包暂停 38 项、六首音乐 37 项，共 234 项通过；12 个素材来源及输出哈希、完整 PCM 解码与词库覆盖检查通过，3 个 `MyArt/` 原稿文件的路径和内容哈希未变。已经完成程序与真实 FMOD 播放验证；未进行人工耳机试听或本次正式导出包验证。
