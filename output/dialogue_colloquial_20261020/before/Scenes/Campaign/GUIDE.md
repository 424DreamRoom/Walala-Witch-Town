# 引导角色：萤萝

新游戏流程：开场 → 萤萝欢迎对话 → 自由活动。主角默认叫薇尔莉娅，不再提供起名界面。欢迎状态由 `campaign.guide_met` 保存；已有姓名的旧档迁移为已认识，避免打断旧进度；旧档中的空名字自动补为默认名字，并保留未完成的欢迎步骤。

萤萝白天在小镇入口附近（脚底约 464,408）守灯。她不占用十位居民的好感、支线名额或餐厅顾客索引。她共享脚底碰撞和 Y 排序；居民会绕行；夜间隐藏并禁用碰撞，次日恢复。场景形象使用原生 32×32 精灵，1:1 显示且不进行小数缩放，保持统一的像素格。

对话包含当前目标、按章节开放的小镇生活话题和完成交付。她只谈当前一章；完成后讲述该章结果并引出下一目标。食材、晚餐、农场、建设、钓鱼与居民关系依次开放，未开放的话题不提前展示。十二章原有指标、奖励和区域解锁全部沿用 `Campaign.complete_chapter`。对话选项绑定当时章节，旧选项不能重复领取或连跳到下一章。手记中的完成入口也使用同一角色的结算对白。

## 新手目标与故事衔接

`onboarding.gd` 根据现有存档数据推导当前目标，不增加保存字段。前三章依次显示采集3份 → 加工3份 → 菜单1道 → 首次上菜 → 累计上菜3次 → 种植5块 → 浇水5块 → 累计收获5份。备料、菜单与农场子目标不新增奖励或交付门槛；可烹饪的库存菜单、已经上菜或已经收获的旧进度会跳过相应前置阶段。已跨日生长的田块计入农场准备进度，第一次收获后不再回退到种植目标。

自由活动时右上角显示当前目标、数量和地点；开场、模态对话与结算期间隐藏。手记“进行中”页显示当前章的问题、阶段目标与本章累计目标，避免把阶段进度误认为奖励条件。玩家可见文字只描述剧情、目标、状态与地点。

操作供开发与测试使用：森林食材经原有备料台加工；在餐厅菜单选择菜品并确认营业，按订单烹饪、上菜。农场使用蓝色法杖完成翻地和浇水，现有种子与作物选择负责播种。土地只在已浇水的跨日结算中生长。所有操作沿用原有输入，不向游戏内添加操作说明。

`story_content.py` 维护十二章48句角色对白、章前背景、章后结果、四段开场旁白与萤萝生活话题，并同时维护四语言翻译。开场只留下匿名信、星点与长桌，月环的运作原因到月晶章节才揭示。中间通过食堂、农场、水门、旧械回路、署名来信、山径邮戳和四季星图建立因果。主角与居民的姓名、头像随对白同步切换；旧档自定义姓名不会误译成同名居民。

手记“已完成”页的“回顾”重播相应章节对白，不发奖励、不改变进度，未来章节不可回顾。对白回看保留发言人，语言切换时同时重建姓名、台词和回看内容。

```powershell
python Scenes/Campaign/build_content.py
python Localization/build_catalog.py
python Scenes/Campaign/run_story_verification.py
python Scenes/Campaign/run_story_verification.py capture --suite story
```

测试使用 `output/story_onboarding/` 下的独立 APPDATA、LOCALAPPDATA、设置和存档，核对 `MyArt/` 全部文件哈希。覆盖实际采集、加工、菜单、三次烹饪上菜、五块田地的跨日收获、替代食谱、旧进度续接、所有章节与四语言排版、头像、回看和无奖励回顾；并联动原有向导、支线节奏与开场回归测试。

所有玩家对白只提供生活背景、系统事实、目标、进度与结果，不包含按键或操作教学。具体操作仅在本文说明：沿用现有 `interact` 输入与近距离脚底判定；现有 H 向导入口从各区域打开同一角色的对话。翻页、回看、退出与焦点导航继续使用原 HUD 行为，未增加输入映射。目标行保留翻译模板和参数，四语言切换时即时重建文字与回看。

开发验证：

```powershell
python Localization/build_catalog.py
python Scenes/Campaign/run_guide_verification.py import
python Scenes/Campaign/run_guide_verification.py
python Scenes/Campaign/run_guide_verification.py capture
python Scenes/Campaign/run_quest_verification.py
python Scenes/Campaign/run_opening_verification.py
```

新增验证使用 `output/guide_npc/` 下的独立设置、存档、日志及截图，不读写玩家正式设置或存档。美术和完整提示词见 `Art/Characters/Yingluo/`。
