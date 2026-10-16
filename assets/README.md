# 美术资产登记

已有两轮内置 image_gen 生成的透明原型图集，正式使用路径为 `assets/generated/`。第一轮：

- `buildings.png`：主堡、住宅、仓库、伐木场、锯木厂、麦田农舍。
- `citizens.png`：同一服装居民的四个行走方向，每方向四帧。
- `nature.png`：橡树、云杉、岩石、苹果树。

完整提示词、布局、生成日期与限制在 [generated/manifest.json](generated/manifest.json)。未输入第三方截图，未加入第三方游戏素材。通过 Godot 区域采样使用原图，保留生成的透明通道。

第二轮新增：`village-houses-v2.png`（三种住宅与水井）、`citizens-walk-v2.png`（四方向六帧）、`citizens-work-v2.png`（伐木、锯木、农耕各四帧）。提示词与本项目自有参考图记录见 [generated/manifest-v2.json](generated/manifest-v2.json)。

`sprite-layout-v2.json` 保存逐帧区域与脚底基点，依据透明通道测量并在 Godot 内采样；未修改生成的 PNG。不同动作不能按相同单元格机械裁切，否则会跳脚或截断工具。

这些是原型资产：动画姿势差异、脚底基点、角色款式与局部边缘仍需后续打磨。当前施工脚手架、道路、地面与工作/烟雾特效由 Godot 绘制。

每批正式素材随目录附来源记录，包含：文件、作者/生成方式、来源链接、许可全文或凭据位置、允许用途、是否修改、导出规格。购买凭据放私密存储，仓库仅登记引用。

概念图、官网截图和风格参考不等于授权资产。AI 生成概念图先校验透视/尺度/基点及风格，再加工为场景素材。建筑和人物规范见 docs/ART_DIRECTION.md。
