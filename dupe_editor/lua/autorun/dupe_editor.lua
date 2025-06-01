AddCSLuaFile("entityList.lua")
AddCSLuaFile("helperFunctions.lua")
AddCSLuaFile("shared.lua")


--[[
    TODO:
        BUGS:
            
            Fix "+"" not showing up on tables unless clicking on it
            Update child node upon adding table or value instead of everything
            Upon checking/unchecking "hide" and "sort" keep opened tables instead of collapsing everything
            
        
        
        Useful features:
        - Display modified keys in bold    
        - Booleans only require double click to be changed
        - Search bar for key/values
        - Buttons to expand/collapse
        - Edit world entities

        Specific features for specific entities:
        - one click remove DoNotDuplicate (set it to false)
        - protect e2
        - paint loop

    If you are reading this code, it means you know how to read lua code, so hi !

]]--

if SERVER then
    util.AddNetworkString("RequestArmedDupe")
    util.AddNetworkString("SendArmedDupe")

    


    net.Receive("RequestArmedDupe", function(len, client)
        if not IsValid(client) or not client.CurrentDupe then return end

        local json = util.TableToJSON(client.CurrentDupe)
        local compressed = util.Compress(json)

        net.Start("SendArmedDupe")
            net.WriteData(compressed, #compressed)
        net.Send(client)
    end)
    
	-- Create and return the entity
	--return EntityClass.Func( Player, unpack( ArgList ) )

    DupeEnts = duplicator.EntityClasses
    
end

if CLIENT then
    

    --PrintTable(Entity(0):GetTable())

    currentDupeTable = currentDupeTable or nil

    VERSION = 0.1

    local tableCopy = nil
    
    local PopulateTree
    --local OpenEntityListWindow
    
    local originalDupeTable = nil  -- Store original data order

    local function modifyDupe(dupe_name)
        local dupe = engine.OpenDupe(dupe_name)
        if not dupe then
            print("Error loading dupe")
            return
        end

        local uncompressed = util.Decompress(dupe.data, nil)
        local dupeTable = util.JSONToTable(uncompressed)
        
        return dupeTable
    end

    
    
    local function OpenMultilineEditor(node, k, v, parentTable)
        local EditFrame = vgui.Create("DFrame")
        EditFrame:SetSize(600, 500)
        EditFrame:Center()
        EditFrame:SetTitle("Multiline Editor: " .. tostring(k))
        EditFrame:MakePopup()

        local TextEditor = vgui.Create("DTextEntry", EditFrame)
        TextEditor:SetSize(580, 435)
        TextEditor:SetPos(10, 30)
        TextEditor:SetMultiline(true)
        newText = DisplayNewlines(parentTable[k])
        if TextEditor:GetText() ~= newText then
            TextEditor:SetText(newText)
        end
        
        local SaveButton = vgui.Create("DButton", EditFrame)
        SaveButton:SetSize(480, 25)
        SaveButton:SetPos(10, 470)
        if SaveButton:GetText() ~= "Save" then
            SaveButton:SetText("Save")
        end
        SaveButton.DoClick = function()
            local newValue = TextEditor:GetValue()
            
            parentTable[k] = newValue
            
            local displayText = newValue
            if #displayText > 50 then
                displayText = string.sub(displayText, 1, 47) .. "..."
            end
            newText = k .. ": " .. displayText
            if node:GetText() ~= newText then
                node:SetText(newText)
            end
            
            EditFrame:Close()
        end
    end
    



    local function ParseSpecialValue(value, originalType)
        
        if value == nil or type(value) == "number" or type(value) == "boolean" then
            return value
        end
        
        -- detect and convert special values
        if type(value) == "string" then
            
            local num = tonumber(value)
            if num then return num end
            
            if value:lower() == "true" then return true end
            if value:lower() == "false" then return false end
            
            -- Angle format  "Angle(0, 0, 0)"
            if value:match("^Angle%([%d%s%.%-%,]+%)$") then
                local p, y, r = value:match("Angle%(([%d%.%-%s]+),([%d%.%-%s]+),([%d%.%-%s]+)%)")
                if p and y and r then
                    return Angle(tonumber(p) or 0, tonumber(y) or 0, tonumber(r) or 0)
                end
            end
            
            -- Vector format  "Vector(0, 0, 0)"
            if value:match("^Vector%([%d%s%.%-%,]+%)$") then
                local x, y, z = value:match("Vector%(([%d%.%-%s]+),([%d%.%-%s]+),([%d%.%-%s]+)%)")
                if x and y and z then
                    return Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
                end
            end
        end
        
        
        if originalType == "Angle" then
            local p, y, r = 0, 0, 0
            local parts = string.Split(value, ",")
            if #parts >= 3 then
                p = tonumber(parts[1]) or 0
                y = tonumber(parts[2]) or 0
                r = tonumber(parts[3]) or 0
            end
            return Angle(p, y, r)
        elseif originalType == "Vector" then
            local x, y, z = 0, 0, 0
            local parts = string.Split(value, ",")
            if #parts >= 3 then
                x = tonumber(parts[1]) or 0
                y = tonumber(parts[2]) or 0
                z = tonumber(parts[3]) or 0
            end
            return Vector(x, y, z)
        end
        
        return value
    end








    -- Open editor for a value
    local function OpenValueEditor(node, k, v, parentTable)
        local vType = GetValueType(v)
        
        local EditFrame = vgui.Create("DFrame")
        EditFrame:SetSize(380, 150)
        EditFrame:Center()
        EditFrame:SetTitle("Edit Value: " .. tostring(k) .. " (Type: " .. vType .. ")")
        EditFrame:MakePopup()

        local TypeLabel = vgui.Create("DLabel", EditFrame)
        TypeLabel:SetPos(10, 30)
        TypeLabel:SetSize(360, 20)
        newText = "Current Type: " .. vType .. " - Make sure to maintain format!"
        if TypeLabel:GetText() ~= newText then
            TypeLabel:SetText(newText)
        end

        local TextEntry = vgui.Create("DTextEntry", EditFrame)
        TextEntry:SetSize(360, 25)
        TextEntry:SetPos(10, 55)
        newText = ValueToEditableString(parentTable[k])
        if TextEntry:GetText() ~= newText then
            TextEntry:SetText(newText)
        end
        
        if vType == "Angle" then
            local HelpLabel = vgui.Create("DLabel", EditFrame)
            HelpLabel:SetPos(10, 85)
            HelpLabel:SetSize(360, 20)
            newText = "Format: Angle(pitch, yaw, roll) - e.g. Angle(0, 90, 0)"
            if HelpLabel:GetText() ~= newText then
                HelpLabel:SetText(newText)
            end
        elseif vType == "Vector" then
            local HelpLabel = vgui.Create("DLabel", EditFrame)
            HelpLabel:SetPos(10, 85)
            HelpLabel:SetSize(360, 20)
            newText = "Format: Vector(x, y, z) - e.g. Vector(0, 0, 100)"
            if HelpLabel:GetText() ~= newText then
                HelpLabel:SetText(newText)
            end
        end


        local SaveButton = vgui.Create("DButton", EditFrame)
        SaveButton:SetSize(360, 25)
        SaveButton:SetPos(10, 115)
        if SaveButton:GetText() ~= "Save" then
            SaveButton:SetText("Save")
        end

        SaveButton.DoClick = function()
            local newValue = TextEntry:GetValue()
            
            newValue = ParseSpecialValue(newValue, vType)
            
            parentTable[k] = newValue
            theText = k .. ": " .. ValueToEditableString(newValue)
            if node:GetText() ~= theText then
                node:SetText(theText)
            end
            EditFrame:Close()
        end
    
    end


    local function OpenKeyEditor(node, k, v, parentTable)
        local EditFrame = vgui.Create("DFrame")
        EditFrame:SetSize(300, 100)
        EditFrame:Center()
        EditFrame:SetTitle("Edit Key")
        EditFrame:MakePopup()

        local TextEntry = vgui.Create("DTextEntry", EditFrame)
        TextEntry:SetSize(280, 25)
        TextEntry:SetPos(10, 30)
        newText = tostring(k)
        if TextEntry:GetText() ~= newText then
            TextEntry:SetText(newText)
        end
        local SaveButton = vgui.Create("DButton", EditFrame)
        SaveButton:SetSize(280, 25)
        SaveButton:SetPos(10, 60)
        newText = "Save"
        if SaveButton:GetText() ~= newText then
            SaveButton:SetText("Save")
        end
        SaveButton.DoClick = function()
            local newKey = TextEntry:GetValue()
            
            -- opsie fix
            if newKey == "" then
                EditFrame:Close()
                return
            end
            
            if parentTable[newKey] ~= nil and newKey ~= k then
                Derma_Message("Key already exists!", "Error", "OK")
                return
            end
            
            -- remove old key
            -- and copy value to new key
            parentTable[newKey] = v
            parentTable[k] = nil
            
            theText = newKey .. ": " .. ValueToEditableString(v)
            if node:GetText() ~= theText then
                node:SetText(theText)
            end
            node.DataKey = newKey
            
            EditFrame:Close()
        end
    end


    -- Insert new key/value pair
    local function InsertKeyValue(node, parentTable)
        local EditFrame = vgui.Create("DFrame")
        EditFrame:SetSize(300, 180)
        EditFrame:Center()
        EditFrame:SetTitle("Insert Key/Value")
        EditFrame:MakePopup()


        local TypeLabel = vgui.Create("DLabel", EditFrame)
        TypeLabel:SetPos(10, 60)
        TypeLabel:SetSize(50, 20)
        newText = "Type:"
        if TypeLabel:GetText() ~= newText then
            TypeLabel:SetText("Type:")
        end
        local TypeCombo = vgui.Create("DComboBox", EditFrame)
        TypeCombo:SetPos(60, 60)
        TypeCombo:SetSize(230, 20)
        TypeCombo:AddChoice("String", "string")
        TypeCombo:AddChoice("Number", "number")
        TypeCombo:AddChoice("Boolean", "boolean")
        TypeCombo:AddChoice("Angle", "Angle")
        TypeCombo:AddChoice("Vector", "Vector")
        TypeCombo:AddChoice("Function", "function")
        --TypeCombo:AddChoice("Table", "table")
        TypeCombo:ChooseOptionID(1)
        
        
        local KeyLabel = vgui.Create("DLabel", EditFrame)
        KeyLabel:SetPos(10, 30)
        KeyLabel:SetSize(50, 20)
        newText = "Key:"
        if KeyLabel:GetText() ~= newText then
            KeyLabel:SetText("Key:")
        end
        local KeyEntry = vgui.Create("DTextEntry", EditFrame)
        KeyEntry:SetSize(230, 20)
        KeyEntry:SetPos(60, 30)
        if KeyEntry:GetText() ~= "" then
            KeyEntry:SetText("")
        end


        local ValueLabel = vgui.Create("DLabel", EditFrame)
        ValueLabel:SetPos(10, 90)
        ValueLabel:SetSize(50, 20)
        newText = "Value:"
        if ValueLabel:GetText() ~= newText then
            ValueLabel:SetText("Value:")
        end
        local ValueEntry = vgui.Create("DTextEntry", EditFrame)
        ValueEntry:SetSize(230, 20)
        ValueEntry:SetPos(60, 90)
        if ValueEntry:GetText() ~= "" then
            ValueEntry:SetText("")
        end


        local HelpLabel = vgui.Create("DLabel", EditFrame)
        HelpLabel:SetPos(10, 115)
        HelpLabel:SetSize(280, 20)
        newText = "For Angle: Angle(0,0,0) | Vector: Vector(0,0,0)"
        if HelpLabel:GetText() ~= newText then
            HelpLabel:SetText(newText)
        end


        local SaveButton = vgui.Create("DButton", EditFrame)
        SaveButton:SetSize(280, 25)
        SaveButton:SetPos(10, 140)
        if SaveButton:GetText() ~= "Save" then
            SaveButton:SetText("Save")
        end
        SaveButton.DoClick = function()
            local newKey = KeyEntry:GetValue()
            local newType = TypeCombo:GetOptionData(TypeCombo:GetSelectedID())
            local newValue = ValueEntry:GetValue()
            
            if newKey == "" and newType ~= "function" then
                Derma_Message("Key cannot be empty!", "Error", "OK")
                return
            end
            
            if parentTable[newKey] ~= nil then
                Derma_Message("Key already exists!", "Error", "OK")
                return
            end
            
            -- Convert value based on selected type
            if newType == "function" then
                local key = "user_func"
                RunString("tempFunc = " .. newValue, key)
                if isfunction(tempFunc) then
                    newValue = tempFunc
                else
                    newValue = function() end
                    print("Function compile error.")
                end
            elseif newType == "string" then
                -- no conversion required
            elseif newType == "number" then
                newValue = tonumber(newValue) or 0
            elseif newType == "boolean" then
                newValue = (newValue:lower() == "true")
            elseif newType == "Angle" then
                local p, y, r = 0, 0, 0
                -- chatgpt moment
                p, y, r = newValue:match("Angle%(([%d%.%-%s]+),([%d%.%-%s]+),([%d%.%-%s]+)%)")
                if not (p and y and r) then
                    local parts = string.Split(newValue, ",")
                    if #parts >= 3 then
                        p = tonumber(parts[1]) or 0
                        y = tonumber(parts[2]) or 0
                        r = tonumber(parts[3]) or 0
                    end
                else
                    p = tonumber(p) or 0
                    y = tonumber(y) or 0
                    r = tonumber(r) or 0
                end
                newValue = Angle(p, y, r)
            elseif newType == "Vector" then
                local x, y, z = 0, 0, 0
                x, y, z = newValue:match("Vector%(([%d%.%-%s]+),([%d%.%-%s]+),([%d%.%-%s]+)%)")
                if not (x and y and z) then
                    local parts = string.Split(newValue, ",")
                    if #parts >= 3 then
                        x = tonumber(parts[1]) or 0
                        y = tonumber(parts[2]) or 0
                        z = tonumber(parts[3]) or 0
                    end
                else
                    x = tonumber(x) or 0
                    y = tonumber(y) or 0
                    z = tonumber(z) or 0
                end
                newValue = Vector(x, y, z)
            elseif newType == "table" then
                newValue = {}
            end
            
            parentTable[newKey] = newValue
            
            -- refresh the node to show the new entry
            if node.DataValue then
                node:Clear()
                PopulateTree(node, node.DataValue)
            else
                local parentNode = node:GetParentNode()
                if parentNode and parentNode.DataValue then
                    parentNode:Clear()
                    PopulateTree(parentNode, parentNode.DataValue)
                end
            end
            
            EditFrame:Close()
        end
    end

    
    
    local function InsertTable(node, parentTable)
        local EditFrame = vgui.Create("DFrame")
        EditFrame:SetSize(300, 100)
        EditFrame:Center()
        EditFrame:SetTitle("Insert Table")
        EditFrame:MakePopup()

        local KeyLabel = vgui.Create("DLabel", EditFrame)
        KeyLabel:SetPos(10, 30)
        KeyLabel:SetSize(50, 20)
        if KeyLabel:GetText() ~= "Key:" then
            KeyLabel:SetText("Key:")
        end

        local KeyEntry = vgui.Create("DTextEntry", EditFrame)
        KeyEntry:SetSize(230, 20)
        KeyEntry:SetPos(60, 30)
        if KeyEntry:GetText() ~= "" then
            KeyEntry:SetText("")
        end

        local SaveButton = vgui.Create("DButton", EditFrame)
        SaveButton:SetSize(280, 25)
        SaveButton:SetPos(10, 60)
        newText = "Save"
        if SaveButton:GetText() ~= newText then
            SaveButton:SetText("Save")
        end
        SaveButton.DoClick = function()
            local newKey = KeyEntry:GetValue()
            
            if newKey == "" then
                Derma_Message("Key cannot be empty!", "Error", "OK")
                return
            end
            
            if parentTable[newKey] ~= nil then
                Derma_Message("Key already exists!", "Error", "OK")
                return
            end
            
            parentTable[newKey] = {}
            
            if node.DataValue then
                node:Clear()
                PopulateTree(node, node.DataValue)
            else
                local parentNode = node:GetParentNode()
                if parentNode and parentNode.DataValue then
                    parentNode:Clear()
                    PopulateTree(parentNode, parentNode.DataValue)
                end
            end
            
            EditFrame:Close()
        end
    end

    function table.copy(tbl)
        local copy = {}
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                copy[k] = table.copy(v)
            else
                copy[k] = v
            end
        end
        return copy
    end


    local function ComputeVolume(mins, maxs)
        local size = Vector(math.abs(maxs.x - mins.x), math.abs(maxs.y - mins.y), math.abs(maxs.z - mins.z))
        return size.x * size.y * size.z
    end

    local function RemoveSmallestEntities(entitiesTable)
        local volumes = {}
        for k, ent in pairs(entitiesTable) do
            if istable(ent) and ent.Mins and ent.Maxs then
                local vol = ComputeVolume(ent.Mins, ent.Maxs)
                table.insert(volumes, { key = k, volume = vol })
            end
        end

        table.sort(volumes, function(a, b) return a.volume < b.volume end)

        local toRemoveCount = math.floor(#volumes * 0.1 + 1.0)
        if toRemoveCount == 0 then return end

        local toRemove = {}
        for i = 1, toRemoveCount do
            table.insert(toRemove, volumes[i].key)
        end

        Derma_Query(
            "Remove " .. toRemoveCount .. " smallest entities?",
            "Confirm Removal",
            "Yes", function()
                for _, k in ipairs(toRemove) do
                    entitiesTable[k] = nil
                end
                if node and node.DataValue then
                    node:Clear()
                    PopulateTree(node, node.DataValue)
                end
            end,
            "No", function() end
        )
    end

    local function ShowNodeMenu(node, k, v, parentTable)
        local menu = DermaMenu()

        if k == "Entities" and istable(v) then
            menu:AddOption("Remove bottom 5% smallest props", function()
                RemoveSmallestEntities(v)
            end)
            menu:AddSpacer()
        end

                
        if k == "Constraints" and istable(v) then
            menu:AddOption("Remove bottom 5% smallest props", function()
                RemoveSmallestEntities(v)
            end)
            menu:AddSpacer()
        end


        menu:AddOption("Edit Key", function()
            OpenKeyEditor(node, k, v, parentTable)
        end)


        if type(v) ~= "table" then
            menu:AddOption("Edit Value", function()
                OpenValueEditor(node, k, v, parentTable)
            end)
        end
        
        
        if type(v) == "string" then
            local multilineOption = menu:AddOption("→ Edit in Editor ←", function()
                OpenMultilineEditor(node, k, v, parentTable)
            end)
            
            if ContainsEscapeSequences(v) then
                multilineOption:SetColor(Color(255, 100, 100))
            end
        end
        

        if type(v) == "table" then
            menu:AddOption("Insert Key/Value", function()
                if type(v) == "table" then
                    InsertKeyValue(node, v)
                else
                    InsertKeyValue(node, parentTable)
                end
            end)
            
            menu:AddOption("Create empty table", function()
                if type(v) == "table" then
                    InsertTable(node, v)
                else
                    InsertTable(node, parentTable)
                end
            end)
            
            menu:AddOption("---------")

            menu:AddOption("Copy table", function()
                -- deep-copy v and remember its key
                tableCopy = {
                  key   = k,
                  value = table.Copy(v)
                }
            end)
            
            
            menu:AddOption("Paste table", function()
                if not tableCopy then return end
                local t = node.DataValue
                if not istable(t) then
                    Derma_Message("Cannot paste here – not a table", "Error", "OK")
                    return
                end
                local key = tableCopy.key
                if t[key] ~= nil then
                    local max = 0
                    for k, _ in pairs(t) do
                        local num = tonumber(k)
                        if num and num > max then
                            max = num
                        end
                    end
                    key = tostring(max + 1)
                end
                t[key] = table.Copy(tableCopy.value)

                node:Clear()
                PopulateTree(node, t)
            end)
            
            
            
            
            menu:AddOption("---------")

            menu:AddOption("Insert copied entity (NET)", function()
                PasteEntityData("NET")
            end)
            menu:AddOption("Insert copied entity (JSON)", function()
                PasteEntityData("JSON")
            end)
            

        end
        

        menu:AddOption("Delete", function()
            
            Derma_Query(
                "Are you sure you want to delete this " .. (type(v) == "table" and "table" or "value") .. "?  \n\n" .. tostring(k),
                "Confirm Delete",
                "Yes", function()
                    
                    parentTable[k] = nil
                    
                    local parentNode = node:GetParentNode()
                    if parentNode and parentNode.DataValue then
                        parentNode:Clear()
                        PopulateTree(parentNode, parentNode.DataValue) -- refresh folders and keys
                    end
                end,
                "No", function() end
            )
        end)
        --p
        menu:Open()
    end




    -- init this cool ass window
    local function CreateDupeEditor()
        


        local Window = vgui.Create("DFrame")
        Window:SetSize(1090, 730)
        Window:Center()
        Window:SetTitle("Dupe Editor")
        Window:MakePopup()

        local DupeList = vgui.Create("DListView", Window)
        DupeList:SetSize(300, 640)
        DupeList:SetPos(10, 70)
        DupeList:AddColumn("Dupe Files")

        -- Data Editor as a tree view on the right
        local DataTree = vgui.Create("DTree", Window)
        DataTree:SetSize(760, 640)
        DataTree:SetPos(320, 70)
        DataTree:SetPadding(5)

        local SortLabel = vgui.Create("DLabel", Window)
        SortLabel:SetPos(10, 40)
        SortLabel:SetSize(60, 20)
        newText = "Sort by:"
        if SortLabel:GetText() ~= newText then
            SortLabel:SetText("Sort by:")
        end
        local SortCombo = vgui.Create("DComboBox", Window)
        SortCombo:SetPos(70, 40)
        SortCombo:SetSize(150, 20)
        SortCombo:AddChoice("Name (A-Z)", 1)
        SortCombo:AddChoice("Name (Z-A)", 2)
        SortCombo:AddChoice("Date (Newest)", 3, true)  -- default
        SortCombo:AddChoice("Date (Oldest)", 4)


        local Instructions = vgui.Create("DLabel", Window)
        Instructions:SetPos(320, 710)
        Instructions:SetSize(300, 20)
        newText = "Right-click on any item to edit"
        if Instructions:GetText() ~= newText then
            Instructions:SetText("Right-click on any item to edit")
        end
        
        local VersionText = vgui.Create("DLabel", Window)
        VersionText:SetPos(10, 710)
        VersionText:SetSize(300, 20)
        newText = "Ver: " .. VERSION
        if VersionText:GetText() ~= newText then
            VersionText:SetText(newText)
        end

        local AutoSortData = vgui.Create("DCheckBoxLabel", Window)
        AutoSortData:SetPos(Window:GetWide() - 180, 42)
        newText = "Auto Sort"
        if AutoSortData:GetText() ~= newText then
            AutoSortData:SetText("Auto Sort")
        end
        AutoSortData:SetChecked(true)
        AutoSortData:SizeToContents() -- Size based on text
        
        local HideEmptyTables = vgui.Create("DCheckBoxLabel", Window)
        HideEmptyTables:SetPos(Window:GetWide() - 320, 42)
        newText = "Hide Empty Tables"
        if HideEmptyTables:GetText() ~= newText then
            HideEmptyTables:SetText(newText)
        end
        HideEmptyTables:SetChecked(true)
        HideEmptyTables:SizeToContents()

        function PasteTableData()
        end

        function PasteEntityData(method)

            if method == "NET" then
                if not copiedEntityData then
                    Derma_Message("No entity data copied!", "Error", "OK")
                    print("No entity data copied!")
                    return
                end
                
                if not currentDupeTable then
                    Derma_Message("No dupe loaded to paste into! (how did you do that??)", "Error", "OK")
                    return
                end
            end

            -- Make sure the Entities table exists
            if not currentDupeTable.Entities then
                currentDupeTable.Entities = {}
            end
            
            -- Find the next available entity ID
            local maxID = 0
            for id, _ in pairs(currentDupeTable.Entities) do
                local numID = tonumber(id)
                if numID and numID > maxID then
                    maxID = numID
                end
            end
            
            local newID = maxID + 1
            
            -- Add the entity to the dupe
            if method == "NET" then
                currentDupeTable.Entities[tostring(newID)] = table.Copy(copiedEntityData)
            else
                local json = file.Read("dupe_editor_json.json", "DATA")

                if not json then
                    Derma_Message("No entity data saved! \nCheck: common\\GarrysMod\\garrysmod\\data\\dupe_editor_json.json", "Error", "OK")
                    print("No entity data saved! \nCheck: common\\GarrysMod\\garrysmod\\data\\dupe_editor_json.json")
                    return
                end
                local dupeTable = util.JSONToTable(json)
                currentDupeTable.Entities[tostring(newID)] = table.Copy(dupeTable)
            end
            
            -- Update your dupe tree view (implement this based on your UI setup)
            -- This would refresh the main dupe editor tree
            DataTree:Clear()
            for rootName, rootData in pairs(currentDupeTable) do
                if type(rootData) == "table" then
                    local root = DataTree:AddNode(rootName)
                    root.DataValue = rootData or {}
                    root:SetIcon("icon16/folder.png")
                    
                    root.DoRightClick = function()
                        ShowNodeMenu(root, rootName, rootData, nil)
                    end
                    
                    --PopulateTree(root, rootData or {})
                    PopulateTree(root, rootData or {}, false)
                    
                    if root.Expand then
                        root:Expand(true)
                    elseif root.SetExpanded then
                        root:SetExpanded(true)
                    end
                end
            end

        end

        -- =========================================
        
        PopulateTree = function(node, data)
            local items = {}
            for k, v in pairs(data) do
                -- check if table is empty
                if not (HideEmptyTables:GetChecked() and type(v) == "table" and IsEffectivelyEmpty(v)) then
                    table.insert(items, {key = k, value = v})
                end
            end
            
            -- Sort items if auto-sort is enabled
            if AutoSortData:GetChecked() then
                table.sort(items, function(a, b)
                    local priorityA = GetTypePriority(a.value)
                    local priorityB = GetTypePriority(b.value)
                    
                    if priorityA == priorityB then
                        -- If same type, sort by key (alphabetically)
                        if type(a.key) == "string" and type(b.key) == "string" then
                            return string.lower(a.key) < string.lower(b.key)
                        else
                            return tostring(a.key) < tostring(b.key)
                        end
                    else
                        return priorityA < priorityB
                    end
                end)
            end
            
            for _, item in ipairs(items) do
                local k = item.key
                local v = item.value
                
                local tmpValue = ValueToEditableString(v)
                
                -- make it easy to figure out the content
                if tmpValue == "table" and v.Class ~= nil then
                    
                    if v._name == nil then
                        v._name = ""
                    end
                    local count = 0
                    for _ in pairs(items) do
                        count = count + 1
                    end
                    
                    tmpValue = tmpValue .. " (" .. v.Class .. ")"

                    if v.Class == "gmod_wire_expression2" then
                        tmpValue = tmpValue .. "  \"" .. v._name .. "\""
                    end

                end
                if tmpValue == "table" then
                    tmpValue = tmpValue .. " - entries: " .. CountEntries(v)
                end


                tmpValue = tmpValue:gsub("\n[^\n]*$", "")
                tmpValue = tmpValue:gsub("\n[^\n]*(\n?)$", "%1")
                tmpValue = tmpValue:gsub("\n", "")
                
                -- Does not properly work when short string changes to longer and/or with newlines
                if #tmpValue > 50 and ValueToEditableString(v) ~= "table" then
                    tmpValue = string.sub(tmpValue, 1, 47) .. "..."
                end
                
                local label = k .. ": " .. tmpValue
                local child = node:AddNode(label)
                
                child.DataKey = k
                child.DataValue = v
                
                if type(v) == "table" then
                    if IsEffectivelyEmpty(v) then
                        child:SetIcon("icon16/folder_delete.png") -- empty tables
                    else
                        child:SetIcon("icon16/folder.png")
                    end
                    
                    child.DoClick = function(self)
                        if self.Populated then
                            self:SetExpanded(not self.Expanded) -- this should fix the un/expand bug
                        else
                            self:Clear()
                            PopulateTree(self, self.DataValue)
                            self.Populated = true
                            self:SetExpanded(true)
                        end
                    end
                elseif IsAngle(v) then
                    child:SetIcon("icon16/shape_rotate_clockwise.png")
                elseif IsVector(v) then
                    child:SetIcon("icon16/chart_line.png")
                elseif type(v) == "string" then
                    child:SetIcon("icon16/pencil.png")
                elseif type(v) == "number" then
                    child:SetIcon("icon16/calculator.png")
                elseif type(v) == "boolean" then
                    child:SetIcon("icon16/bullet_pink.png")
                else
                    child:SetIcon("icon16/page.png") -- undefined
                end
                
                child.DoRightClick = function(self)
                    ShowNodeMenu(self, k, v, data)
                end
    
                -- spacing for my dyslexyc friends
                child:DockMargin(0, 0, 0, 5)
            end
        end

        local function LoadDupe(dupePath, displayName)
            --currentDupePath = dupePath
            currentDupeTable = modifyDupe(dupePath)
            
            if not currentDupeTable then return end
            
            originalDupeTable = DeepCopy(currentDupeTable)
            
            Window:SetTitle("Dupe Editor - " .. displayName)
            
            DataTree:Clear()
        
            for rootName, rootData in pairs(currentDupeTable) do
                if type(rootData) == "table" then
                    local root = DataTree:AddNode(rootName)
                    root.DataValue = rootData or {}
                    root:SetIcon("icon16/folder.png")
                    
                    root.DoRightClick = function()
                        ShowNodeMenu(root, rootName, rootData, nil)
                    end
                    
                    PopulateTree(root, rootData or {})
                    if root.Expand then
                        root:Expand(true)
                    elseif root.SetExpanded then
                        root:SetExpanded(true)
                    end
                end
            end
        end
        
        
        
        local function GetDupesList()
            local dupeFiles = {}
            local files, _ = file.Find("dupes/*.dupe", "GAME") -- use GAME for dupes instead of DATA
            
            for _, filename in ipairs(files) do
                local fullPath = "dupes/" .. filename
                table.insert(dupeFiles, {
                    displayName = filename,
                    path = fullPath,
                    time = file.Time(fullPath, "GAME") or 0
                })
            end
            
            return dupeFiles
        end
        

        local function PopulateDupeList(sortOption)
            DupeList:Clear()
            local dupeFiles = GetDupesList()
            
            if sortOption == 1 then
                -- A-Z
                table.sort(dupeFiles, function(a, b) return a.displayName < b.displayName end)
            elseif sortOption == 2 then
                -- Z-A
                table.sort(dupeFiles, function(a, b) return a.displayName > b.displayName end)
            elseif sortOption == 3 then
                -- Newest
                table.sort(dupeFiles, function(a, b) return a.time > b.time end)
            else
                -- Oldest
                table.sort(dupeFiles, function(a, b) return a.time < b.time end)
            end
            
            for _, fileInfo in ipairs(dupeFiles) do
                local line = DupeList:AddLine(fileInfo.displayName)
                -- store the path with the line for easy access
                line.DupePath = fileInfo.path
            end
        end
        
        
        PopulateDupeList(3)
        
        -- update sorting when dropdown changes
        SortCombo.OnSelect = function(_, _, _, sortOption)
            PopulateDupeList(sortOption)
        end
        
        DupeList.OnRowSelected = function(_, rowIndex, row)
            local selectedDupe = row:GetColumnText(1)
            LoadDupe(row.DupePath, selectedDupe)
        end
        


        local SaveButton = vgui.Create("DButton", Window)
        SaveButton:SetSize(80, 20)
        SaveButton:SetPos(Window:GetWide() - 90, 40)
        
        if SaveButton:GetText() ~= newText then
            SaveButton:SetText("Save")
        end
        SaveButton.DoClick = function()
            local json = util.TableToJSON(currentDupeTable)
            local compressed = util.Compress(json)
            
            local success, err = pcall(function()
                engine.WriteDupe(compressed, "") --fix screenshot
            end)
            
            if success then
                Derma_Message("Dupe saved successfully!", "Success", "OK")
                print("Dupe saved!")

                -- refhesh
                local selectedValue = SortCombo:GetSelectedID() or 1
                PopulateDupeList(selectedValue)
            else
                Derma_Message("Error saving dupe: " .. tostring(err), "Error", "OK")
                print("Error saving dupe: ", err) -- should not fail?
            end
        end


        local SaveArmedButton = vgui.Create("DButton", Window)
        SaveArmedButton:SetSize(120, 20)
        SaveArmedButton:SetPos(320, 40)
        if SaveArmedButton:GetText() ~= newText then
            SaveArmedButton:SetText("Clone Armed Dupe")
        end
        SaveArmedButton.DoClick = function()
            net.Start("RequestArmedDupe")
            net.SendToServer()
        end
        
        net.Receive("SendArmedDupe", function()
            local compressed = net.ReadData(net.BytesLeft())
        
            local uncompressed = util.Decompress(compressed)
            if not uncompressed then
                Derma_Message("Failed to retrieve armed dupe!", "Error", "OK")
                return
            end
        
            local dupeTable = util.JSONToTable(uncompressed)
            if not dupeTable then
                Derma_Message("Invalid dupe data!", "Error", "OK")
                return
            end
        
            local success, err = pcall(function()
                engine.WriteDupe(compressed, "") -- fix screenshot?
            end)
        
            if success then
                Derma_Message("Armed dupe saved successfully!", "Success", "OK")
                local selectedValue = SortCombo:GetSelectedID() or 1
                PopulateDupeList(selectedValue)
            else
                Derma_Message("Error saving armed dupe: " .. tostring(err), "Error", "OK")
            end
        end)

        
        AutoSortData.OnChange = function(self, val)
            DataTree:Clear()
        
            for rootName, rootData in pairs(currentDupeTable) do
                if type(rootData) == "table" then
                    local root = DataTree:AddNode(rootName)
                    
                    if val then
                        root.DataValue = rootData or {}
                    else
                        currentDupeTable = DeepCopy(currentDupeTable)
                        root.DataValue = rootData or {}
                    end
                    
                    root:SetIcon("icon16/folder.png")
                    
                    root.DoRightClick = function()
                        ShowNodeMenu(root, rootName, rootData, nil)
                    end
                    
                    PopulateTree(root, rootData or {})
                    if root.Expand then
                        root:Expand(true)
                    elseif root.SetExpanded then
                        root:SetExpanded(true)
                    end
                end
            end
        end
        

        HideEmptyTables.OnChange = function(self, val)
            if currentDupeTable then
                DataTree:Clear()
        
                for rootName, rootData in pairs(currentDupeTable) do
                    if type(rootData) == "table" then
                        local root = DataTree:AddNode(rootName)
                        root.DataValue = rootData or {}
                        root:SetIcon("icon16/folder.png")
                        
                        root.DoRightClick = function()
                            ShowNodeMenu(root, rootName, rootData, nil)
                        end
                        
                        PopulateTree(root, rootData or {})
                        if root.Expand then
                            root:Expand(true)
                        elseif root.SetExpanded then
                            root:SetExpanded(true)
                        end
                    end
                end
            end
        end
        
        local EntityListButton = vgui.Create("DButton", Window)
        EntityListButton:SetSize(120, 20)
        EntityListButton:SetPos(520, 40)
        if EntityListButton:GetText() ~= newText then
            EntityListButton:SetText("Open entity list")
        end
        EntityListButton.DoClick = function()
            OpenEntityListWindow()
        end

        local RefreshButton = vgui.Create("DButton", Window)
        RefreshButton:SetSize(80, 20)
        RefreshButton:SetPos(230, 40)
        if RefreshButton:GetText() ~= newText then
            RefreshButton:SetText("Refresh")
        end
        RefreshButton.DoClick = function()
            local selectedValue = SortCombo:GetSelectedID() or 1
            PopulateDupeList(selectedValue)
        end


    end

    concommand.Add("dupe_editor", CreateDupeEditor)
end