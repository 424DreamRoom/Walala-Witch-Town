# 天气与脚步音效

运行游戏并进入小镇，WASD/方向键走路，Shift 跑步。1 晴天、2 雨天、3 雪天。右下「声音 / 鸣谢」里的音效/环境滑条和静音同时控制天气、脚步与交互音效；使用现有的声音设置保存。

雨天复用 Ylmir 的 rain.ogg 可循环录音，雪天复用 IgnasD 的 wind.ogg 风声。环境音效分类和全局音量共同控制天气声；进入家、餐厅、铁匠铺或商店立即停止室外环境声，回到户外根据当前天气恢复。晴天和结算时不播放天气环境声。

2026-10-11 修复雪天风声几乎无声的问题：原素材整段平均约 −37.2 dBFS，旧的额外 −24 dB 衰减叠加默认环境音量 35% 后，输出约 −70.3 dBFS。`audio_manager.gd` 的 `AMBIENT_GAIN_DB` 现在按素材分别校准：雨声 −12 dB，风声 +6 dB。默认风声输出约 −40.3 dBFS，与雨声约 −43.4 dBFS 接近，并保留最大音量的峰值余量。音频素材字节、声音设置默认值和保存格式不变。

脚步来自 TinyWorlds 的木地板/石头/树叶/泥地包及 Corsica_S 的雪地录音，共新增 13 个文件、271,271 字节。木地板 3 个变体、草地 2 个、雪地 6 个，连续不重复同一变体；石头和泥地各 1 个。草地使用树叶沙沙声、土路使用泥地声。小镇铺砖、建筑门前小路、草地、土质地块，野外道路和码头木板按当前绘图几何匹配。家、餐厅和商店使用木地板声，铁匠铺石砖区使用石路声，其余为木地板；下雪时户外使用雪地脚步。

`lantern_lane.gd` 只在 `move_and_slide()` 后发出本次实际位移信号。GameLoop 选择地面材质，AudioManager 按步幅触发声音：走路约每 20 像素一声，跑步约每 21.54 像素一声，对应现有动画每两帧一次落脚。碰墙无实际移动、站立和采集锁定时不产生新脚步；瞬移距离不计入步幅。短尾音正常播完，场景切换、结算、静音或音量归零会停止脚步声。

脚步有 2 个独立复用声部，不占原有 8 个交互声部；轻微随机音高减少重复感。相对音效滑条，走路另减 10 dB、跑步另减 8 dB。材质映射在 `footstep_surfaces.gd`，音量与步幅在 `audio_manager.gd`。

两个新增素材包均为 CC0，允许商用、修改，无强制署名。来源页与包内 readme 保存在 Licenses，原包在 Archives。逐文件作者、下载地址、原始及选用 SHA-256、转换记录在 manifest.json，游戏内鸣谢同步更新。

- 普通脚步：https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud
- 雪地脚步：https://opengameart.org/content/42-snow-and-gravel-footsteps
- 许可：https://creativecommons.org/publicdomain/zero/1.0/

7 个普通脚步保留原始 OGG 字节。6 个雪地 FLAC 转为单声道 PCM16 WAV，去除前导空白，最长 0.38 秒，峰值调整到 0.55，首尾淡化 3/15 毫秒。`prepare_footsteps.py --sndfile DLL路径` 可从本地原包重建，转换时需要 7-Zip 和 libsndfile；游戏运行不需要它们或网络。

验证入口：

```powershell
python Sounds/Walala/run_weather_footsteps.py headless
python Sounds/Walala/run_weather_footsteps.py audio
```

audio 模式使用无窗口显示驱动与 WASAPI 声卡驱动。验证包含 13 个音效非零 PCM 解码、地面映射、实际移动/跑步、顶墙与瞬移不误响、雨雪与室内切换、交互声部共存、音量/静音、结算清理。雪天另检查完整风声解码后的默认输出响度、与雨声/音乐的相对响度、最大音量峰值余量、播放连续性和结尾循环。测试显式进入小镇，兼容当前新游戏从家中开始的流程；使用单独的设置和存档路径，退出时删除测试设置，不改用户已保存的音量或进度。日志保存在 output/weather_footsteps_headless.log 和 output/weather_footsteps_audio.log。自动解码和驱动播放检查不代替耳机试听；尚未验证导出包。

本次另用独立 AudioManager 和临时音频捕获总线验证实际 WASAPI 混音输出：平均 −40.4 dBFS，峰值 −23.8 dBFS；24 项雪天播放、循环、分类静音与场景上下文检查全部通过，日志为 `output/snow_output_wasapi.log`。五分类声音设置 Dummy/WASAPI 回归各 75 项通过。完整场景回归两种驱动的 80 项断言均通过；共享工作区同时发生房屋和家具店相关变更，最后一次运行另有 `Scenes/Save/save_menu.gd:111` 的类型推断编译错误和 `outdoor_sign_furniture_store.png` 加载错误，因此不能将完整场景回归记为无错误通过。

2026-10-10 验证结果：Dummy 和 WASAPI 两种驱动各 61 项通过，无脚本错误。原经营回归 93 项断言通过；原脚本直接退出时留下活动场景并提示资源仍在使用，以仅补齐 `lane.queue_free()` 和等待释放的临时副本复核后，退出也无资源错误。副本未改断言或游戏逻辑，运行后已删除；结果见 output/weather_footsteps_gameplay.log。23 个清单文件的 SHA-256 全部匹配。
