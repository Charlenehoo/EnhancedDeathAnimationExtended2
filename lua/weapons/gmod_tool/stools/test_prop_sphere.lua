TOOL.Category = "Debug"
TOOL.Name = "Gravity Proxy"

-- 左键：在射线击中点创建 prop_sphere（重力代理）
function TOOL:LeftClick(tr)
    if not tr.Hit then return false end

    local proxy = ents.Create("prop_sphere")
    -- proxy:SetModel("models/hunter/blocks/cube025x025x025.mdl")
    proxy:SetModel("models/editor/cube_small.mdl")
    proxy:SetKeyValue("radius", "4")
    proxy:SetPos(tr.HitPos + Vector(0, 0, 4)) -- 球心抬高半径，使其刚好接触地面
    proxy:Spawn()
    -- proxy:SetCollisionGroup(COLLISION_GROUP_DEBRIS) -- 只与世界碰撞

    -- 物理参数配置（零摩擦、轻质量、高阻尼）
    -- local phys = proxy:GetPhysicsObject()
    -- if IsValid(phys) then
    --     phys:SetMass(0.5)
    --     phys:SetFriction(0)
    --     phys:SetElasticity(0)
    --     phys:SetDamping(50, 50)
    --     phys:SetAngleDragCoeff(10000)
    -- end

    -- 调试可视化：半透明红色
    -- proxy:SetColor(Color(255, 0, 0, 180))
    -- proxy:SetRenderMode(RENDERMODE_TRANSALPHA)

    undo.SetPlayer(self:GetOwner())
    undo.Create("Gravity Proxy")
    undo.AddEntity(proxy)
    undo.Finish()

    print("[Proxy Debug] 已创建 prop_sphere (Radius=4)")
    return true
end

-- 右键：打印该 prop_sphere 的所有关键物理信息
function TOOL:RightClick(tr)
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "prop_sphere" then
        print("[Proxy Debug] 请点击一个 prop_sphere")
        return false
    end

    local pos = ent:GetPos()
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then
        print("[Proxy Debug] 无物理对象")
        return false
    end

    -- 从球心向下打射线，测地面距离
    local trace = util.TraceLine({
        start = pos + Vector(0, 0, 10),
        endpos = pos - Vector(0, 0, 1000),
        mask = MASK_SOLID,
        filter = { ent }
    })

    local groundDist = trace.Hit and (pos.z - trace.HitPos.z) or nil
    local vel = phys:GetVelocity()
    -- local angVel = phys:GetAngularVelocity()

    print("========== Prop_Sphere 调试信息 ==========")
    print("位置 (Pos):      ", tostring(pos))
    print("速度 (Vel):      ", tostring(vel))
    print("角速度 (AngVel): ", tostring(angVel))
    print("质量 (Mass):     ", phys:GetMass())
    -- print("摩擦 (Friction): ", phys:GetFriction())
    -- print("弹性 (Elasticity):", phys:GetElasticity())
    if groundDist then
        print("到地面距离:      ", string.format("%.2f 单位", groundDist))
    else
        print("到地面距离:      (射线未击中，可能悬空)")
    end
    print("==========================================")

    return true
end

-- 可选：在画布上显示提示（左键创建，右键调试）
function TOOL:DrawToolScreen(width, height)
    surface.SetFont("DermaLarge")
    surface.SetTextColor(255, 255, 255, 255)
    surface.SetTextPos(10, 10)
    surface.DrawText("左键: 创建 prop_sphere")
    surface.SetTextPos(10, 40)
    surface.DrawText("右键: 打印该 sphere 的物理信息")
end
