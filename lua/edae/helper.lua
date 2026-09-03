-- lua/edae/helper.lua
-- 通用辅助函数模块，供各子系统使用

local helper = {}

--- 从稠密表（数组）中随机选择一个元素
--- @param denseTable table 以连续整数索引的数组
--- @return any|nil 随机元素，若表为空或 nil 则返回 nil
function helper.RandomFromDenseTable(denseTable)
    if not denseTable or #denseTable == 0 then
        return nil
    end
    return denseTable[math.random(#denseTable)]
end

return helper
