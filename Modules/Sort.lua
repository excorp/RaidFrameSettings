local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local addon = addonTable.RaidFrameSettings

local Sort = addon:NewModule("Sort")
Mixin(Sort, addonTable.hooks)

local LS = LibStub("LibSpecialization")

local sortOpt

local enabled
local defaultRealm
local needToSort = 0
local isScheduled
local scheduler
local unit_priority = {}
local unit_frame = {}
local unit_spec = {}


local user_conf = {
    specShortCut = {
        ["암살"] = 259,
        ["무법"] = 260,
        ["무"] = {
            [260] = true, -- 무법
            [71] = true,  -- 무전
        },
        ["잠행"] = 261,
        ["잠"] = 261,

        ["혈죽"] = 250,
        ["혈"] = 250,
        ["냉죽"] = 251,
        ["냉"] = {
            [251] = true, -- 냉죽
            [64] = true,  -- 냉법
        },
        ["부죽"] = 252,
        ["부"] = 252,

        ["악딜"] = 557,
        ["악"] = {
            [557] = true, -- 악딜
            [581] = true, -- 악탱
            [266] = true, -- 악흑
        },
        ["악탱"] = 581,

        ["수드"] = 104,
        ["수"] = {
            [104] = true, -- 수드
            [256] = true, -- 수사
        },
        ["야드"] = 103,
        ["야"] = {
            [103] = true, -- 야드
            [253] = true, -- 야냥
        },
        ["조드"] = 102,
        ["조"] = 102,
        ["회드"] = 105,
        ["회"] = 105,

        ["보존"] = 1468,
        ["보"] = {
            [1468] = true, -- 보존
            [66]   = true, -- 보기
        },
        ["황폐"] = 1467,
        ["황"] = 1467,
        ["증강"] = 1473,
        ["증"] = 1473,

        ["야냥"] = 253,
        ["격냥"] = 254,
        ["격"] = 254,
        ["생냥"] = 255,
        ["생"] = 255,

        ["비법"] = 62,
        ["비"] = 62,
        ["화법"] = 63,
        ["화"] = 63,
        ["냉법"] = 64,


        ["양조"] = 268,
        ["양"] = 268,
        ["운무"] = 270,
        ["운"] = 270,
        ["풍운"] = 269,
        ["풍"] = 269,

        ["신기"] = 65,
        ["신"] = {
            [65]  = true, -- 신기
            [257] = true, -- 신사
        },
        ["보기"] = 66,
        ["징기"] = 70,
        ["징"] = 70,

        ["수사"] = 256,
        ["신사"] = 257,
        ["암사"] = 258,
        ["암"] = 258,

        ["정술"] = 262,
        ["정"] = 262,
        ["고술"] = 263,
        ["고"] = {
            [263] = true, -- 고술
            [265] = true, -- 고흑
        },
        ["복술"] = 264,
        ["복"] = 264,

        ["고흑"] = 265,
        ["악흑"] = 266,
        ["파흑"] = 257,
        ["파"] = 257,

        ["무전"] = 71,
        ["분전"] = 72,
        ["분"] = 72,
        ["전탱"] = 73,
    },
    classShortCut = {
        ["도적"] = "ROGUE",
        ["돋거"] = "ROGUE",
        ["도"] = "ROGUE",

        ["사냥꾼"] = "HUNTER",
        ["사냥"] = "HUNTER",
        ["냥꾼"] = "HUNTER",
        ["냥"] = "HUNTER",

        ["죽음의기사라고 세상 그 누가 입력하냐. 엄청나게 긴데"] = "DEATHKNIGHT",
        ["죽기"] = "DEATHKNIGHT",
        ["죽"] = "DEATHKNIGHT",

        ["성기사"] = "PALADIN",
        ["기사"] = "PALADIN",
        ["기"] = "PALADIN",

        ["전사"] = "WARRIOR",
        ["전"] = "WARRIOR",

        ["법사"] = "MAGE",
        ["벗바"] = "MAGE",
        ["법"] = "MAGE",

        ["사제"] = "PRIEST",
        ["사"] = "PRIEST",

        ["드루이드"] = "DRUID",
        ["드루"] = "DRUID",
        ["드"] = "DRUID",

        ["기원사"] = "EVOKER",
        ["기원"] = "EVOKER",

        ["주술사"] = "SHAMAN",
        ["주술"] = "SHAMAN",
        ["술사"] = "SHAMAN",
        ["술"] = "SHAMAN",

        ["수도사"] = "MONK",
        ["수도"] = "MONK",

        ["흑마"] = "WARLOCK",
        ["흑"] = "WARLOCK",

        ["악사"] = "DEMONHUNTER",
        ["악"] = "DEMONHUNTER",
    },
    rolePositionShortCut = {
        ["탱"] = {
            role = "TANK",
        },
        ["힐"] = {
            role = "HEALER",
        },
        ["딜"] = {
            role = "DAMAGER",
        },
        ["근"] = {
            role     = "DAMAGER",
            position = "MELEE"
        },
        ["근딜"] = {
            role     = "DAMAGER",
            position = "MELEE"
        },
        ["원"] = {
            role     = "DAMAGER",
            position = "RANGED"
        },
        ["원딜"] = {
            role     = "DAMAGER",
            position = "RANGED"
        },
    },
    position = {
        WARRIOR     = "MELEE",
        HUNTER      = "RANGED", -- Survival=MELEE
        PALADIN     = "MELEE",
        ROGUE       = "MELEE",
        PRIEST      = "RANGED",
        DEATHKNIGHT = "MELEE",
        SHAMAN      = "RANGED", -- Enhancement=MELEE
        MAGE        = "RANGED",
        WARLOCK     = "RANGED",
        MONK        = "MELEE",
        DRUID       = "RANGED", -- Guardian,Feral=MELEE
        DEMONHUNTER = "MELEE",
        EVOKER      = "RANGED",
    },
}

local function ClassSpecRolePositionForUnit(unit)
    local name, realm = UnitName(unit)
    if realm then
        name = name .. "-" .. realm
    end
    local localizedClass, englishClass, classIndex = UnitClass(unit)
    if unit_spec[name] then
        return englishClass, unit_spec[name].specId, unit_spec[name].role, unit_spec[name].position
    else
        local role = UnitGroupRolesAssigned(unit) --  TANK, HEALER, DAMAGER, NONE
        local position = user_conf.position[englishClass] or ""
        return englishClass, 0, role, position
    end
end


local frame_pos = {
    party = {},
    raidgroup = {},
    raid = {},
}
local group_type
local group_separated


local OnEditModeExited_id
local cvarsToUpdateContainer = {
    "HorizontalGroups",
    "KeepGroupsTogether",
}
local cvarsPatternsToRunSort = {
    "raidOptionDisplay.*",
    "pvpOptionDisplay.*",
    "raidFrames.*",
    "pvpFrames.*"
}

local secureframe
local memberHeader
local petHeader

local function RequestUpdateContainers()
    Sort:getFramePoint()
    Sort:TrySort()
end

local function RequestSort()
    Sort:TrySort(true)
end

local function OnLayoutsApplied()
    -- user or system changed their layout
    RequestUpdateContainers()
end

local function OnEditModeExited()
    -- user may have changed frame settings
    frame_pos = {
        party = {},
        raidgroup = {},
        raid = {},
    }
    RequestUpdateContainers()
end

local function OnRaidGroupLoaded()
    -- refresh group frame offsets once a group has been loaded
    RequestUpdateContainers()
end

local function OnRaidContainerSizeChanged()
    RequestUpdateContainers()
end

local function OnCvarUpdate(_, _, name)
    for _, cvar in ipairs(cvarsToUpdateContainer) do
        if name == cvar then
            RequestUpdateContainers()
            return
        end
    end

    for _, pattern in ipairs(cvarsPatternsToRunSort) do
        if string.match(name, pattern) then
            RequestSort()
            return
        end
    end
end

local function groupFunc(callback)
    if group_type == "party" then
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember" .. i]
            if frame then
                if callback(frame) then
                    return
                end
            end
        end
    elseif group_type == "raid" then
        if group_separated then
            for i = 1, 8 do
                for j = 1, 5 do
                    local frame = _G["CompactRaidGroup" .. i .. "Member" .. j]
                    if frame then
                        if callback(frame) then
                            return
                        end
                    end
                end
            end
        else
            for i = 1, 40 do
                local frame = _G["CompactRaidFrame" .. i]
                if frame then
                    if callback(frame) then
                        return
                    end
                end
            end
        end
    end
end

function Sort:clearPoints()
    groupFunc(function(frame)
        frame:ClearAllPoints()
    end)
end

function Sort:getFrameUnit(unit)
    local frame = unit_frame[unit]
    if frame and frame.unit == unit then
        return frame
    end
    groupFunc(function(frame)
        if frame and frame.unit == unit then
            unit_frame[unit] = frame
            return true
        end
    end)
    return unit_frame[unit]
end

function Sort:getFramePoint()
    group_type = IsInRaid() and "raid" or "party"
    if group_type == "raid" then
        group_separated = (isClassic and CompactRaidFrameManager_GetSetting("KeepGroupsTogether")) or (isRetail and EditModeManagerFrame:ShouldRaidFrameShowSeparateGroups())
    end

    if group_type == "party" then
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember" .. i]
            if frame and frame:GetNumPoints() > 0 and not frame_pos.party[i] then
                frame_pos.party[i] = {}
                for j = 1, frame:GetNumPoints() do
                    tinsert(frame_pos.party[i], { frame:GetPoint(j) })
                end
                frame:ClearAllPoints()
            end
        end
        -- TODO: ARENA will be supported in the future
    elseif group_type == "raid" then
        if group_separated then
            for i = 1, 8 do
                if not frame_pos.raidgroup[i] then
                    frame_pos.raidgroup[i] = {}
                end
                if #frame_pos.raidgroup[i] == 0 then
                    for j = 1, 5 do
                        local frame = _G["CompactRaidGroup" .. i .. "Member" .. j]
                        if frame and frame:GetNumPoints() > 0 then
                            frame_pos.raidgroup[i][j] = {}
                            for k = 1, frame:GetNumPoints() do
                                tinsert(frame_pos.raidgroup[i][j], { frame:GetPoint(k) })
                            end
                            frame:ClearAllPoints()
                        end
                    end
                end
            end
        else
            -- TODO: Not currently supported.
        end
    end
end

local function secureframeSetFrame(no, frame, p)
    -- frame:SetProtected()
    secureframe:SetFrameRef("frame" .. no, frame)
    if p then
        if p[2] then
            p[2]:SetProtected()
        end
        secureframe:SetAttributeNoHandler("frame" .. no .. "p1", p[1])
        secureframe:SetFrameRef("frame" .. no .. "p2", p[2])
        secureframe:SetAttributeNoHandler("frame" .. no .. "p3", p[3])
        secureframe:SetAttributeNoHandler("frame" .. no .. "p4", p[4])
        secureframe:SetAttributeNoHandler("frame" .. no .. "p5", p[5])
    end
end

function Sort:TrySort(reanchorOnly)
    if not enabled then
        return
    end

    if isScheduled then
        return
    end

    -- If in combat, have it called after the combat ends.
    if InCombatLockdown() then
        needToSort = reanchorOnly and 2 or 1
        return
    end

    -- No sorting in edit mode
    if isRetail and EditModeManagerFrame.editModeActive then
        return
    end

    -- Get group members and sort
    if not reanchorOnly then
        local priority = sortOpt
        local priority_sorted = {}
        for k, v in pairs(priority.priority) do
            if type(v) == "table" then
                v.key = k
                tinsert(priority_sorted, v)
            end
        end
        table.sort(priority_sorted, function(a, b)
            return a.priority > b.priority
        end)

        unit_priority = {}
        local member = {}
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                tinsert(member, "raid" .. i)
            end
        else
            tinsert(member, "player")
            for i = 1, 4 do
                tinsert(member, "party" .. i)
            end
        end
        for _, unit in pairs(member) do
            if UnitExists(unit) then
                local class, specId, role, position = ClassSpecRolePositionForUnit(unit)
                local name, realm = UnitName(unit)
                if not realm then
                    realm = defaultRealm
                end
                local fullname = (name or "알수없음") .. "-" .. realm
                local user = {
                    priority = 0,
                    position = 0,
                }
                for needle, v in pairs(priority.user) do
                    local rnp = user_conf.rolePositionShortCut[needle]
                    if v.fullname and (name == needle or fullname == needle) then
                        user = v
                        break
                    elseif v.spec and (user_conf.specShortCut[needle] and specId ~= 0 and ((type(user_conf.specShortCut[needle]) == "table" and user_conf.specShortCut[needle][specId]) or specId == user_conf.specShortCut[needle])) then
                        user = v
                        break
                    elseif v.rolepos and (rnp and role == rnp.role and (position == rnp.position or rnp.position == nil)) then
                        user = v
                        break
                    elseif v.class and (user_conf.classShortCut[needle] and class == user_conf.classShortCut[needle]) then
                        user = v
                        break
                    elseif v.name then
                        if string.find(fullname, needle) then
                            user = v
                            break
                        end
                    end
                end
                local groupno = 1
                if group_type == "raid" then
                    if group_separated then
                        local id = tonumber(string.sub(unit, 5))
                        if id then
                            groupno = select(3, GetRaidRosterInfo(id))
                        end
                    end
                end
                if not unit_priority[groupno] then
                    unit_priority[groupno] = {}
                end
                tinsert(unit_priority[groupno], {
                    token = unit,
                    class = priority.class[class] or 0,
                    role = priority.role[role] or 0,
                    position = priority.position[position] or 0,
                    user = user.priority,
                    user_position = UnitIsUnit(unit, "player") and priority.player and priority.player.position or user.position or 0,
                    name = fullname,
                })
            end
        end
        for _, party in pairs(unit_priority) do
            table.sort(party, function(a, b)
                for _, v in pairs(priority_sorted) do
                    if a[v.key] ~= b[v.key] then
                        if group_type == "raid" and v.key == "token" then
                            local id1 = tonumber(string.sub(a[v.key], 5))
                            local id2 = tonumber(string.sub(b[v.key], 5))
                            if not id1 or not id2 then
                                return id1
                            end
                            if v.reverse then
                                return id1 > id2
                            else
                                return id1 < id2
                            end
                        end
                        if v.key == "token" or v.key == "name" then
                            if v.reverse then
                                return a[v.key] > b[v.key]
                            else
                                return a[v.key] < b[v.key]
                            end
                        end
                        if v.reverse then
                            return a[v.key] < b[v.key]
                        else
                            return a[v.key] > b[v.key]
                        end
                    end
                end
                return a.token < b.token
            end)
        end

        -- Change the location of a user with a location set
        if priority.priority.player then
            local positioned = {}
            for groupno, party in pairs(unit_priority) do
                for k, v in pairs(party) do
                    if v.user_position > 0 then
                        if not positioned[groupno] then
                            positioned[groupno] = {}
                        end
                        tinsert(positioned[groupno], k)
                    end
                end
            end
            for groupno, v in pairs(positioned) do
                local insert = {}
                for i = #v, 1, -1 do
                    local idx = v[i]
                    table.insert(insert, unit_priority[groupno][idx])
                    table.remove(unit_priority[groupno], idx)
                end
                for _, info in pairs(insert) do
                    if #unit_priority[groupno] >= info.user_position then
                        table.insert(unit_priority[groupno], info.user_position, info)
                    else
                        table.insert(unit_priority[groupno], info)
                    end
                end
            end
        end
    end

    -- Repositioning
    self:clearPoints()
    local count = 0
    if group_type == "party" then
        local first
        local prev
        if unit_priority[1] then
            for k, v in pairs(unit_priority[1]) do
                local frame = self:getFrameUnit(v.token)
                if frame and frame_pos.party[k] then
                    for _, p in pairs(frame_pos.party[k]) do
                        count = count + 1
                        if not first then
                            first = frame
                            frame:SetPoint(p[1], _G.CompactPartyFrame, p[3], p[4], p[5])
                            secureframeSetFrame(count, frame, { p[1], _G.CompactPartyFrame, p[3], p[4], p[5] })
                        else
                            frame:SetPoint(p[1], prev, p[3], p[4], p[5])
                            secureframeSetFrame(count, frame, { p[1], prev, p[3], p[4], p[5] })
                        end
                        prev = frame
                    end
                end
            end
            if first and prev then
                _G.CompactPartyFrameBorderFrame:SetPoint("TOPLEFT", first, "TOPLEFT", -3, 5)
                _G.CompactPartyFrameBorderFrame:SetPoint("BOTTOMRIGHT", prev, "BOTTOMRIGHT", 8, -5 - 3)
            end
            -- Adjust the position of the first pet frame
            secureframe:SetAttributeNoHandler("petframeStart", count + 1)
            for i = 1, 5 do
                local frame = _G["CompactPartyFramePet" .. i]
                count = count + 1
                secureframeSetFrame(count, frame)
            end
            for i = 1, 5 do
                local frame = _G["CompactPartyFramePet" .. i]
                if frame.unit and frame.unitExists then
                    local point, pframe = frame:GetPoint()
                    if pframe and pframe:GetName():match("CompactPartyFrameMember") then
                        for j = 1, frame:GetNumPoints() do
                            local org = { frame:GetPoint(j) }
                            local parent = prev
                            if point == "TOPLEFT" then
                                parent = first
                            end
                            if parent then
                                frame:SetPoint(org[1], parent, org[3], org[4], org[5])
                            end
                        end
                    end
                end
            end
        end
    elseif group_type == "raid" then
        if group_separated then
            for subgroup, party in pairs(unit_priority) do
                local first
                local prev
                for k, v in pairs(party) do
                    local frame = self:getFrameUnit(v.token)
                    if frame and frame_pos.raidgroup[subgroup][k] then
                        for _, p in pairs(frame_pos.raidgroup[subgroup][k]) do
                            count = count + 1
                            if not first then
                                first = frame
                                -- frame:SetPoint(unpack(p))
                                -- secureframeSetFrame(count, frame, p)
                                frame:SetPoint(p[1], _G["CompactRaidGroup" .. subgroup], p[3], p[4], p[5])
                                secureframeSetFrame(count, frame, { p[1], _G["CompactRaidGroup" .. subgroup], p[3], p[4], p[5] })
                            else
                                frame:SetPoint(p[1], prev, p[3], p[4], p[5])
                                secureframeSetFrame(count, frame, { p[1], prev, p[3], p[4], p[5] })
                            end
                            prev = frame
                        end
                    end
                end
            end
            secureframe:SetAttributeNoHandler("petframeStart", count + 1)
        else
            -- TODO: This type is not currently supported
        end
    end

    secureframe:SetAttributeNoHandler("frameCount", count)

    needToSort = 0
end

local function InjectSecureHelpers(secureFrame)
    if not secureFrame.Execute then
        function secureFrame:Execute(body)
            return SecureHandlerExecute(self, body)
        end
    end

    if not secureFrame.WrapScript then
        function secureFrame:WrapScript(frame, script, preBody, postBody)
            return SecureHandlerWrapScript(frame, script, self, preBody, postBody)
        end
    end

    if not secureFrame.SetFrameRef then
        function secureFrame:SetFrameRef(label, refFrame)
            return SecureHandlerSetFrameRef(self, label, refFrame)
        end
    end
end

local function ConfigureHeader(header)
    InjectSecureHelpers(header)

    function header:UnitButtonCreated(index)
        local children = { header:GetChildren() }
        local frame = children[index]

        if not frame then
            addon:Print("Failed to find unit button " .. index)
            return
        end

        addon:RunWhenCombatEnds(function()
            -- the refreshUnitChange script doesn't capture when the unit is changed to nil
            -- which can happen when someone leaves the group, or a pet ceases to exist
            -- so we're really only interested in unit changing to nil here
            frame:SetAttribute("_onattributechanged", [[
                local secureframe = self:GetAttribute("secureframe")
                secureframe:SetAttribute("state-petstate", "ignore")
            ]])
            frame:SetAttribute("HaveSetAttributeHandler", true)
        end)
    end

    -- show as much as possible
    header:SetAttribute("showRaid", true)
    header:SetAttribute("showParty", true)
    header:SetAttribute("showPlayer", true)
    header:SetAttribute("showSolo", true)

    -- unit buttons template type
    header:SetAttribute("template", "SecureHandlerAttributeTemplate")

    -- fired when a new unit button is created
    header:SetAttribute("initialConfigFunction", [=[
        UnitButtonsCount = (UnitButtonsCount or 0) + 1

        -- self = the newly created unit button
        self:SetWidth(0)
        self:SetHeight(0)
        self:SetID(UnitButtonsCount)
        self:SetAttribute("secureframe", secureframe)

        RefreshUnitChange = [[
            -- Blizzard iterate over all the unit buttons and change their unit token so this snippet is called a lot
            -- we want to avoid spamming multiple sort attempts and only perform after all the buttons have been updated
            -- we can do this by changing our attribute to some temporary value which blizzard will change back when it re-evaluates state attributes
            local secureframe = self:GetAttribute("secureframe")
            secureframe:SetAttribute("state-petstate", "ignore")
        ]]
        self:SetAttribute("refreshUnitChange", RefreshUnitChange)

        if Header.CallMethod then
            Header:CallMethod("UnitButtonCreated", UnitButtonsCount)
        else
            -- backwards compatibility for wotlk private
            local run = control or self
            run:RunFor(Header, [[
                control:CallMethod("UnitButtonCreated")
            ]])
        end
    ]=])

    header:SetFrameRef("secureframe", secureframe)
    header:Execute([[
        Header = self
        secureframe = self:GetFrameRef("secureframe")
    ]])

    -- must be shown for it to work
    header:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    header:Show()
end

function Sort:OnEnable()
    enabled = true

    sortOpt = CopyTable(addon.db.profile.Sort)

    defaultRealm = GetRealmName() or ""

    if not secureframe then
        secureframe = CreateFrame("FRAME", nil, UIParent, "SecureHandlerStateTemplate")
        secureframe:SetAttributeNoHandler("InCombat", [[
            return SecureCmdOptionParse("[combat] true; false") == "true"
        ]])
        secureframe:SetAttribute("_onstate-petstate", [[
            if newstate == "ignore" then return end
            if not self:RunAttribute("InCombat") then
                return
            end
            local count = self:GetAttribute("frameCount")
            local petStart = self:GetAttribute("petframeStart")
            if count < 1 then
                return
            end
            for i = 1, petStart - 1 do
                local frame = self:GetFrameRef("frame" .. i)
                frame:ClearAllPoints()
            end
            for i = 1, petStart - 1 do
                local frame = self:GetFrameRef("frame" .. i)
                local p1 = self:GetAttribute("frame" .. i .. "p1")
                local p2 = self:GetFrameRef("frame" .. i .. "p2")
                local p3 = self:GetAttribute("frame" .. i .. "p3")
                local p4 = self:GetAttribute("frame" .. i .. "p4")
                local p5 = self:GetAttribute("frame" .. i .. "p5")
                frame:SetPoint(p1, p2, p3, p4, p5)
            end
            for i = petStart, count do
                local frame = self:GetFrameRef("frame" .. i)
                local point, pframe = frame:GetPoint()
                if pframe and pframe:GetName():match("CompactPartyFrameMember") then
                    local first = self:GetFrameRef("frame1")
                    local last = self:GetFrameRef("frame" .. (petStart - 1))
                    local point, _, relativePoint, offsetX, offsetY = frame:GetPoint()
                    frame:SetPoint(point, point == "TOPLEFT" and first or last, relativePoint, offsetX, offsetY)

                    local CompactPartyFrameBorderFrame = self:GetFrameRef("CompactPartyFrameBorderFrame")
                    CompactPartyFrameBorderFrame:SetPoint("TOPLEFT", first, "TOPLEFT", -3, 5)
                    CompactPartyFrameBorderFrame:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 8, -5 - 3)
                end
            end
        ]])

        memberHeader = CreateFrame("Frame", nil, UIParent, "SecureGroupHeaderTemplate")
        petHeader = CreateFrame("Frame", nil, UIParent, "SecureGroupPetHeaderTemplate")
        local headers = { memberHeader, petHeader }
        for _, header in ipairs(headers) do
            ConfigureHeader(header)
        end

        _G.CompactPartyFrameBorderFrame:SetProtected()
        secureframe:SetFrameRef("CompactPartyFrameBorderFrame", _G.CompactPartyFrameBorderFrame)
    end
    secureframe:SetAttributeNoHandler("frameCount", 0)
    secureframe:SetAttributeNoHandler("petframeStart", 0)

    self:getFramePoint()
    self:TrySort()

    LS:Register(addon, function(specId, role, position, sender, channel)
        unit_spec[sender] = {
            specId = specId,
            role = role,
            position = position,
        }
        Sort:TrySort()
    end)
    isScheduled = true
    if scheduler and not scheduler:IsCancelled() then
        scheduler:Cancel()
    end
    scheduler = C_Timer.NewTimer(1, function()
        isScheduled = false
        Sort:TrySort()
    end)
    LS:RequestSpecialization()

    if isRetail then
        OnEditModeExited_id = EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExited)
        self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", OnLayoutsApplied)
    end
    self:RegisterEvent("CVAR_UPDATE", OnCvarUpdate)
    if CompactRaidGroup_OnLoad then
        hooksecurefunc("CompactRaidGroup_OnLoad", OnRaidGroupLoaded)
    end
    if CompactRaidFrameContainer_OnSizeChanged then
        hooksecurefunc("CompactRaidFrameContainer_OnSizeChanged", OnRaidContainerSizeChanged)
    end
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        C_Timer.After(0, function() Sort:TrySort() end)
    end)
    self:RegisterEvent("UNIT_PET", function(event, unit)
        if _G.CompactRaidFrameContainer.displayPets then
            if unit == "player" or strsub(unit, 1, 4) == "raid" or strsub(unit, 1, 5) == "party" then
                C_Timer.After(0, function() Sort:TrySort(true) end)
            end
        end
    end)
    self:RegisterEvent("PLAYER_ROLES_ASSIGNED", function()
        C_Timer.After(0, function() Sort:TrySort() end)
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if needToSort ~= 0 then
            C_Timer.After(0, function() Sort:TrySort(needToSort == 2) end)
        end
    end)

    RegisterAttributeDriver(secureframe, "state-petstate", "[pet] pet; nopet;")
end

function Sort:OnDisable()
    enabled = false
    self:DisableHooks()
    UnregisterAttributeDriver(secureframe, "state-petstate")

    LS:Unregister(addon)

    if scheduler and not scheduler:IsCancelled() then
        scheduler:Cancel()
    end

    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if isRetail then
        EventRegistry:UnregisterCallback("EditMode.Exit", OnEditModeExited_id)
        self:UnregisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    end
    self:UnregisterEvent("PLAYER_ROLES_ASSIGNED")
    self:UnregisterEvent("CVAR_UPDATE")

    -- restore anchor
    self:clearPoints()
    local first, prev
    for i, ps in pairs(frame_pos.party) do
        local frame = _G["CompactPartyFrameMember" .. i]
        if frame and ps then
            if not first then
                first = frame
            end
            for _, p in pairs(ps) do
                frame:SetPoint(unpack(p))
            end
            if frame:IsShown() then
                prev = frame
            end
        end
    end
    if first and prev then
        _G.CompactPartyFrameBorderFrame:SetPoint("TOPLEFT", first, "TOPLEFT", -3, 5)
        _G.CompactPartyFrameBorderFrame:SetPoint("BOTTOMRIGHT", prev, "BOTTOMRIGHT", 8, -5 - 3)
    end
    -- Adjust the position of the first pet frame
    for i = 1, 5 do
        local frame = _G["CompactPartyFramePet" .. i]
        if frame.unit and frame.unitExists then
            local point, pframe = frame:GetPoint()
            if pframe and pframe:GetName():match("CompactPartyFrameMember") then
                for j = 1, frame:GetNumPoints() do
                    local org = { frame:GetPoint(j) }
                    local parent = prev
                    if point == "TOPLEFT" then
                        parent = first
                    end
                    if parent then
                        frame:SetPoint(org[1], parent, org[3], org[4], org[5])
                    end
                end
                break
            end
        end
    end
    for i, v in pairs(frame_pos.raidgroup) do
        for j, ps in pairs(v) do
            local frame = _G["CompactRaidGroup" .. i .. "Member" .. j]
            if frame and ps then
                for _, p in pairs(ps) do
                    frame:SetPoint(unpack(p))
                end
            end
        end
    end
    frame_pos = {
        party = {},
        raidgroup = {},
        raid = {},
    }
end
