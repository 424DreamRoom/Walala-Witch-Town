# Walala 音频实装

## 使用
F5/F6运行原LanternLane，右下「声音 / 鸣谢」开关设置面板。音乐与音效/环境分别有滑条、静音；0也静音。面板不暂停营业，开着时暂遮右侧菜单，点击同一入口关闭。鸣谢可滚动、可关闭，不打开外部网页。没有新增快捷键，没有修改InputMap或project.godot。音量只在本次运行保留。

默认音乐22%、音效35%，音乐另减6dB，雨另减12dB，雪天气仅低音量风声另减24dB，不把风声称为雪的声音。白天各地点共享Town（64秒），夜晚及结算Town 3（99秒）；0.8秒双播放器交叉淡入淡出。相同曲目不重启；四个长声音使用引擎loop。音乐不是作者明确标注的无缝曲，已验证回绕，但接缝主观听感未确认。雨作者明确提供可循环实录。

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
