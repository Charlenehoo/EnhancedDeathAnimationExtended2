-- lua/weapons/gmod_tool/stools/ragdoll_sequencer_artagdoll.lua
-- 工具：顺序播放 Artagdoll 注册表中的所有动画（仅 models/AREAnims/model_anim.mdl）

TOOL.Name = "#tool.ragdoll_sequencer_artagdoll.name"
TOOL.Category = "Fun"

-- 加载依赖
local Registry = include("edae/config/animation_registry.lua")
local AnimationPlayer = include("edae/playback/animation_player.lua")
local Constants = include("edae/core/constants.lua")
local GroundStrategyBuilder = include("edae/playback/builders/ground_strategy_builder.lua")

local ARTAGDOLL_MODEL = "models/AREAnims/model_anim.mdl"

-- 仅提取 Artagdoll 模型的条目
local flatList = {}
for _, sceneList in pairs(Registry) do
    if type(sceneList) == "table" then
        for _, entry in ipairs(sceneList) do
            if entry.model == ARTAGDOLL_MODEL and entry.seq then
                table.insert(flatList, entry)
            end
        end
    end
end

-- 获取忽略环境的策略（等同溺水模式）
local drowningStrategy = GroundStrategyBuilder:Build(Constants.LifeCycleHandler.STATE_ENUM.DROWNING)

if SERVER then
    -- 清理钩子（动画结束后移除布娃娃）
    function TOOL:Deploy()
        hook.Add(Constants.Events.OnAnimationFinished, "RagdollSequencerCleanup", function(ragdoll, animName, reason)
            if IsValid(ragdoll) and ragdoll.RagdollSequencerSpawned then
                ragdoll:Remove()
            end
        end)
        self.Index = 1
        return true
    end

    function TOOL:Holster()
        hook.Remove(Constants.Events.OnAnimationFinished, "RagdollSequencerCleanup")
        return true
    end

    function TOOL:LeftClick(tr)
        local ply = self:GetOwner()
        if not IsValid(ply) or not ply:IsPlayer() then return false end

        if #flatList == 0 then
            ply:PrintMessage(HUD_PRINTTALK, "No Artagdoll animations found in registry!")
            return false
        end

        -- 获取当前条目（循环）
        local entry = flatList[self.Index]
        if not entry then
            self.Index = 1
            entry = flatList[1]
        end
        self.Index = self.Index + 1
        if self.Index > #flatList then self.Index = 1 end

        -- 创建布娃娃（使用玩家模型）
        local model = ply:GetModel()
        if not model or not util.IsValidModel(model) then
            model = "models/player.mdl"
        end

        local pos = ply:GetPos() + ply:GetForward() * 100 + Vector(0, 0, 10)
        local ang = ply:GetAngles()
        ang.p = 0
        ang.r = 0

        local ragdoll = ents.Create("prop_ragdoll")
        if not IsValid(ragdoll) then return false end
        ragdoll:SetModel(model)
        ragdoll:SetPos(pos)
        ragdoll:SetAngles(ang)
        ragdoll:Spawn()

        if ragdoll:GetPhysicsObjectCount() == 0 then
            ragdoll:Remove()
            return false
        end

        ragdoll.RagdollSequencerSpawned = true

        -- 组装播放选项（注入忽略环境的策略）
        local opts = {
            groundPos          = pos,
            yaw                = ang.yaw,
            animationModelName = entry.model,
            totalLoops         = 0,
            boneStrategy       = drowningStrategy.boneStrategy,
            repositionStrategy = drowningStrategy.repositionStrategy,
        }

        local success = AnimationPlayer:Play(ragdoll, entry.seq, opts)
        if not success then
            ragdoll:Remove()
            ply:PrintMessage(HUD_PRINTTALK, "Failed to play: " .. entry.seq)
        else
            ply:PrintMessage(HUD_PRINTTALK, "Playing: " .. entry.seq .. " (" .. self.Index .. "/" .. #flatList .. ")")
        end

        return true
    end
end
