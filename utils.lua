-- utils.lua https://github.com/iicc1/Exchange-wallets-tracker-bot

function vardump(value, depth, key)
    local linePrefix = ""
    local spaces = ""

    if key ~= nil then
        linePrefix = "["..key.."] = "
    end

    if depth == nil then
        depth = 0
    else
        depth = depth + 1
        for i=1, depth do spaces = spaces .. "  " end
    end

    if type(value) == 'table' then
        mTable = getmetatable(value)
        if mTable == nil then
            print(spaces ..linePrefix.."(table) ")
        else
            print(spaces .."(metatable) ")
            value = mTable
        end
        for tableKey, tableValue in pairs(value) do
            vardump(tableValue, depth, tableKey)
        end
    elseif type(value)  == 'function' or type(value) == 'thread' or type(value) == 'userdata' or value == nil then
        print(spaces..tostring(value))
    else
        print(spaces..linePrefix.."("..type(value)..") "..tostring(value))
    end
end
