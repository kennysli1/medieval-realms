# 二维居民与战斗动作样片

2026-10-19，内置 imagegen 生成的原创二维素材，无开罗游戏或其他第三方游戏图片输入。完整提示词在 `manifest.json` 和 `resident-spaced-prompt.txt`。后者以第一张原创居民图为角色参考重新生成，增加工具周围留白。

- `resident.png`：首版六列三行；运行时仅使用第一行的走路帧。其他行存在工具跨格与邻帧接近的问题，不采用。
- `resident-spaced.png`：四列三行，使用搬木和挥斧两行动作。
- `knight.png`：四列三行，走路、挥剑、格挡/受击；红方通过运行时蓝色衣盾换色获得。
- `yard.png`：固定的二维背景插画，用于检查角色动作与场景尺度；尚未拆成可建造的模块。

原始 PNG 未编辑。`tools/measure_pixel_proof.gd` 按连通透明轮廓测量完整帧，而不是机械等分裁掉武器；从鞋子的像素计算落脚锚点，将结果写入 `frames.json`。运行时仅采样原图，统一角色高度；像素透明边缘用 shader 阈值处理。动作不是移动一张静态图片，手臂、腿、武器、受击姿势来自不同帧；移动、时序、换色和少量命中特效由 Godot 控制。

这是有限方向、有限帧数的可行性样片，仍有逐帧体积/步态差异，不能当成已经完成量产的资产管线。没有经济结算、寻路、伤害结算或复杂战斗 AI。

运行：根目录 `watch-resident-2d.bat` / `watch-battle-2d.bat`；空格暂停、R 重播、1/2 切换。

重新测量：Godot `--headless --path . --script res://tools/measure_pixel_proof.gd`。
录制：运行对应场景并传入 `-- --pixel-frames=绝对输出目录 --pixel-count=240`（居民 12 秒）或 200（战斗 10 秒）。每秒 20 帧固定模拟；导出图片位于忽略的 exports 目录，再用 FFmpeg 转为 GIF/MP4。视频渲染耗时不是游戏实际帧率。
