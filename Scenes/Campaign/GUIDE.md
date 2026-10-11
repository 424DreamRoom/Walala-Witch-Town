# 引导角色：萤萝

新游戏流程：开场 → 萤萝欢迎对话 → 自由活动。主角默认叫薇尔莉娅，不再提供起名界面。欢迎状态由 `campaign.guide_met` 保存；已有姓名的旧档迁移为已认识，避免打断旧进度；旧档中的空名字自动补为默认名字，并保留未完成的欢迎步骤。

萤萝白天在小镇入口附近（脚底约 464,408）守灯。她不占用十位居民的好感、支线名额或餐厅顾客索引。她共享脚底碰撞和 Y 排序；居民会绕行；夜间隐藏并禁用碰撞，次日恢复。场景形象使用原生 32×32 精灵，1:1 显示且不进行小数缩放，保持统一的像素格。

对话包含当前目标、按章节开放的小镇生活话题和完成交付。她只谈当前一章；完成后讲述该章结果并引出下一目标。食材、晚餐、农场、建设、钓鱼与居民关系依次开放，未开放的话题不提前展示。十二章原有指标、奖励和区域解锁全部沿用 `Campaign.complete_chapter`。对话选项绑定当时章节，旧选项不能重复领取或连跳到下一章。手记中的完成入口也使用同一角色的结算对白。

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
