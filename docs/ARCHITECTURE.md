# 工程架构提案

## 表现与模拟分离

`Control UI / Node2D 表现 → 玩家指令 → 纯 GDScript 模拟状态 → 事件/快照 → 表现刷新`。

模拟类优先继承 RefCounted，无界面可运行。先使用明确的类与数据，不提前建立 ECS、全局消息总线或大批 Autoload。

## 模块责任与顺序

- core：游戏时钟、坐标变换、seed；已建立时钟和投影基础。
- city/economy/citizens：首版集中于 `src/city/city_simulation.gd`，拥有地格、建筑、路网、库存、建材预留、岗位与运输状态；原型规模稳定后再按职责拆分，避免跨文件共享可变字典。
- definitions：`src/city/building_catalog.gd` 定义六种建筑、成本与描述。
- presentation：`city_view.gd` 绘制场景，`city_controller.gd` 处理 UI 和玩家指令；不直接决定库存变化。
- art：`town_art.gd` 统一住宅变体、贴图区域、行走/工作帧和脚底基点；表现层按距离播放步态，渲染位置分道及工作站偏移不改变模拟道路与货物交付。
- world：六边形地形、探索、行军；尚未实现。
- military：训练、兵力、补给与战斗；尚未实现。
- persistence：`city_save.gd` 实现 JSON schema=1、写入临时文件并校验、备份与替换；读取失败保留当前城镇，可用 `.bak` 恢复。

居民基础状态：待业→前往岗位→工作→取货→运输→交付；任务不可达则暂停并显示原因，重算任务不复制货物。住宅、岗位和运输任务用稳定 ID 关联，表现节点不作为存档引用。

经济例子：指令申请建设→库存预留材料→运输领取→工地交付→施工消耗→完工事件。仓库只增加已交付资源，动画到达不能单独生成资源。

## 地图与寻路

城镇用整数格坐标，投影单独转换，不能将屏幕像素作为模拟位置。基础投影为 `x=(gx-gy)*64, y=(gx+gy)*32`。建筑与人物基点按 Y 排序，大体量建筑遮挡需单独试验分层/透明策略。

首版使用 AStarGrid2D 处理道路和建筑障碍；入口/货物交接点明确，不给每个居民每帧重新寻路。道路改动递增路网版本并失效行走路径，阻断任务每游戏秒重试。装饰避让不影响逻辑可达性。

世界地图使用轴向六边形坐标，与城镇坐标类型分离。两张地图推进同一游戏时钟，切场景不销毁模拟状态。

## 运行与性能

已使用固定模拟步长 0.1 秒，人物表现位置在帧间平滑追随模拟位置。地面/路面绘制命令缓存，路网或网格显示改变时重建；自然物可见性在建筑/道路变化时重算。当前原型为 32×32 城镇、20 人；扩展到 64×64/100 人留待性能测试。1080p 60 fps 为后续目标，不宣称已达标。

居民从 20 人起验证；需求调度按批次执行。超过数百居民后再根据测量考虑分区更新或集群模拟。

## 存档契约

schema=1 顶层含 schema_version、time、seed、rng_state、next_id、deliveries、meal_timer、buildings、roads、citizens、inventory。world/armies 未实现，不写空占位。向量显式编码，RNG 64 位状态用字符串保存；JSON 整数恢复成整型，避免库存类型漂移。加载到临时状态完成校验，再替换当前世界。文件放 user://saves；不要提交真实用户存档。

视觉第二轮增加可选 `layout_version`（缺失时按旧布局1），新游戏为2；住宅可选 `variant` 缺失时由稳定 ID 决定。旧存档仍为 schema=1，加载不改建筑或路网。`appearance_revision` 是不落盘的渲染缓存失效标记。

## 官方技术依据

- [Godot 2D 导航对象](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_2d.html)
- [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html)
- [TileMapLayer 与 Y 排序](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html)

链接的 stable 文档随上游变化，实际以仓库固定的 4.7.2 引擎导入和运行结果为准。
