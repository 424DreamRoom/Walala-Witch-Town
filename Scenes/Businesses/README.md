# 余烬铁匠铺、橡果杂货店与榛木家具店

橡果杂货店的“今日食材”使用 `MyArt/Icon/Food/` 中面包、鸡蛋和番茄的用户原稿，分别6、4、5金。原稿只读，游戏引用 `Art/Icon/MyArt/Food/` 的原尺寸导出图；食材卡片按整数倍最近邻显示，柜台和背包使用同一组图。可购买、堆叠、转入木箱和保存。原有七项交易保留，列表使用紧凑按钮。导出规范、验证和隔离预览见 `Art/Icon/MyArt/README.md`。

两间柜台面板使用原生 12px Fusion Pixel 深色字，关闭文字阴影和阴影描边，保持细小笔画的空隙。只将阴影偏移设为零仍会留下 Godot 默认的 1px 阴影描边，导致中文笔画粘连；场景中的浅色地点名继续使用独立的阴影设置。

店主为露米（Lumi），铁匠为余烬（Ember），沿用居民资料中的身份与原创角色图集。露米站在账本柜台后，余烬站在铁砧后；两人有待机动画和脚底碰撞，角色与家具共享 Y 排序。小镇居民、店员和餐厅客人均不显示头顶姓名。姓名保留在对话、居民手记和服务面板中，支持简体中文、繁体中文、英语和日语。服务面板另显示库存、背包已用格数及金币。

居民姓名：茉莉、余烬、澪、露米、星芒、陶陶、皮普、芦苇、霜铃、奥萝。姓名来自 `Scenes/Campaign/content.gd`，不改动居民 ID、关系或存档结构。

F5 开始游戏后，沿石路进入中央月泉广场。北面带绿白条纹遮棚的是橡果杂货店；沿广场东侧道路向河边走，可找到灰瓦石墙的余烬铁匠铺。门口 27 像素内按交互键（默认 E）进屋；在室内底部台阶旁按交互键回到门外安全位置，R 回到安全出生点。靠近门口和长按按键不会自动进出，E 也用于柜台服务。

两间房屋使用 Hearthwood 调色板和原生像素尺寸：外观为 192×192，室内为 640×480。铁匠铺有石地、烟囱、四帧炉火、风箱、工具架、锻造台、铁砧、淬火桶和矿箱；商店有药剂货架、干货架、账本柜台、粮袋、食材陈列和绿色织毯。家具独立加载，使用脚底 Y 排序并参与碰撞。室内停止雨雪与天气音效，铁匠铺石地和木地使用对应脚步声。

走近铁砧或商店柜台按 E 打开服务，点击按钮交易；E / Esc 收起，走远自动关闭。柜台仅白天营业。沿用原有计时：白天结束会进入餐厅营业。

| 地点 | 服务 |
|---|---|
| 铁匠铺 | 矿石2 + 木材1 → 铁锭1；出售矿石1得3金、木材1得1金；独立的「法杖升级」「背包升级」入口，显示等级、属性前后对比和费用 |
| 杂货店 | 蘑菇、莓果、香草各3金/份；香草种子4颗/2金；出售铁锭1得8金、鱼1得4金、香草1得3金 |
| 榛木家具店 | 小空屋 → 舒适小屋：120金 + 木材30 + 铁锭3；舒适小屋 → 宽敞之家：400金 + 木材80 + 铁锭8 |

榛木家具店入口为小镇西南侧原住宅 `shop_5`，坐标 (200,636)，门牌使用椅子图案。`furniture_store.tscn` 同样复用 `business_interior.gd`，独立布局展示床、沙发、书桌和书柜，柜台由露米接待。白天靠近柜台按 E 打开扩建窗口，显示当前面积、下一等级、已有家具数量及材料价格；确认后同时扣除金币、木材和铁锭，回家即可看到扩大后的房间。材料不足、夜间、离开柜台、窗口失效或已达最大等级时均不扣款。扩建保留玩家已摆放家具和木箱内容，不赠送家具；制作、摆放入口位于家中的暂停菜单。

新游戏从无家具的小空屋开始，三个等级的地板尺寸为 192×128、320×208、512×288。旧存档保留原有完整住宅、固定设施及家具。房屋专项验证：`python Scenes/Building/run_verification.py housing`；实际截图：`python Scenes/Building/run_verification.py housing-capture`，使用进程专属存档和设置。

购买食材进入共享背包，初始容量12格，升级后依次为18、24、36格，普通物品每格最多99份；铁锭和香草种子同样进入背包，并同步采集资源及农场数量。农场收获的香草可直接在这里出售。交易直接更新共享库存与金币；材料不足、余额不足、目标物品没有可用格或堆叠空间、非营业时段或离开柜台均不会扣款或发货。资源、农田、种子、金币和装备等级跨天保留并随当前栏位存档保存。装备升级费用、效果和验证见 `Scenes/Equipment/README.md`。

`blacksmith.tscn` / `store.tscn` 由 `game_loop.gd` 装配，复用 `business_interior.gd`。库存写入集中在 `loop_state.gd`。新版小镇入口坐标分别为 (1020,556) 和 (620,376)，来自 `town_layout.json`；既有住宅、餐厅、野外和码头接入保留。

绘制源与重建：

```powershell
python Art/Environment/Hearthwood/tools/build_businesses.py
```

需要 Pillow。完整环境重建和室外重建会自动重新应用两栋房屋。素材、布局 JSON 和资源尺寸登记在 `Art/Environment/Hearthwood/`；导出时包含 `blacksmith_layout.json` 与 `store_layout.json`。

验证（支持 `--godot PATH` 或 `GODOT_BIN`）：

```powershell
python Scenes/Businesses/run_verification.py import
python Scenes/Businesses/run_verification.py headless
python Scenes/Businesses/run_verification.py capture
python Scenes/Businesses/run_verification.py home
python Scenes/Businesses/run_verification.py lane
python Scenes/Businesses/run_verification.py loop
```

专用验证通过真实物理移动与 E 输入检查进出、家具阻挡、镜头、雨声恢复和计时切换；窗口模式通过根窗口鼠标事件检查交易按钮，并保存原生画面及窗口截图。交易边界使用定向注入库存。截图与日志位于 `Art/Environment/Hearthwood/Verification/Businesses/`。

NPC 验证同时检查两位店员身份、图集、无头顶姓名、服务面板姓名、待机、碰撞及柜台可达性，覆盖购买扣款与入包、余额不足、满格拒绝、远程拒绝和夜间拒绝。验证设置和存档使用 `output/business_npcs/`，不读写正式进度。

2026-10-10 / Godot 4.7.2：建筑无窗口63项、实际1280×720窗口88项全部通过，最终日志无脚本错误或缺失资源。原住宅56项、小镇移动51项、两日经营93项回归通过。21张PNG的尺寸、透明度和炉火局部变化检查通过；17个室内家具及服务/出口接近点可达；23个资源及布局文件重建哈希一致；8组实际窗口与原生画面的最近邻放大逐像素一致。素材验证及实机总览重建：

```powershell
python Art/Environment/Hearthwood/tools/validate_businesses.py --rebuild --screens
```

实机四图总览保存为 `Art/Environment/Hearthwood/Verification/businesses_preview.png`，各画面直接拼接，不重绘场景像素。尚未进行导出包或跨平台验证。
