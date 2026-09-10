-- ============================================================================
-- Tool: Eye Controller (Test mode)
-- Left Click  : Select a ragdoll (resets angles to 0)
-- Right Click : Rotate eyes by +5° in the current mode (Horizontal / Vertical)
-- Reload      : Switch mode between Horizontal and Vertical
-- ============================================================================

TOOL.Name = "Eye Controller"
TOOL.Category = "Fun"
TOOL.Command = nil
TOOL.ClientConVar = {}

-- 存储每个布娃娃的当前水平角（hor）和垂直角（ver），单位：弧度
local ragdollAngles = {}

-- 当前选中的布娃娃
local selectedRagdoll = nil

-- 当前模式："horizontal" 或 "vertical"
local currentMode = "horizontal"

-- 模式名称显示
local modeNames = {
    horizontal = "Horizontal (Yaw)",
    vertical   = "Vertical (Pitch)",
}

-- ============================================================================
-- 纯函数：根据水平和垂直角度计算方向向量，并设置眼睛目标
-- 完全忠于 death_face.lua 中的 SetEyeDirection_EyeTarget 实现
-- ============================================================================
local function SetEyeDirection_EyeTarget(ragdoll, hor, ver)
    local cosV = math.cos(ver)
    local dir = Vector(
        math.cos(hor) * cosV,
        math.sin(hor) * cosV,
        math.sin(ver)
    )
    local eyesID = ragdoll:LookupAttachment("eyes")
    if not eyesID or eyesID == 0 then return false end
    local attach = ragdoll:GetAttachment(eyesID)
    if not attach then return false end
    -- 直接传入 dir * 200，与 death_face 完全一致
    ragdoll:SetEyeTarget(dir * 200)
    return true
end

-- ============================================================================
-- TOOL 方法
-- ============================================================================

-- 左键：选择布娃娃，重置其角度为 0
function TOOL:LeftClick(trace)
    if not trace.Entity or not trace.Entity:IsValid() then return false end
    local ent = trace.Entity
    if ent:IsRagdoll() then
        selectedRagdoll = ent
        ragdollAngles[ent] = { hor = 0, ver = 0 }
        print("[Eye Controller] Selected ragdoll: " .. tostring(ent) ..
            " | Mode: " .. modeNames[currentMode] ..
            " | Angles reset to 0")
        return true
    else
        print("[Eye Controller] Target is not a ragdoll.")
        return false
    end
end

-- 右键：根据当前模式增加角度 5°，然后应用
function TOOL:RightClick(trace)
    if not selectedRagdoll or not selectedRagdoll:IsValid() then
        print("[Eye Controller] No ragdoll selected. Use Left Click to select one.")
        return false
    end

    local ragdoll = selectedRagdoll
    local angles = ragdollAngles[ragdoll]
    if not angles then
        -- 若未初始化，重置
        angles = { hor = 0, ver = 0 }
        ragdollAngles[ragdoll] = angles
    end

    local delta = math.rad(5) -- 5° 转弧度
    if currentMode == "horizontal" then
        angles.hor = angles.hor + delta
    else
        angles.ver = angles.ver + delta
    end

    -- 应用新的角度
    SetEyeDirection_EyeTarget(ragdoll, angles.hor, angles.ver)

    -- 打印当前角度（便于调试）
    print(string.format("[Eye Controller] %s: hor=%.2f°, ver=%.2f°",
        modeNames[currentMode],
        math.deg(angles.hor),
        math.deg(angles.ver)
    ))

    return true
end

-- 换弹键：切换模式
function TOOL:Reload()
    if currentMode == "horizontal" then
        currentMode = "vertical"
    else
        currentMode = "horizontal"
    end
    print("[Eye Controller] Switched to mode: " .. modeNames[currentMode])
    return true
end

-- 每帧清理无效的布娃娃
function TOOL:Think()
    if selectedRagdoll and not selectedRagdoll:IsValid() then
        selectedRagdoll = nil
        ragdollAngles = {}
    end
    -- 清理无效的键
    for ragdoll, _ in pairs(ragdollAngles) do
        if not ragdoll:IsValid() then
            ragdollAngles[ragdoll] = nil
        end
    end
end

-- 本地化工具名称（客户端显示）
if CLIENT then
    language.Add("Tool.eye_controller.name", "Eye Controller")
    language.Add("Tool.eye_controller.desc", "Left: select ragdoll, Right: rotate eyes +5°, Reload: switch H/V")
end
