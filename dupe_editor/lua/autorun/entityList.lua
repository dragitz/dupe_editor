AddCSLuaFile("helperFunctions.lua")
AddCSLuaFile("shared.lua")


--[[

]]--

local DupeEnts = {}
local tempEntityData

-- those types can not be passed via net messages
local bannedTypes = {
    ["function"] = true,
    ["CEffectData"] = true,
    ["userdata"] = true,
    --["PhysObj"] = true,
    ["ConVar"] = true
}


if SERVER then

    --Entity(150).VehicleTable.Name = "You suck for using an auto revenge turret ♥" .. string.rep("\t", 30)  -- Zero-width space
    --Entity(150).VehicleTable.Class = "cringe"

    DupeEnts = duplicator.EntityClasses

    util.AddNetworkString("RequestEntityTable")
    util.AddNetworkString("RequestEntityTableClick")
    util.AddNetworkString("RequestEntityTableClickJSON")

    util.AddNetworkString("DupeEditor_ForceDupe")
    util.AddNetworkString("DupeEditor_CrazyName")

    net.Receive("DupeEditor_CrazyName", function(_, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        -- restore original if you want to undo later
        --ent.VehicleTable.Name = string.rep("cringe auto revenge turret user (remove it to stop this)--->", 10000)
        --ent.VehicleTable.Name = "This message is sponsored by: @@@  REMOVE THE FUCKING AUTO REVENGE TURRET  @@@"
        --ent.VehicleTable.Name = string.rep("\u{200B}", 500000)  -- Zero-width space
        ent.VehicleTable.Name = string.rep("a", 500000)  -- Zero-width space
        






    end)
            
    net.Receive("DupeEditor_ForceDupe", function(_, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        -- restore original if you want to undo later
        ent._OldCanTool = ent.CanTool
        ent.CanTool = true
        ent.AdminOnly = false

        -- duplicator flags are plain fields—this is OK
        ent.DisableDuplicator = false
        ent.DoNotDuplicate    = false
        ent.Spawnable         = true

        print(("[DupeEditor] %s is now fully toolable/duplicable"):format(ent))
    end)
        
        



    local function RemoveFunctions(t)
        for k,v in pairs(t) do
            if bannedTypes[type(v)] then
                --print(type(v) )
                print(k)
                t[k] = nil
            end
        end
        return t
    end

    -- there's no depth check, might cause errors, but it would be super rare
    local function CleanForNetBecauseNetDoesntLikeFunctionsInTables(tbl, seen)
        seen = seen or {}
        if seen[tbl] then return {} end
        seen[tbl] = true
        local out = {}
        for k,v in pairs(tbl) do
            if type(v) == "table" then
                out[k] = CleanForNetBecauseNetDoesntLikeFunctionsInTables(v, seen)
            elseif not bannedTypes[type(v)] then
                out[k] = v
            end
        end
        return out
    end

    local function GetNttTable(ent)
        
        local data = {}
        local raw = ent:GetTable()
        
        if ( ent.PreEntityCopy ) then ent:PreEntityCopy() end
        data = CleanForNetBecauseNetDoesntLikeFunctionsInTables(raw)
        --data = Merge( data, ent:GetTable() )
        -- do a local merge. edit: this shit ain't working
        --[[ ent:GetTable()
        for k, v in pairs(ent:GetTable()) do
            if type(v) ~= "function" then
                data[k] = v
            end
        end
        ]]--
        --data = ent:GetTable()
        
		if ( ent.PostEntityCopy ) then ent:PostEntityCopy() end

        local class = ent:GetClass()
        local args = duplicator.EntityClasses[class] and duplicator.EntityClasses[class].Args

        if args then
            for _, key in ipairs(args) do
                data[key] = ent[key]
            end
        end
        for k,v in pairs(ent:GetKeyValues()) do
            if not bannedTypes[type(v)] then
                data[k] = v
            end
        end

        -- duplicator.RegisterEntityClass("gmod_wire_expression2", MakeWireExpression2, "Pos", "Ang", "Model", "_original", "_name", "_inputs", "_outputs", "_vars", "inc_files", "filepath", "code_author")

        -- Source:
        -- https://github.com/Facepunch/garrysmod/blob/eedfd0de87da7617417a1361b899ca2366b7e78e/garrysmod/lua/includes/modules/duplicator.lua#L142
		data.Pos				= Vector(1.0, 1.0, 1.0) --ent:GetPos() --
		data.Angle				= ent:GetAngles()
		data.Class				= class
		data.Model				= ent:GetModel()
		data.Skin				= ent:GetSkin()
		data.Mins, data.Maxs	= ent:GetCollisionBounds()
		data.ColGroup			= ent:GetCollisionGroup()
		data.Name				= ent:GetName()
		data.WorkshopID			= ent:GetWorkshopID()
		data.CurHealth			= ent:Health()
		data.MaxHealth			= ent:GetMaxHealth()
		data.Persistent			= ent:GetPersistent()

		--data.Pos, data.Angle	= WorldToLocal( data.Pos, data.Angle, LocalPos, LocalAng )

		data.ModelScale			= ent:GetModelScale()
		if ( data.ModelScale == 1 ) then data.ModelScale = nil end

		if ( ent:CreatedByMap() ) then
			data.MapCreationID = ent:MapCreationID()
		end
		if ( ent.ClassOverride ) then data.Class = ent.ClassOverride end

        data.PhysicsObjects = ent.PhysicsObjects or {}

		data.FlexScale = ent:GetFlexScale()
		for i = 0, ent:GetFlexNum() do

			local w = ent:GetFlexWeight( i )
			if ( w != 0 ) then
				data.Flex = data.Flex or {}
				data.Flex[ i ] = w
			end

		end
        
		local bg = ent:GetBodyGroups()
		if ( bg ) then

			for k, v in pairs( bg ) do
				if ( ent:GetBodygroup( v.id ) > 0 ) then

					data.BodyG = data.BodyG or {}
					data.BodyG[ v.id ] = ent:GetBodygroup( v.id )

				end

			end

		end

        data._DuplicatedColor = ent:GetColor()
        if ( ent:GetMaterial() != "" ) then data._DuplicatedMaterial = ent:GetMaterial() end

        -- add rest ....

        if ( ent.GetNetworkVars ) then
			data.DT = ent:GetNetworkVars()
		end
        
        if ( ent.OnEntityCopyTableFinish ) then
			ent:OnEntityCopyTableFinish( data )
		end

        ----------------------------------
        -- final cleaning
        data = CleanForNetBecauseNetDoesntLikeFunctionsInTables(data)
        --print(data.Class)
        if data.Class == "gmod_tool" then
            data.Tool = {} -- hacky fix to prevent net overflow
        end
        return data
    end

    net.Receive("RequestEntityTable", function(_, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        local data = GetNttTable(ent)
        data = RemoveFunctions(data)

        net.Start("RequestEntityTable")
        net.WriteTable(data)
        net.Send(ply)
    end)

    net.Receive("RequestEntityTableClick", function(_, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        local data = GetNttTable(ent)
        data = RemoveFunctions(data)

        net.Start("RequestEntityTableClick")
        net.WriteTable(data)
        net.Send(ply)
    end)

    net.Receive("RequestEntityTableClickJSON", function(_, ply)
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end

        local data = GetNttTable(ent)
        data = RemoveFunctions(data)

        local json = util.TableToJSON(data, true)
        file.Write("dupe_editor_json.json", json)
    end)


end

if CLIENT then

    currentDupeTable = currentDupeTable or nil

    

    net.Receive("RequestEntityTable", function()
        local data = net.ReadTable()
        local node, entity = PendingRequest.node, PendingRequest.entity
        PopulateEntityTree(node, entity, data)
        PendingRequest = nil
    end)
    function RequestEntityTable(node, entity)
        PendingRequest = { node = node, entity = entity }
        net.Start("RequestEntityTable")
        net.WriteEntity(entity)
        net.SendToServer()
    end


    net.Receive("RequestEntityTableClick", function()
        local data = net.ReadTable()
        copiedEntityData = data
        PendingRequest = nil
    end)
    function RequestEntityTableClick(node, entity)
        PendingRequest = { node = node, entity = entity }
        net.Start("RequestEntityTableClick")
        net.WriteEntity(entity)
        net.SendToServer()
    end

    -- json save
    function RequestEntityTableClickJSON(entity)
        net.Start("RequestEntityTableClickJSON")
        net.WriteEntity(entity)
        net.SendToServer()
    end    


    function PopulateEntityTree(node, entity, items)
        
        -- fucking async
        if not items then
            RequestEntityTable(node, entity)
            return
        end

        local originalEntity = entity

        local arr = {}
        for k,v in pairs(items) do
            table.insert(arr, { key = k, value = v })
        end
        
        table.sort(arr, function(a, b)
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
        
        local count = 0
        for _ in pairs(arr) do count = count + 1 end

        for _, item in ipairs(arr) do
            local k = item.key
            local v = item.value

            local tmpValue = ValueToEditableString(v)
            
            -- make it easy to figure out the content
            if tmpValue == "table" and v.Class ~= nil then
                local count = 0
                --print(v)
                for _ in pairs(SafeIterate(v)) do
                    count = count + 1
                end
                
                tmpValue = tmpValue .. " (" .. v.Class .. ")"
                if v.Class == "gmod_wire_expression2" then
                    tmpValue = tmpValue .. "  \"" .. (v._name or "Unnamed") .. "\""
                end
            end
            
            if tmpValue == "table" then
                tmpValue = tmpValue .. " - entries: " .. CountEntries(v)
            end
            tmpValue = tmpValue:gsub("\n[^\n]*$", "")
            tmpValue = tmpValue:gsub("\n[^\n]*(\n?)$", "%1")
            tmpValue = tmpValue:gsub("\n", "")
            
            if #tmpValue > 50 and ValueToEditableString(v) ~= "table" then
                tmpValue = string.sub(tmpValue, 1, 47) .. "..."
            end
            
            local label = k .. ": " .. tmpValue
            local child = node:AddNode(label)
            
            child.DataKey = k
            child.DataValue = v
            
            -- Set icon based on data type
            if type(v) == "table" or type(v) == "Entity" or type(v) == "Player" or type(v) == "Weapon" then
                if IsEffectivelyEmpty(v) then
                    child:SetIcon("icon16/folder_delete.png") -- empty tables
                else
                    child:SetIcon("icon16/folder.png")
                end
                -- specific icon for those
                if type(v) == "Entity" or type(v) == "Player" then
                    child:SetIcon("icon16/brick.png")
                end
                if type(v) == "Weapon" then
                    child:SetIcon("icon16/gun.png")
                end

                child.DoClick = function(self)
                    if self.Populated then
                        self:SetExpanded(not self.Expanded) -- this should fix the un/expand bug
                    else
                        self:Clear()
                        PopulateEntityTree(self, self.DataValue)
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
            
            child:DockMargin(0, 0, 0, 5)
        end
    end

    function CreateEntityTreeView(entity, parent)
        if not IsValid(entity) then return end
        
        local tree = vgui.Create("DTree", parent)
        tree:Dock(FILL)
        
        local rootNode = tree:AddNode(entity:GetClass() .. " (#" .. entity:EntIndex() .. ")")
        rootNode:SetIcon("icon16/bricks.png")
        rootNode:SetExpanded(true)
        
        PopulateEntityTree(rootNode, entity)
        
        return tree
    end

    --OpenEntityListWindow = function()
    function OpenEntityListWindow()
        if IsValid(EntityListWindow) then
            EntityListWindow:Remove()
        end
        
        EntityListWindow = vgui.Create("DFrame")
        EntityListWindow:SetTitle("Entity List")
        EntityListWindow:SetSize(720, 460)
        EntityListWindow:Center()
        EntityListWindow:MakePopup()
        
        local SearchPanel = vgui.Create("DPanel", EntityListWindow)
        SearchPanel:Dock(TOP)
        SearchPanel:SetTall(30)
        SearchPanel:DockMargin(5, 5, 5, 0)
        SearchPanel.Paint = function() end -- Transparent
        
        local SearchLabel = vgui.Create("DLabel", SearchPanel)
        SearchLabel:SetText("Search:")
        SearchLabel:SetTextColor(Color(0, 0, 0))
        SearchLabel:SizeToContents()
        SearchLabel:Dock(LEFT)
        SearchLabel:DockMargin(5, 8, 5, 0)
        
        local SearchBox = vgui.Create("DTextEntry", SearchPanel)
        SearchBox:Dock(FILL)
        SearchBox:DockMargin(0, 5, 5, 5)
        
        -- Create filter options
        local FilterPanel = vgui.Create("DPanel", EntityListWindow)
        FilterPanel:Dock(TOP)
        FilterPanel:SetTall(30)
        FilterPanel:DockMargin(5, 0, 5, 5)
        FilterPanel.Paint = function() end
        
        local FilterLabel = vgui.Create("DLabel", FilterPanel)
        FilterLabel:SetText("Filter by:")
        FilterLabel:SetTextColor(Color(0, 0, 0))
        FilterLabel:SizeToContents()
        FilterLabel:Dock(LEFT)
        FilterLabel:DockMargin(5, 8, 5, 0)
        
        local TypeComboBox = vgui.Create("DComboBox", FilterPanel)
        TypeComboBox:Dock(LEFT)
        TypeComboBox:SetWide(150)
        TypeComboBox:DockMargin(0, 5, 5, 5)
        TypeComboBox:SetValue("All Entities")
        TypeComboBox:AddChoice("All Entities")
        TypeComboBox:AddChoice("Props")
        TypeComboBox:AddChoice("NPCs")
        TypeComboBox:AddChoice("Weapons")
        TypeComboBox:AddChoice("Vehicles")
        TypeComboBox:AddChoice("SENTS")
        TypeComboBox:AddChoice("M9K")
        TypeComboBox:AddChoice("Wire")
        TypeComboBox:AddChoice("Non-model")
        
        
        local EntityTree = vgui.Create("DTree", EntityListWindow)
        EntityTree:Dock(FILL)
        EntityTree:DockMargin(5, 0, 5, 5)
        
        local entityNodes = {}
        local categoryOrder = {
            ["Wire"]     = 1,
            ["NPCs"]      = 2,
            ["Vehicles"]  = 3,
            ["Props"]      = 4,
            ["SENTS"]     = 5,
            ["M9K"]     = 6,
            ["Weapons"]   = 7,
            ["Other"]     = 98,
            ["Non-model"] = 99,
        }

        local function RefreshEntityList(filter, searchText)
            EntityTree:Clear()
            entityNodes = {}


            
            local categoryNodes = {}
            local function GetCategoryNode(category)
                if not categoryNodes[category] then
                    local node = EntityTree:AddNode(category)
                    node:SetIcon("icon16/folder.png")
                    node:SetExpanded(true)
                    categoryNodes[category] = node
                end
                return categoryNodes[category]
            end

            -- Fetch and sort all entities by class
            local allEntities = ents.GetAll()
            table.sort(allEntities, function(a, b)
                return (a:GetClass() or "") < (b:GetClass() or "")
            end)

            -- Group entities by category
            local grouped = {}
            for _, ent in ipairs(allEntities) do
                local class = ent:GetClass() or "unknown class (dupe editor)"
                local IsWire = ent.IsWire or false

                local model = ent:GetModel() or ""
                local idx   = ent:EntIndex()
                
                if idx > 0 then -- ignore worldspawn
                    
                    local cat   = "Other"
                    local show  = (filter == "All Entities")
                    if class:match("^prop_p") then
                        cat, show = "Props",   show or filter == "Props"
                    elseif class:match("^npc_") then
                        cat, show = "NPCs",    show or filter == "NPCs"
                    elseif class:match("^weapon_") or class:match("^gmod_tool") then
                        cat, show = "Weapons", show or filter == "Weapons"
                    elseif string.find(string.lower(class), "vehicle") then
                        cat, show = "Vehicles", show or filter == "Vehicles"
                    elseif string.find(string.lower(class), "sent") then
                        cat, show = "SENTS", show or filter == "SENTS"
                    elseif string.find(string.lower(class), "m9k") then
                        cat, show = "M9K", show or filter == "M9K"
                    elseif class:match("^gmod_wire") or class:match("^wire_") or IsWire then
                        cat, show = "Wire",    show or filter == "Wire"
                    elseif model == "" then
                        cat, show = "Non-model", show or filter == "Non-model"
                    end
                    -- Search filter
                    if searchText and searchText ~= "" then
                        show = show and (
                            string.find(string.lower(class), string.lower(searchText), 1, true)
                            or string.find(tostring(idx), tostring(searchText), 1, true)
                        )
                    end
                    if show then
                        grouped[cat] = grouped[cat] or {}
                        table.insert(grouped[cat], {ent=ent, class=class, model=model, idx=idx})
                    end
                end
            end

            local cats = {}
            for cat in pairs(grouped) do table.insert(cats, cat) end
            table.sort(cats, function(a, b)
                return (categoryOrder[a] or 999) < (categoryOrder[b] or 999)
            end)

            for _, cat in ipairs(cats) do
                local parentNode = GetCategoryNode(cat)
                local list = grouped[cat]
                
                table.sort(list, function(a, b) return a.class < b.class end)
                for _, data in ipairs(list) do
                    local name = data.idx .. ": " .. data.class
                    if data.model ~= "" then
                        local short = string.match(data.model, ".*/([^/]+)$") or data.model
                        name = name .. " (" .. short .. ")"
                    end
                    local node = parentNode:AddNode(name)
                    node:SetIcon("icon16/brick.png")
                    node.EntityIndex = data.idx
                    node.EntityClass = data.class
                    entityNodes[#entityNodes+1] = {node=node, class=data.class, index=data.idx, category=cat}

                    
                    node.DoRightClick = function(self)
                        local menu = DermaMenu()
                        
                        menu:AddOption("Copy Entity Data (NET)", function()
                            local entity = Entity(self.EntityIndex)
                            if IsValid(entity) then
                                RequestEntityTableClick(node, entity)
                            end
                        end)
                        
                        menu:AddOption("Copy Entity Data (JSON)", function()
                            local ent = Entity(self.EntityIndex)
                            
                            RequestEntityTableClickJSON(ent)
                            if IsValid(ent) then
                                RequestEntityTableClickJSON(ent)
                                
                            end

                        
                        end)
                        
                        menu:AddOption("Force allow dupe", function()
                            local ent = Entity(self.EntityIndex)
                            
                            if not IsValid(ent) then return end

                            net.Start("DupeEditor_ForceDupe")
                                net.WriteEntity(ent)
                            net.SendToServer()
                        end)
                        
                        menu:AddOption("Crazy name", function()
                            local ent = Entity(self.EntityIndex)
                            
                            if not IsValid(ent) then return end

                            net.Start("DupeEditor_CrazyName")
                                net.WriteEntity(ent)
                            net.SendToServer()
                        end)
                    


                        menu:AddOption("Show Details", function()
                            local entity = Entity(self.EntityIndex)
                            if IsValid(entity) then
                                
                                local detailsWindow = vgui.Create("DFrame")
                                detailsWindow:SetTitle("Entity Details - " .. self.EntityClass .. " (" .. self.EntityIndex .. ")")
                                detailsWindow:SetSize(500, 600)
                                detailsWindow:Center()
                                detailsWindow:MakePopup()
                                detailsWindow.EntityIndex = self.EntityIndex
                                
                                local detailsTree = vgui.Create("DTree", detailsWindow)
                                detailsTree:Dock(FILL)
                                detailsTree:DockMargin(5, 5, 5, 5)
                                detailsTree:DockPadding(0, 0, 0, 40)
                                
                                local rootNode = detailsTree:AddNode(entity:GetClass() .. " (#" .. entity:EntIndex() .. ")")
                                rootNode:SetIcon("icon16/bricks.png")
                                rootNode:SetExpanded(true)
                                
                                PopulateEntityTree(rootNode, entity)
                                entityEditorCurrentNode = rootNode
                                
                            else
                                Derma_Message("Entity no longer valid!", "Error", "OK")
                            end
                        end)
                        menu:Open()
                    end
                end
            end
        end

        
        RefreshEntityList("All Entities", "")
        
        SearchBox.OnChange = function(self)
            RefreshEntityList(TypeComboBox:GetValue(), self:GetValue())
        end
        
        TypeComboBox.OnSelect = function(_, _, value)
            RefreshEntityList(value, SearchBox:GetValue())
        end
        
        local ButtonPanel = vgui.Create("DPanel", EntityListWindow)
        ButtonPanel:Dock(BOTTOM)
        ButtonPanel:SetTall(30)
        ButtonPanel:DockMargin(5, 0, 5, 5)
        ButtonPanel.Paint = function() end -- Transparent
        
        local RefreshButton = vgui.Create("DButton", ButtonPanel)
        RefreshButton:Dock(LEFT)
        RefreshButton:SetWide(100)
        RefreshButton:SetText("Refresh")
        RefreshButton.DoClick = function()
            RefreshEntityList(TypeComboBox:GetValue(), SearchBox:GetValue())
        end
        
        local CloseButton = vgui.Create("DButton", ButtonPanel)
        CloseButton:Dock(RIGHT)
        CloseButton:SetWide(100)
        CloseButton:SetText("Close")
        CloseButton.DoClick = function()
            EntityListWindow:Close()
        end
    end
end