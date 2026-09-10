function TOOL:LeftClick(_)
    local p = self:GetOwner()
    if not IsValid(p) or not p:IsPlayer() then
        return false
    end

    local model = p:GetModel()
    print("Model: " .. model)

    for i = 0, p:GetFlexNum() - 1 do
        print("FlexNum: " .. tostring(i) .. " - " .. "FlexName: " .. p:GetFlexName(i))
    end

    for i = 0, p:GetBoneCount() - 1 do
        print("BoneID: " .. tostring(i) .. " - " .. "BoneName: " .. p:GetBoneName(i))
    end

    return true
end
