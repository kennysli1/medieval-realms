# 工程架构提案

## 表现与模拟分离

`Control UI / Node2D 表现 → 玩家指令 → 纯 GDScript 模拟状态 → 事件/快照 → 表现刷新`。

模拟类优先继承 RefCounted，无界面可运行。先使用明确的类与数据，不提前建立 ECS、全局消息总线或大批 Autoload。

## 模块责任与顺序

- core：游戏时钟、坐标变换、seed；已建立时钟和投影基础。
- city：地格占用、建筑、道路可达性；尚未实现。
- economy：库存、预留、配方和加工任务；尚未实现。
- citizens：岗位、任务状态机与运输；尚未实现。
- world：六边形地形、探索、行军；尚未实现。
- military：训练、兵力、补给与战斗；尚未实现。
- persistence：版本化序列化与备份；尚未实现。

居民基础状态：待业→前往岗位→工作→取货→运输→交付；任务不可达则暂停并显示原因，重算任务不复制货物。住宅、岗位和运输任务用稳定 ID 关联，表现节点不作为存档引用。

经济例子：指令申请建设→库存预留材料→运输领取→工地交付→施工消耗→完工事件。仓库只增加已交付资源，动画到达不能单独生成资源。

## 地图与寻路

城镇用整数格坐标，投影单独转换，不能将屏幕像素作为模拟位置。基础投影为 `x=(gx-gy)*64, y=(gx+gy)*32`。建筑与人物基点按 Y 排序，大体量建筑遮挡需单独试验分层/透明策略。

首版拟使用 AStarGrid2D 处理道路和建筑障碍；入口/货物交接点明确，不给每个居民每帧重新寻路。道路改动递增路网版本，按需失效路径。装饰避让不影响逻辑可达性。

世界地图使用轴向六边形坐标，与城镇坐标类型分离。两张地图推进同一游戏时钟，切场景不销毁模拟状态。

## 运行与性能

建议固定模拟步长 0.1 秒，表现按帧插值；不同速度累积模拟时间而不是改变移动动画帧率。第一版基准：64×64 城镇、100 个居民，1080p 目标 60 fps；此为待验证目标，须记录硬件与 profiler，不宣称已达标。

居民从 20 人起验证；需求调度按批次执行。超过数百居民后再根据测量考虑分区更新或集群模拟。

## 存档契约

顶层含 schema_version、simulation_time、seed、rng_state、city、citizens、inventory、world、armies。加载到临时状态完成校验，再替换当前世界。文件放 user://saves；不要提交真实用户存档。

## 官方技术依据

- [Godot 2D 导航对象](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_2d.html)
- [AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html)
- [TileMapLayer 与 Y 排序](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html)

链接的 stable 文档随上游变化，实际以仓库固定的 4.7.2 引擎导入和运行结果为准。
