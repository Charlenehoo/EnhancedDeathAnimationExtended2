-- lua/edae/pp/player_proxy.lua
-- 玩家代理模块：玩家死亡后，通过 A/D 键控制布娃娃旋转
-- 客户端发送增量旋转请求，服务器接收并应用

local MODULE_NAME = "PlayerProxy"
if _EnhancedDeathAnimationExtendedSingletons and _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants = include("edae/config/constants.lua")
local NET_STRING = Constants.NETWORK_STRING.PlayerRotateRagdoll

local PlayerProxy = {}

if SERVER then
    -- 服务器端：接收旋转请求并调用 AnimationPlayer
    local AnimationPlayer = include("edae/ap/animation_player.lua")

    net.Receive(NET_STRING, function(len, ply)
        if not IsValid(ply) or ply:Alive() then return end
        local ragdoll = ply:GetRagdollEntity()
        if not IsValid(ragdoll) then return end

        local deltaYaw = net.ReadFloat()
        -- 最大转向速度（度/秒），可根据需要调整
        local maxTurnSpeed = 30

        AnimationPlayer:RotateBy(ragdoll, deltaYaw, maxTurnSpeed)
    end)
else
    -- 客户端端：检测 A/D 键并发送增量
    local turnSpeed = 15       -- 转向速度（度/秒），影响 A/D 键灵敏度
    local sendInterval = 0.05  -- 网络发送间隔（秒）
    local accumulatedDelta = 0 -- 累积的旋转增量
    local lastSendTime = 0

    hook.Add("CreateMove", "EDAE_PlayerProxy_CreateMove", function(cmd)
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:Alive() then return end
        local ragdoll = ply:GetRagdollEntity()
        if not IsValid(ragdoll) then return end

        -- 计算本帧增量
        local delta = 0
        if cmd:KeyDown(IN_MOVELEFT) then
            delta = delta + turnSpeed * FrameTime()
        end
        if cmd:KeyDown(IN_MOVERIGHT) then
            delta = delta - turnSpeed * FrameTime()
        end

        if delta ~= 0 then
            accumulatedDelta = accumulatedDelta + delta
        end

        -- 按间隔发送累积增量
        local now = CurTime()
        if now - lastSendTime >= sendInterval and math.abs(accumulatedDelta) > 0.01 then
            net.Start(NET_STRING)
            net.WriteFloat(accumulatedDelta)
            net.SendToServer()
            accumulatedDelta = 0
            lastSendTime = now
        end
    end)
end

-- 注册单例（避免重复加载）
_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = PlayerProxy
return PlayerProxy
