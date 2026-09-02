-- lua/edae/pp/player_proxy.lua
local MODULE_NAME = "PlayerProxy"
if _EnhancedDeathAnimationExtendedSingletons and _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] then
    return _EnhancedDeathAnimationExtendedSingletons[MODULE_NAME]
end

local Constants         = include("edae/config/constants.lua")
local NET_STRING_ROTATE = Constants.NETWORK_STRING.PlayerRotateRagdoll
local NET_STRING_START  = Constants.NETWORK_STRING.PlayerSelfRevive_Start
local NET_STRING_CANCEL = Constants.NETWORK_STRING.PlayerSelfRevive_Cancel

local PlayerProxy       = {}

if SERVER then
    -- 服务器端：接收旋转请求
    local AnimationPlayer = include("edae/ap/animation_player.lua")

    net.Receive(NET_STRING_ROTATE, function(len, ply)
        if not IsValid(ply) or ply:Alive() then return end
        local ragdoll = ply:GetRagdollEntity()
        if not IsValid(ragdoll) then return end

        local deltaYaw = net.ReadFloat()
        local maxTurnSpeed = 30
        AnimationPlayer:RotateBy(ragdoll, deltaYaw, maxTurnSpeed)
    end)

    -- 服务器端：接收自救开始/取消
    local RagdollManager = include("edae/rm/ragdoll_manager.lua")

    net.Receive(NET_STRING_START, function(len, ply)
        if not IsValid(ply) then return end
        RagdollManager:RequestSelfRevive(ply)
    end)

    net.Receive(NET_STRING_CANCEL, function(len, ply)
        if not IsValid(ply) then return end
        RagdollManager:CancelSelfRevive(ply)
    end)
else
    -- 客户端：检测 A/D 旋转和 E 键自救
    local turnSpeed = 15
    local sendInterval = 0.05
    local accumulatedDelta = 0
    local lastSendTime = 0
    local lastUseKeyDown = false -- 用于检测 E 键按下/松开

    hook.Add("PlayerSpawn", Constants.ADDON_NAME .. MODULE_NAME .. "PlayerSpawn", function(ply)
        if ply == LocalPlayer() then
            accumulatedDelta = 0
            lastSendTime = 0
            lastUseKeyDown = false
        end
    end)

    hook.Add("CreateMove", Constants.ADDON_NAME .. MODULE_NAME .. "CreateMove", function(cmd)
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
            -- 按下瞬间
            net.Start(NET_STRING_START)
            net.SendToServer()
        elseif not useDown and lastUseKeyDown then
            -- 松开瞬间
            net.Start(NET_STRING_CANCEL)
            net.SendToServer()
        end
        lastUseKeyDown = useDown
    end)
end

_EnhancedDeathAnimationExtendedSingletons = _EnhancedDeathAnimationExtendedSingletons or {}
_EnhancedDeathAnimationExtendedSingletons[MODULE_NAME] = PlayerProxy
return PlayerProxy
