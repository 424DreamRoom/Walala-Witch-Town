# 钢琴音色

`piano_c4.wav` 至 `piano_b6.wav` 是项目内生成的 21 个单音采样，覆盖三行七列演奏面板的低、中、高三个八度。采样由 `generate_piano_samples.js` 使用正弦泛音、起音和衰减包络合成，避免依赖外部游戏或受限原稿素材。

`Scenes/Instrument/instrument_library.gd` 按列音名与行八度加载这些文件；`Sounds/Walala/audio_manager.gd` 通过效果音声部复用播放，沿用玩家的音效音量与静音设置。
