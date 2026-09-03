-- lua/edae/player_proxy.lua
-- 玩家代理：捕获玩家输入（A/D 旋转、E 键自救），通过服务器端转发给播放协调器或门面
-- 服务器端：
--   - 旋转请求直接调用 PlaybackCoordinator:RotateBy
--   - 自救开始/取消调用 RagdollManager:RequestSelfRevive / CancelSelfRevive
-- 客户端：
--   - 死亡状态下检测 A/D 键累积旋转角度，定期发送给服务器
--   - 检测 E 键按下/松开，发送自救开始/取消消息

local MODULE_NAME = "PlayerProxy"

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
if _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants         = include("edae/config/constants.lua")
local NET_STRING_ROTATE = Constants.NETWORK_STRING.PlayerRotateRagdoll
local NET_STRING_START  = Constants.NETWORK_STRING.PlayerSelfRevive_Start
local NET_STRING_CANCEL = Constants.NETWORK_STRING.PlayerSelfRevive_Cancel

local PlayerProxy       = {}

if SERVER then
    -- 服务器端：引入依赖
    local PlaybackCoordinator = include("edae/rm/playback_coordinator.lua")
    local RagdollManager      = include("edae/rm/ragdoll_manager.lua")

    -- 接收旋转请求
    net.Receive(NET_STRING_ROTATE, function(len, ply)
        if not IsValid(ply) or ply:Alive() then return end
        local ragdoll = ply:GetRagdollEntity()
        if not IsValid(ragdoll) then return end

        local deltaYaw = net.ReadFloat()
        local maxTurnSpeed = 30 -- 可配置，暂固定
        PlaybackCoordinator:RotateBy(ragdoll, deltaYaw, maxTurnSpeed)
    end)

    -- 接收自救开始
    net.Receive(NET_STRING_START, function(len, ply)
        if not IsValid(ply) then return end
        RagdollManager:RequestSelfRevive(ply)
    end)

    -- 接收自救取消
    net.Receive(NET_STRING_CANCEL, function(len, ply)
        if not IsValid(ply) then return end
        RagdollManager:CancelSelfRevive(ply)
    end)
else
    -- 客户端：检测输入
    local turnSpeed = 15      -- 旋转速度（度/秒）
    local sendInterval = 0.05 -- 发送间隔（秒）
    local accumulatedDelta = 0
    local lastSendTime = 0
    local lastUseKeyDown = false

    -- 玩家重生时重置状态
    hook.Add("PlayerSpawn", MODULE_NAME .. "_PlayerSpawn", function(ply)
        if ply == LocalPlayer() then
            accumulatedDelta = 0
            lastSendTime = 0
            lastUseKeyDown = false
        end
    end)

    -- 每帧检测输入
    hook.Add("CreateMove", MODULE_NAME .. "_CreateMove", function(cmd)
        local ply = LocalPlayer()
        if not IsValid(ply) or ply:Alive() then
            lastUseKeyDown = false
            return
        end

        local ragdoll = ply:GetRagdollEntity()
        if not IsValid(ragdoll) then
            lastUseKeyDown = false
            return
        end

        -- A/D 旋转
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

        local now = CurTime()
        if now - lastSendTime >= sendInterval and math.abs(accumulatedDelta) > 0.01 then
            net.Start(NET_STRING_ROTATE)
            net.WriteFloat(accumulatedDelta)
            net.SendToServer()
            accumulatedDelta = 0
            lastSendTime = now
        end

        -- E 键自救（按下/松开检测）
        local useDown = cmd:KeyDown(IN_USE)
        if useDown and not lastUseKeyDown then
            -- 按下瞬间：请求开始自救
            net.Start(NET_STRING_START)
            net.SendToServer()
        elseif not useDown and lastUseKeyDown then
            -- 松开瞬间：请求取消自救
            net.Start(NET_STRING_CANCEL)
            net.SendToServer()
        end
        lastUseKeyDown = useDown
    end)
end

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = PlayerProxy
return PlayerProxy
