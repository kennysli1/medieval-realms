# Medieval Realms · 中世纪领地（暂定名）

欧洲中世纪题材、固定斜视角 2.5D 的单机城镇经营与领土战略游戏。
玩家规划城镇，观察居民生产、搬运和生活，再通过军队探索、出征和扩张。

**当前阶段：前置开发准备。启动场景是工程入口，不是可玩原型。**

## 开始

使用 **Godot 4.7.2 Standard / GDScript** 导入根目录 `project.godot`，按 F6 运行当前场景或 F5 运行项目。无需 Node、服务器或账号。

Windows 命令行（路径含空格请加引号）：

```powershell
./scripts/check.ps1 -GodotPath '你的 Godot 控制台程序完整路径'
```

检查包含编辑器导入、基础逻辑测试和入口场景启动。GitHub Actions 使用相同引擎版本执行检查。

## 项目入口

- [产品设计与首版范围](DEV_SPEC.md)
- [画面方向与官方参考图](docs/ART_DIRECTION.md)
- [架构与数据流](docs/ARCHITECTURE.md)
- [旧项目迁移清单](docs/MIGRATION.md)
- [开发顺序与验收条件](docs/ROADMAP.md)
- [美术资产登记](assets/README.md)
- [协作约定](AGENTS.md)

目录：`scenes/` 场景、`src/core/` 基础逻辑、`data/` 新版静态定义、`assets/` 自有/授权素材、`tests/` 无界面测试、`docs/` 设计、`scripts/` 检查脚本。

本项目从 `E:\slg1.0` 的玩法经验重新设计，旧网页项目保持独立。未复制旧存档、账号或部署配置。暂未授予开源许可；第三方图片仅作为参考链接，不是游戏资源。
