# 居民动作图集

由 `tools/bake_residents.gd` 在 Godot 4.7.2 的透明 SubViewport 中原生渲染 Quaternius CC0 骨骼模型。原始来源和许可见 `assets/third_party/README.md`。四个 PNG 为 768×3136，每格 96×112：8 帧 × 4 方向 × 7 动作。

动作顺序：idle / walk / carry / run / wave / work / chop。对应源片段 Idle_Neutral / Walk / Walk / Run / Wave / Interact / Sword_Slash。搬运将 Walk 腿部与 Interact 的手臂姿势合成；劈砍使用无武器骨骼动作，并在游戏内附加斧头。work 是通用操作动作，农具和锯木仍需后续专用动画打磨。原始模型附带的其他动画未接入游戏。

统一正交等距相机、暖色光、脚底投影基点，移除源动画的水平根位移；`atlas.json` 保存每帧双手投影点，使货物/工具随动作移动。运行时按居民 appearance 选择固定模型，不因职业或工作状态换人。

重新生成（需图形渲染环境，不能使用 --headless）：

```powershell
& '你的 Godot 控制台路径' --path . --script res://tools/bake_residents.gd
& '你的 Godot 控制台路径' --headless --editor --path . --import
& '你的 Godot 控制台路径' --path . --script res://tools/preview_residents.gd
```

`preview_residents.gd` 直接绘制游戏使用的动作格，保存 `docs/screenshots/resident-actions.png`；不是概念效果图。货物和工作工具在实际游戏中叠加，预览仅展示身体姿态。
