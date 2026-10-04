# 简账：选定的主题与图标方案

更新日期：2026-10-04。

当前交付为图像生成工具制作的视觉设计稿，不是已实现或经过性能测试的 App。

## 选定方案

- 浅色：theme-a-light-v2.png，A 暖白陶土。
- 深色：theme-c-dark-v2.png，C 深色暖灰。
- B 不作为后续开发主题；历史设计稿没有删除。
- 保留总览、账单、分析和记账面板四页布局。

## 本次调整

- 总览页右上角增加主题按钮，与“简账”标题同一行。浅色显示月亮，深色显示太阳；设计意图为点击后在 A/C 间切换。
- 消费分类、最近账单、账单明细及记账分类选择器统一采用无底圈、无彩色底块的单色线条图标。
- 浅色图标为深炭灰，深色图标为暖白；保持统一线宽和大小。
- 分类选中态用文字下方的陶土色短线表达，图标本身仍保持统一颜色。
- 图表及其图例保留分类颜色；它们不是消费项目图标。
- 参考用户提供的 Claude Settings 截图，仅参考图标样式，不引入该设置页的功能。

## 生成方式与最终提示词

使用内置 image_gen 编辑模式。每套的第一张输入为上一版 A 或 C 四页设计图，第二张输入为用户提供的 Claude Settings 截图。原图与参考图保留在原路径，未覆盖。

### 两套共用提示词

```text
Use case: precise-object-edit / ui-mockup.
Image 1 is the EDIT TARGET: an existing four-screen board of the Chinese expense app 简账. Image 2 is a STYLE REFERENCE ONLY for category icons: the supplied Claude settings screenshot with bare monochrome outlined icons, no enclosing colored disks. Do not reproduce the reference settings page or add its settings content.
Make only the following requested design revisions:
1. On the FIRST phone (总览 home screen), add a small, clearly visible theme-switch icon at the upper-right of the actual app header, horizontally aligned with "简账", below the Android status bar and above the date/period row. The button has a spacious invisible touch area and NO circular/colored background. It must not replace the calendar or date controls. It toggles the two retained themes. Also show the same icon in the dimmed home header behind the fourth phone's entry modal.
2. Throughout ALL phones, redraw all category/project pictograms in a consistent bare single-color thin-outline style matching image 2. Absolutely remove the enclosing circles, disks, colored backgrounds, filled tiles, badges, icon shadows and colorful glyphs around breakfast/lunch utensils, coffee cup, subway, shopping, salary. Keep intrinsic object shapes only. This MUST be done in both the home recent transactions and the ledger list.
3. In the fourth phone's category picker, retain the two-row four-column layout but REMOVE ALL rounded-square category tiles, outlines, colored backgrounds and filled selection blocks. Show only each bare monochrome line icon with its existing text beneath it. All eight icon glyphs MUST have exactly the same neutral stroke color and weight, including the selected 餐饮 icon. Indicate the selected category using a short terracotta underline beneath its text, not a background and not a different icon color. Leave the numeric keypad buttons, saving action, type segmented control and content cards intact.
4. Keep line-icon shape language consistent: outlined fork/spoon, coffee cup, subway front, shopping bag/cart, home, controller, medical cross, open book, wallet/briefcase, ellipsis; about 24dp visual size, around 1.8–2dp rounded stroke with open negative space. All category icons share the same monochrome color within each theme. Do NOT apply this rule to category chart segments or their legend dots, since those must remain distinguishable.
Invariants: keep the same four complete Android phones, same order (总览,账单,分析,记一笔), same board aspect, all financial figures, Chinese text, section placement, chart containers, bottom navigation, buttons, fonts and the original theme palette. No new features or decorations. Do NOT redesign layout. Do not render icon badges under any category pictogram. All phones fully visible, original sharp legible typography, no watermark.
Preserve exact key values: monthly expense ¥2,846.50, income ¥8,500.00, balance ¥5,653.50, budget remaining ¥1,153.50, ledger salary +¥8,500.00, entry ¥32.00. Board is an updated design preview with sample data.
```

### A 追加提示词

```text
This is retained LIGHT THEME A. Preserve its warm off-white, light stone and terracotta. All category pictograms must be the SAME dark charcoal #393733, never orange, blue, red or green. Top-right home theme switch is a dark charcoal crescent MOON outline, matching the 'Color mode' crescent in image 2, without any circle, pill or tile behind it. Main board title remains '方案 A · 暖白陶土'. Change the small top subtitle to '主题切换 · 单色线性图标'. Keep all original content otherwise.
```

### C 追加提示词

```text
This is retained DARK THEME C. Preserve its warm charcoal, ivory text and soft terracotta. All category pictograms must be the SAME light warm ivory #E5DED3, never orange, yellow, green or blue. Top-right home theme switch is a warm ivory SUN outline (small central sun with rays, no enclosing badge), the dark-mode companion of the simple outline icon reference. Main board title remains '方案 C · 深色暖灰'. Change the small top subtitle to '主题切换 · 单色线性图标'. Keep all original content otherwise.
```
