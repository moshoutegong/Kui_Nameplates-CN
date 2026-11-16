local L = LibStub("AceLocale-3.0"):NewLocale("KuiNameplatesAuras", "zhCN", false)
if not L then return end

L["Show my auras"] = "显示我施加的光环"
L["Display auras cast by you on the current target's nameplate"] = "在当前目标的姓名板上显示由你施加的光环"
L["Show on trivial units"] = "在杂兵单位上显示"
L["Show auras on trivial (half-size, lower maximum health) nameplates."] = "在杂兵（半尺寸、最大生命值较低的）姓名板上显示光环。"
L["Behaviour"] = "行为"
L["Use whitelist"] = "使用白名单"
L["Only display spells which your class needs to keep track of for PVP or an effective DPS rotation. Most passive effects are excluded."] = "仅显示你的职业在 PVP 中或高效输出循环中需要关注的法术，绝大多数被动效果会被排除。"
L["Show others' auras"] = "显示他人施加的光环"
L["Also display auras cast by other players. Your own auras are always sorted first."] = "同时显示其他玩家施加的光环，你自己的光环始终排在最前面。"
L["Sort own auras first"] = "自己的光环排在前面"
L["Keep the auras you cast at the front of the row, followed by everyone else's."] = "让自己施加的光环排在整行最前，其后才是其他人施加的光环。"
L["Show on secondary targets"] = "在次要目标上显示"
L["Attempt to show and refresh auras on secondary targets - i.e. nameplates which do not have a visible unit frame on the default UI. Particularly useful when tanking."] = "尝试在次要目标上显示并刷新光环 —— 即在默认界面中没有对应可见单位框架的姓名板。坦克时特别有用。"
L["Display"] = "显示"
L["Pulsate auras"] = "光脉冲动"
L["Pulsate aura icons when they have less than 5 seconds remaining.\nSlightly increases memory usage."] = "当光环剩余时间不足 5 秒时让其图标脉动。\n会略微增加内存占用。"
L["Show decimal places"] = "显示小数位"
L["Show decimal places (.9 to .0) when an aura has less than one second remaining, rather than just showing 0."] = "当光环剩余时间不足 1 秒时显示小数位（.9 到 .0），而不是只显示 0。"
L["Sort auras by time remaining"] = "按剩余时间排序光环"
L["Increases memory usage."] = "会增加内存占用。"
L["Timer threshold (s)"] = "计时器阈值（秒）"
L["Timer text will be displayed on auras when their remaining length is less than or equal to this value. -1 to always display timer."] = "当光环的剩余时间小于或等于该数值时显示计时文字，设为 -1 则始终显示计时。"
L["Effect length minimum (s)"] = "效果时长下限（秒）"
L["Auras with a total duration of less than this value will never be displayed. 0 to disable."] = "总持续时间小于该数值的光环将永不显示，设为 0 可禁用此限制。"
L["Effect length maximum (s)"] = "效果时长上限（秒）"
L["Auras with a total duration greater than this value will never be displayed. -1 to disable."] = "总持续时间大于该数值的光环将永不显示，设为 -1 可禁用此限制。"
L["Size"] = "大小"
L["Aura icon size on normal frames"] = "普通框架上的光环图标大小"
L["Size (trivial)"] = "大小（杂兵）"
L["Aura icon size on trivial frames"] = "杂兵框架上的光环图标大小"
L["Squareness"] = "方正度"
L["Aura position"] = "光环位置"
L["Show aura icons above or below the health bar."] = "光环图标显示在血条上方或下方。"
L["Above health bar"] = "血条上方"
L["Below health bar"] = "血条下方"
L["X offset"] = "X 坐标微调"
L["Fine-tune the horizontal position of aura icons. Positive values move them right."] = "微调光环图标的水平位置，正值向右移动。"
L["Y offset"] = "Y 坐标微调"
L["Fine-tune the vertical position of aura icons. Positive values move them up."] = "微调光环图标的垂直位置，正值向上移动。"
L["Where 1 is completely square and .5 is completely rectangular"] = "1 表示完全正方形，0.5 表示完全长方形"

L["Edit spell list"] = "编辑法术列表"
L["Kui |cff9966ffSpell List|r"] = "Kui |cff9966ff法术列表|r"
L["Verbatim"] = "原样添加"
L["ADD_DESC "] = [[
将此名称解析为法术书中某个法术的 ID，并添加到追踪列表。
当输入文本为|cff88ff88绿色|r时，这是默认行为。
]]
L["VERBATIM_DESC"] = [[
不尝试解析为法术 ID，直接添加该法术。也就是说，追踪任何名称与之匹配的光环。
当输入文本为|cffff0088红色|r时，这是默认行为。
按住 Shift 再按回车可强制执行此操作。
]]

L["HELP_TEXT"] = [[
输入想要追踪的技能|cffffff00名称|r或|cffffff00法术 ID|r，然后按回车。
|cffffff00右键点击|r法术可将其移除或忽略。

只有当技能处于你当前可用的技能集合中（即在你专精对应的法术书页面里可见且可用）时，才能通过名称识别。你可以在对目标施加光环后，使用斜杠命令 |cffffff00/kslc dump|r 来查找光环的法术 ID。

将鼠标悬停在“添加”和“原样添加”按钮上，可查看各自作用的详细说明。
]]
