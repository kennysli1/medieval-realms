# 第三方素材登记

获取日期：2026-10-16。所有文件随仓库提供，运行和烘焙均不联网。CC0 资源的授权独立于本项目代码。

## 地表材质：Poly Haven

[官方许可](https://polyhaven.com/license)：CC0。未使用参考游戏的截图。

- [Cobblestone Floor 08](https://polyhaven.com/a/cobblestone_floor_08)：`polyhaven/cobblestone_floor_08.jpg`，Rob Tuytel，1K diffuse。
- [Brown Mud Dry](https://polyhaven.com/a/brown_mud_dry)：`polyhaven/brown_mud_dry.jpg`，1K diffuse。
- [Aerial Grass Rock](https://polyhaven.com/a/aerial_grass_rock)：`polyhaven/aerial_grass_rock.jpg`，1K diffuse。

各文件旁 JSON 保存作者、官方 API 下载地址、原始哈希与许可。原图未编辑；Godot 地面 shader 统一等距 UV，调整配色、混合边缘，按真实四邻接路网合并直线、转角和交叉口。中心广场是装饰铺面，通行仍走道路格并绕开水井。

## 人物：Quaternius

[Ultimate Modular Men](https://quaternius.com/packs/ultimatemodularcharacters.html)、[Ultimate Modular Women](https://quaternius.com/packs/ultimatemodularwomen.html)，作者 Quaternius，官方标注 CC0。

`quaternius/manifest.json` 保存四个嵌入式 glTF 的作者公开 Drive 下载地址与 SHA-256；`quaternius/LICENSE.txt` 为作者包内许可。模型分别为 Farmer、Medieval Woman、Adventurer Man、Adventurer Woman，保留源骨骼与动画。居民烘焙时隐藏女村民自带的剑，工具在游戏内按职业绘制。

游戏实际使用 `assets/baked/residents/` 精灵图集；源 glTF 只用于重新烘焙。运行时仍为轻量 2D 等距场景。骨骼烘焙方法见 [烘焙说明](../baked/residents/README.md)。
