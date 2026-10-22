# 角色对白音效

来源：[Super Dialogue Audio Pack v1 — Dillon Becker](https://dillonbecker.itch.io/sdap)。作者页面与包内许可证均允许免费商用和改编，采用 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，需要署名、许可链接与改编说明。`LICENSE.txt` 随导出保留，游戏鸣谢显示作者、素材包和许可链接。

从五位演员各选三段无明确语言的 Hm? / Hmm... / Huh?，转换成 15 个约 125 毫秒的对白短音节。不是完整台词配音。原文件在 `Originals/`，原始授权与参考表在 `Licenses/`；逐文件来源、原包成员、原始及转换后 SHA-256、裁切位置与增益在 `manifest.json`。

`dialogue_audio_library.gd` 按头像资源 ID 为主角、向导与十位居民分配音色和音高；不依赖显示姓名或当前语言。新增角色可扩展 `PROFILES`，单句字典可用 `voice` 指定 ID 或用空字符串静音。对白逐字显示时播放，每帧最多触发一次，音频层限制至少 125 毫秒间隔，并避免连续重复同一片段。空白、常用标点和富文本标签不触发声音。立即显示全文时保持安静；补全当前句、翻页、关闭、回看或换语言会停止残留声音。回看期间暂停打字。

声音通过现有 FMOD 播放，受主音量、角色音量和效果静音控制，对话暂停世界时仍可播放。不受界面或环境音量影响。旧 `voice_a.wav` / `voice_b.wav` 保留为历史素材，已不加载。运行时无需联网。

重建选用文件（只写本目录，原始文件不同则拒绝覆盖）：

```powershell
python Sounds/Walala/Dialogue/prepare_dialogue_audio.py "Super Dialogue Audio Pack v1.zip"
```

验证与隔离导入：

```powershell
python Sounds/Walala/Dialogue/run_verification.py
```

检查素材哈希、PCM、角色映射、FMOD 实际通道、逐字播放、跳过、回看、语言切换、静音与音量隔离。测试设置和存档在 `output/dialogue_audio_20261022/`，导入只处理独立临时项目的选用 WAV，保护 `MyArt/`。
