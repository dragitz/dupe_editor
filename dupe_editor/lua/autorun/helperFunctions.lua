-- helper functions


function IsAngle(v)
    return type(v) == "Angle" or (type(v) == "table" and v.p ~= nil and v.y ~= nil and v.r ~= nil)
end

function IsVector(v)
    return type(v) == "Vector" or (type(v) == "table" and v.x ~= nil and v.y ~= nil and v.z ~= nil)
end

function ContainsEscapeSequences(str)
    if type(str) ~= "string" then return false end
    return string.find(str, "\\n") ~= nil
end  

function GetValueType(v) -- detect the type of a value
    if IsAngle(v) then 
        return "Angle"
    elseif IsVector(v) then
        return "Vector"
    else
        return type(v)
    end
end


function GetTypePriority(value) -- get priority value for sorting
    if type(value) == "table" then
        return 1
    elseif type(value) == "Entity" or type(value) == "Player" then --type(value) == "Weapon" 
        return 2
    elseif type(value) == "Weapon" then
        return 3
    elseif IsVector(value) then
        return 4
    elseif IsAngle(value) then
        return 5
    elseif type(value) == "boolean" then
        return 6
    elseif type(value) == "string" then
        return 7
    elseif type(value) == "number" then
        return 8
    else
        return 99
    end
end


function DeepCopy(original) -- Function to create a deep copy of a table
    local copy
    if type(original) == "table" then
        copy = {}
        for key, value in pairs(original) do
            copy[key] = DeepCopy(value)
        end
    else
        copy = original
    end
    return copy
end

function CountEntries(tab)
    local amount = 0
    for k, v in pairs(tab) do
        amount = amount + 1
    end
    return amount
end

function DisplayNewlines(str)
    if type(str) ~= "string" then return str end
    return string.gsub(str, "\\n", "\n")
end


-- recursion to find empty folders
function IsEffectivelyEmpty(tab)
    if type(tab) ~= "table" then
        return false
    end
    
    local hasKeys = false
    for k, v in pairs(tab) do
        hasKeys = true
        
        if type(v) ~= "table" then
            return false
        end
        
        if not IsEffectivelyEmpty(v) then
            return false
        end
    end
    return true
end


function ValueToEditableString(v)
    if type(v) == "table" then
        return "table"
    elseif type(v) == "Angle" then
        return string.format("Angle(%.2f, %.2f, %.2f)", v.p, v.y, v.r)
    elseif type(v) == "Vector" then
        return string.format("Vector(%.2f, %.2f, %.2f)", v.x, v.y, v.z)
    elseif type(v) == "string" and ContainsEscapeSequences(v) then
        -- For strings with newlines, truncate and add indicator
        local shortValue = string.gsub(v, "\\n", "↵")
        if #shortValue > 50 then
            return string.sub(shortValue, 1, 47) .. "..."
        end
        return shortValue
    else
        return tostring(v)
    end
end

function SafeIterate_old(tbl)
    if type(tbl) ~= "table" then return {} end
    
    local result = {}
    local success, iterResult = pcall(function()
        for k, v in pairs(tbl) do
            result[k] = v
        end
        return result
    end)
    
    if success then
        return result
    else
        return {} -- Return empty table if iteration failed
    end
end

function SafeIterate(tbl, seen)
    if type(tbl) ~= "table" then return {} end

    seen = seen or {}
    if seen[tbl] then return {} end
    seen[tbl] = true
    local out = {}
    for k,v in pairs(tbl) do
        if type(v) == "table" then
            out[k] = SafeIterate(v, seen)
        elseif type(v) ~= "function" then
            out[k] = v
        end
    end
    return out
end