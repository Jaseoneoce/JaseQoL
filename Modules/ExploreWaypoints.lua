-------------------------------------------------------------------------------
--  JaseTools: Explore challenge waypoints
--
--  In Legacy Challenges (Adventure > Eastern Kingdoms / Kalimdor), every place
--  of an "Explore <zone>" challenge you haven't found yet gets a small button
--  with its coordinates, where the tick would be:
--    click          TomTom waypoint there, and the world map opens on the zone
--                   with the place outlined and marked
--    shift-click    the same for every place still missing in that challenge
--    ctrl-click     waypoint only (the map stays shut)
--    right-click    clear the waypoints and the map marks
--  The place is outlined and filled in pink on the map (OpenMap's or the
--  game's own). Two more switches (also in OpenMap's menu) draw every place
--  still missing the same way: in the zone the map shows and the one you're
--  in, or in every zone.
--  A place drops off by itself once it's explored. Without TomTom the game's
--  own map pin is used where the client has one, and chat gives the coords.
--
--  Where to stand comes from Data\ExploreSpots.lua (OpenMap's exploration
--  data). The Legacy window's rows are found by their text, not by frame
--  names, so a change to that window's layout only loses the buttons.
-------------------------------------------------------------------------------
local _, JQ = ...
local KEY = "exploreWaypoints"
local KEY_ZONE, KEY_ALL = "exploreShowZone", "exploreShowAll"
local WHERE = "explore waypoints"

local GOLD = { 1, 0.82, 0.25 }

-------------------------------------------------------------------------------
--  The places of a challenge: its ticks, matched to the spots
-------------------------------------------------------------------------------
local function Plain(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- challengeID -> { byArea = { [areaID] = spot }, byName = { [name] = spot } }
local indexed = {}
local function Index(id)
    if indexed[id] ~= nil then return indexed[id] end
    local data = JQ.ExploreSpots and JQ.ExploreSpots[id]
    if not data then indexed[id] = false return false end
    local idx = { map = data.map, byArea = {}, byName = {} }
    for _, spot in ipairs(data) do
        for area in spot[1]:gmatch("%d+") do
            area = tonumber(area)
            idx.byArea[area] = spot
            local name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)
            if type(name) == "string" and name ~= "" then idx.byName[name] = spot end
        end
    end
    indexed[id] = idx
    return idx
end

-- The ticks of a challenge that have a spot: { { name, done, x, y, map, outline, id, index }, ... }
local function Places(id)
    local idx = Index(id)
    if not idx or type(GetAchievementNumCriteria) ~= "function" then return nil end
    local ok, count = pcall(GetAchievementNumCriteria, id)
    if not ok or type(count) ~= "number" then return nil end
    local out = {}
    for i = 1, count do
        local okC, text, _, done, _, _, _, _, asset = pcall(GetAchievementCriteriaInfo, id, i)
        if okC and type(text) == "string" then
            local name = Plain(text)
            local spot = (type(asset) == "number" and idx.byArea[asset]) or idx.byName[name]
            if spot then
                out[#out + 1] = { name = name, done = done == true, x = spot[2], y = spot[3], map = idx.map,
                    outline = spot[4], id = id, index = i }
            end
        end
    end
    return out
end

local function Coords(p) return ("%.1f, %.1f"):format(p.x * 100, p.y * 100) end
local function ZoneName(map)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name or "?"
end

-------------------------------------------------------------------------------
--  The places being shown: waypoints and map marks
-------------------------------------------------------------------------------
local targets = {}              -- { name, x, y, map, outline, id, index, uid }
local Layout                    -- (below) draws the map marks

local function RemoveWaypoint(t)
    if t.uid and TomTom and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, t.uid) end
    t.uid = nil
end

local function ClearTargets(quiet)
    local had = #targets > 0
    for _, t in ipairs(targets) do RemoveWaypoint(t) end
    wipe(targets)
    if had and C_Map and C_Map.ClearUserWaypoint and not TomTom then pcall(C_Map.ClearUserWaypoint) end
    if Layout then Layout(true) end
    if had and not quiet then JQ.Print("Explore waypoints cleared.") end
end

local function AddWaypoint(t, first)
    if TomTom and TomTom.AddWaypoint then
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, t.map, t.x, t.y, {
            title = t.name, from = "JaseTools", persistent = false,
            minimap = true, world = true, crazy = first, cleardistance = 0,
        })
        if ok and type(uid) == "table" then t.uid = uid end
        return ok
    end
    -- no TomTom: the game's own map pin, where this client has one (one at a time)
    if first and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local ok = pcall(function()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(t.map, t.x, t.y))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end)
        return ok
    end
    return false
end

local function ShowMap(map)
    if not WorldMapFrame then return end
    if not WorldMapFrame:IsShown() then
        if ToggleWorldMap then ToggleWorldMap() elseif ShowUIPanel then ShowUIPanel(WorldMapFrame) end
    end
    if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(map) end
end

-- places: a list from Places(); openMap: bring the world map up on the zone
local function Go(places, openMap)
    if #places == 0 then return end
    ClearTargets(true)
    for i, p in ipairs(places) do
        local t = { name = p.name, x = p.x, y = p.y, map = p.map, outline = p.outline, id = p.id, index = p.index }
        targets[#targets + 1] = t
        AddWaypoint(t, i == 1)
    end
    local zone = ZoneName(places[1].map)
    if #places == 1 then
        JQ.Print(("%s: %s %s."):format(places[1].name, zone, Coords(places[1])))
    else
        JQ.Print(("%d places to explore in %s:"):format(#places, zone))
        for _, p in ipairs(places) do print(("   %s  |cffffd040%s|r"):format(p.name, Coords(p))) end
    end
    if not TomTom then JQ.Print("TomTom isn't loaded, so there's no arrow: the map shows where to go.") end
    if openMap then JQ.Try(WHERE .. " (opening the map)", ShowMap, places[1].map) end
    Layout(true)
end

-------------------------------------------------------------------------------
--  Map marks: each place's ground outlined and filled in pink on the world
--  map (OpenMap's stitched map or the game's own), with a dot and its name.
--  Drawn for the places clicked, and with the two switches for every place
--  still missing in the zone (the one the map shows and the one you're in) or
--  in every zone.
-------------------------------------------------------------------------------
local PINK = { 1, 0.36, 0.76 }
local LINE_ALPHA, FILL_ALPHA = 0.95, 0.28
local host, lines, fills, marks = nil, {}, {}, {}
local nLine, nFill, nMark = 0, 0, 0
local lastSig

local B64 = {}
do
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #chars do B64[chars:byte(i)] = i - 1 end
end
local function Decode(s, i)
    return ((B64[s:byte(i)] or 0) * 64 + (B64[s:byte(i + 1)] or 0)) / 4095 * 1.25 - 0.125
end

-- An outline's loops as points of its zone's map ({ x1, y1, x2, y2, ... } each), and how far down it reaches.
local shapes = {}
local function Shape(outline)
    local s = shapes[outline]
    if s then return s end
    s = { loops = {}, top = math.huge, bottom = -math.huge }
    for loop in outline:gmatch("%S+") do
        local pts = {}
        for i = 1, #loop - 3, 4 do
            local x, y = Decode(loop, i), Decode(loop, i + 2)
            pts[#pts + 1], pts[#pts + 2] = x, y
            if y < s.top then s.top = y end
            if y > s.bottom then s.bottom = y end
        end
        if #pts >= 4 then s.loops[#s.loops + 1] = pts end
    end
    shapes[outline] = s
    return s
end

-- A point of a zone's map (0..1) on the map the world map shows now (0..1 of its canvas), or nil.
local function Projector(map, shown)
    if map == shown then return function(x, y) return x, y end end
    local api = OpenMapAPI
    if api and api.IsStitched and api.WorldFromMap and api.MapFromWorld then
        local ok, on = pcall(api.IsStitched)
        if ok and on then
            -- both maps are rectangles of OpenMap's world: two corners give the whole mapping
            local ok1, u0, v0 = pcall(api.WorldFromMap, map, 0, 0)
            local ok2, u1, v1 = pcall(api.WorldFromMap, map, 1, 1)
            if ok1 and ok2 and u0 and u1 then
                local ok3, x0, y0 = pcall(api.MapFromWorld, shown, u0, v0)
                local ok4, x1, y1 = pcall(api.MapFromWorld, shown, u1, v1)
                if ok3 and ok4 and x0 and x1 then
                    return function(x, y) return x0 + x * (x1 - x0), y0 + y * (y1 - y0) end
                end
            end
        end
    end
    if C_Map and C_Map.GetMapRectOnMap then
        local ok, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, map, shown)
        if ok and type(minX) == "number" and type(maxY) == "number" and maxX > minX then
            return function(x, y) return minX + x * (maxX - minX), minY + y * (maxY - minY) end
        end
    end
end

local function Canvas()
    if not WorldMapFrame then return nil end
    if WorldMapFrame.GetCanvas then return WorldMapFrame:GetCanvas() end
    return WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

-- The places still missing, by challenge (kept until something is explored).
local missingBy, mapToId
local function MissingOf(id)
    missingBy = missingBy or {}
    local list = missingBy[id]
    if not list then
        list = {}
        for _, p in ipairs(Places(id) or {}) do
            if not p.done then list[#list + 1] = p end
        end
        missingBy[id] = list
    end
    return list
end

-- The Explore challenge of a map (or of the zone it's part of: a city, a cave).
local function ChallengeOf(map)
    if not mapToId then
        mapToId = {}
        for id, data in pairs(JQ.ExploreSpots or {}) do mapToId[data.map] = id end
    end
    for _ = 1, 4 do
        if type(map) ~= "number" then return nil end
        if mapToId[map] then return mapToId[map] end
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        map = info and info.parentMapID
    end
end

local function PlayerMap()
    local ok, map = pcall(function() return C_Map.GetBestMapForUnit("player") end)
    return ok and type(map) == "number" and map or nil
end

local function Drawing()
    if #targets > 0 then return true end
    return JQ.IsEnabled(KEY) and (JQ.IsEnabled(KEY_ZONE) or JQ.IsEnabled(KEY_ALL))
end

-- What to draw: { { p = place, target = bool }, ... }, the clicked places first.
local function Wanted(shown)
    local items, seen = {}, {}
    local function Add(p, target)
        local k = p.id * 1000 + p.index
        if not seen[k] then
            seen[k] = true
            items[#items + 1] = { p = p, target = target }
        end
    end
    for _, t in ipairs(targets) do Add(t, true) end
    if JQ.IsEnabled(KEY) then
        if JQ.IsEnabled(KEY_ALL) then
            for id in pairs(JQ.ExploreSpots or {}) do
                for _, p in ipairs(MissingOf(id)) do Add(p, false) end
            end
        elseif JQ.IsEnabled(KEY_ZONE) then
            local a, b = ChallengeOf(shown), ChallengeOf(PlayerMap())
            if a then for _, p in ipairs(MissingOf(a)) do Add(p, false) end end
            if b and b ~= a then for _, p in ipairs(MissingOf(b)) do Add(p, false) end end
        end
    end
    return items
end

local function Mark()
    nMark = nMark + 1
    local m = marks[nMark]
    if m then return m end
    m = CreateFrame("Frame", nil, host)
    m:SetSize(16, 16)
    m.glow = m:CreateTexture(nil, "ARTWORK")
    m.glow:SetPoint("CENTER")
    m.glow:SetSize(34, 34)
    m.dot = m:CreateTexture(nil, "OVERLAY")
    m.dot:SetPoint("CENTER")
    local atlas = "WhiteCircle-RaidBlips"
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        m.glow:SetAtlas(atlas)
        m.dot:SetAtlas(atlas)
    else
        m.glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        m.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    m.glow:SetVertexColor(PINK[1], PINK[2], PINK[3], 0.4)
    m.dot:SetVertexColor(PINK[1], PINK[2], PINK[3], 1)
    m.label = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    m.label:SetPoint("BOTTOM", m, "TOP", 0, 4)
    m.label:SetTextColor(1, 0.84, 0.94)
    m.label:SetShadowColor(0, 0, 0, 1)
    m.label:SetShadowOffset(1, -1)
    -- a slow pulse on the places clicked, so the eye finds them
    m.pulse = m.glow:CreateAnimationGroup()
    m.pulse:SetLooping("BOUNCE")
    local a = m.pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.25)
    a:SetDuration(0.8)
    marks[nMark] = m
    return m
end

local function Segment(x1, y1, x2, y2, w, h, thickness)
    nLine = nLine + 1
    local l = lines[nLine]
    if not l then
        l = host:CreateLine(nil, "ARTWORK")
        l:SetColorTexture(PINK[1], PINK[2], PINK[3], LINE_ALPHA)
        lines[nLine] = l
    end
    l:SetThickness(thickness)
    l:SetStartPoint("TOPLEFT", host, x1 * w, -y1 * h)
    l:SetEndPoint("TOPLEFT", host, x2 * w, -y2 * h)
    l:Show()
end

-- The inside of a shape, as rows of strips (there's no filled polygon to draw with):
-- each row's strips run between the outline's crossings, in and out by turns.
local crossings = {}
local function FillShape(shape, project, rows, w, h)
    local step = (shape.bottom - shape.top) / rows
    if step <= 0 then return end
    for row = 0, rows - 1 do
        local y = shape.top + (row + 0.5) * step
        local n = 0
        for _, pts in ipairs(shape.loops) do
            local count = #pts
            local x1, y1 = pts[count - 1], pts[count]
            for i = 1, count - 1, 2 do
                local x2, y2 = pts[i], pts[i + 1]
                if (y1 <= y) ~= (y2 <= y) then
                    n = n + 1
                    crossings[n] = x1 + (y - y1) / (y2 - y1) * (x2 - x1)
                end
                x1, y1 = x2, y2
            end
        end
        for i = n + 1, #crossings do crossings[i] = nil end
        table.sort(crossings)
        for i = 1, n - 1, 2 do
            local ax, ay = project(crossings[i], y - step / 2)
            local bx, by = project(crossings[i + 1], y + step / 2)
            if ax and bx then
                nFill = nFill + 1
                local f = fills[nFill]
                if not f then
                    f = host:CreateTexture(nil, "BACKGROUND")
                    f:SetColorTexture(PINK[1], PINK[2], PINK[3], FILL_ALPHA)
                    fills[nFill] = f
                end
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", host, "TOPLEFT", ax * w, -ay * h)
                f:SetPoint("BOTTOMRIGHT", host, "TOPLEFT", bx * w, -by * h)
                f:Show()
            end
        end
    end
end

local function Draw()
    local canvas = Canvas()
    local shown = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local w, h = canvas:GetSize()
    local scale = canvas:GetScale() or 1
    if scale <= 0 then scale = 1 end
    local inv = math.max(0.05, math.min(20, 1 / scale))   -- marks stay the same size on screen
    local level = canvas:GetFrameLevel() + 400
    if OpenMapAPI and OpenMapAPI.ArtTopLevel then
        local ok, top = pcall(OpenMapAPI.ArtTopLevel)
        if ok and type(top) == "number" then level = math.max(level, top + 20) end
    end
    host:SetFrameLevel(math.min(level, 9990))

    nLine, nFill, nMark = 0, 0, 0
    local projectors = {}
    for _, item in ipairs(shown and Wanted(shown) or {}) do
        local p = item.p
        local project = projectors[p.map]
        if project == nil then
            project = Projector(p.map, shown) or false
            projectors[p.map] = project
        end
        local cx, cy
        if project then cx, cy = project(p.x, p.y) end
        -- (only what's on the canvas or near it: the rest is out of sight)
        if cx and cy and cx > -3 and cx < 4 and cy > -3 and cy < 4 then
            local _, top = project(0, 0)
            local _, bottom = project(0, 1)
            local zonePx = math.abs((bottom or 0) - (top or 0)) * h * scale    -- the zone's height on screen
            local shape = Shape(p.outline or "")
            local thickness = (item.target and 2.5 or 1.5) * inv
            for _, pts in ipairs(shape.loops) do
                local count = #pts
                local px, py = project(pts[count - 1], pts[count])
                for i = 1, count - 1, 2 do
                    local x, y = project(pts[i], pts[i + 1])
                    if x and px then Segment(px, py, x, y, w, h, thickness) end
                    px, py = x, y
                end
            end
            if #shape.loops > 0 then
                -- strips about 4 px tall on screen: fewer the further out the map is
                local rows = math.ceil((shape.bottom - shape.top) * zonePx / 4)
                FillShape(shape, project, math.max(2, math.min(28, rows)), w, h)
            end
            local m = Mark()
            m:SetScale(inv)
            m:ClearAllPoints()
            m:SetPoint("CENTER", host, "TOPLEFT", cx * w / inv, -cy * h / inv)
            if item.target then
                m.dot:SetSize(14, 14)
                m.glow:Show()
                m.label:SetText(("%s  %s"):format(p.name, Coords(p)))
                if not m.pulse:IsPlaying() then m.pulse:Play() end
            else
                m.dot:SetSize(8, 8)
                m.pulse:Stop()
                m.glow:Hide()
                m.label:SetText(zonePx >= 320 and p.name or "")   -- names once the zone is big enough to read them
            end
            m:Show()
        end
    end
    for i = nLine + 1, #lines do lines[i]:Hide() end
    for i = nFill + 1, #fills do fills[i]:Hide() end
    for i = nMark + 1, #marks do
        marks[i].pulse:Stop()
        marks[i]:Hide()
    end
end

-- Draws the marks again when the map, its zoom or its size changed (force: now).
Layout = function(force)
    local canvas = Canvas()
    if not canvas then return end
    if not Drawing() then
        if host then host:Hide() end
        lastSig = nil
        return
    end
    if not host then
        host = CreateFrame("Frame", nil, canvas)
        host:SetAllPoints(canvas)
        local since = 0
        host:SetScript("OnUpdate", function(_, elapsed)
            since = since + elapsed
            if since < 0.15 then return end
            since = 0
            Layout()
        end)
    end
    host:Show()
    if not canvas:IsVisible() then return end
    local stitched = OpenMapAPI and OpenMapAPI.IsStitched and select(2, pcall(OpenMapAPI.IsStitched)) and 1 or 0
    local scale = canvas:GetScale() or 1
    -- (the marks ride the canvas as it zooms: made again only once the zoom has moved a fair step)
    local zoomStep = math.floor(math.log(scale > 0 and scale or 1) / math.log(1.25) + 0.5)
    local sig = table.concat({ tostring(WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()), zoomStep,
        ("%d"):format(canvas:GetWidth() or 0), #targets, stitched, tostring(PlayerMap()),
        JQ.IsEnabled(KEY_ZONE) and 1 or 0, JQ.IsEnabled(KEY_ALL) and 1 or 0 }, ":")
    if not force and sig == lastSig then return end
    lastSig = sig
    JQ.Try(WHERE .. " (map marks)", Draw)
end

-- Something was explored, or a switch moved: the lists are read again and the map redrawn.
local function Refresh()
    missingBy = nil
    lastSig = nil
    Layout(true)
end

-------------------------------------------------------------------------------
--  The buttons on the challenge's rows
-------------------------------------------------------------------------------
local scrollBox, page
local buttons, used = {}, 0
local mine = setmetatable({}, { __mode = "k" })     -- our own buttons (never searched for rows)

local function ButtonEnter(self)
    local p = self.place
    if not p then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(p.name, GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(("%s  %s"):format(ZoneName(p.map), Coords(p)), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(TomTom and "Click: TomTom waypoint, and show it on the map" or "Click: show it on the map", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Shift-click: every place still missing here", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Ctrl-click: waypoint only", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click: clear", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function ButtonClick(self, mouse)
    local p = self.place
    if not p then return end
    if mouse == "RightButton" then ClearTargets() return end
    local list = { p }
    if IsShiftKeyDown() then
        list = {}
        for _, q in ipairs(Places(p.id) or {}) do
            if not q.done then list[#list + 1] = q end
        end
    end
    JQ.Try(WHERE, Go, list, not IsControlKeyDown())
end

local function Button()
    used = used + 1
    local b = buttons[used]
    if b then return b end
    b = CreateFrame("Button", nil, UIParent)
    mine[b] = true
    b:SetHeight(16)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)
    b:SetScript("OnEnter", ButtonEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", ButtonClick)
    buttons[used] = b
    return b
end

local function HideButtons()
    for i = 1, #buttons do
        buttons[i].place = nil
        buttons[i]:Hide()
    end
    used = 0
end

-- Every FontString under a frame (not ours), a few levels down.
local function EachText(frame, depth, fn)
    if depth > 6 or not frame or mine[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local r = regions[i]
        if r.GetObjectType and r:GetObjectType() == "FontString" then fn(r, frame) end
    end
    local children = { frame:GetChildren() }
    for i = 1, #children do EachText(children[i], depth + 1, fn) end
end

local function Attach(fs, row, entry, place)
    local b = Button()
    b.place = place
    b.text:SetText(Coords(place))
    b:SetWidth(math.max(40, (b.text:GetStringWidth() or 40) + 8))
    b:SetParent(row)
    b:SetFrameLevel(row:GetFrameLevel() + 5)
    b:ClearAllPoints()
    -- a row of its own (the name's box): at its right edge, where the tick goes; else after the name
    local width = row:GetWidth() or 0
    if row ~= entry and width > 60 and width < 420 then
        b:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    else
        b:SetPoint("LEFT", fs, "LEFT", (fs:GetStringWidth() or 0) + 8, 0)
    end
    b:Show()
end

local function Scan()
    HideButtons()
    if not JQ.IsEnabled(KEY) or not (scrollBox and page and page:IsVisible()) then return end
    scrollBox:ForEachFrame(function(entry)
        local data = entry.GetElementData and entry:GetElementData()
        local id = type(data) == "table" and data.id
        if type(id) ~= "number" or not (JQ.ExploreSpots and JQ.ExploreSpots[id]) then return end
        local missing, any = {}, false
        for _, p in ipairs(Places(id) or {}) do
            if not p.done then missing[p.name] = p; any = true end
        end
        if not any then return end
        EachText(entry, 0, function(fs, row)
            local p = missing[Plain(fs:GetText()) or ""]
            if p and fs:IsVisible() then
                missing[p.name] = nil       -- one button a place
                Attach(fs, row, entry, p)
            end
        end)
    end)
end

local queued = false
local function QueueScan()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        JQ.Try(WHERE .. " (buttons)", Scan)
    end)
    -- once more, in case the rows were laid out a moment later
    C_Timer.After(0.2, function() JQ.Try(WHERE .. " (buttons)", Scan) end)
end

local hooked = setmetatable({}, { __mode = "k" })
local function HookEntry(entry)
    if entry and entry.Init and not hooked[entry] then
        hooked[entry] = true
        hooksecurefunc(entry, "Init", QueueScan)
    end
end

local function Setup()
    if scrollBox then return end
    page = LegacySystemFrame and LegacySystemFrame.ChallengesPage
    local box = page and page.DetailPane and page.DetailPane.ScrollBox
    if not (box and box.ForEachFrame) then return end
    scrollBox = box
    box:ForEachFrame(HookEntry)
    if ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
        ScrollUtil.AddAcquiredFrameCallback(box, function(_, entry)
            HookEntry(entry)
            QueueScan()
        end, buttons)
    end
    page:HookScript("OnShow", QueueScan)
    QueueScan()
end

-------------------------------------------------------------------------------
--  Explored: the place drops off, the buttons follow
-------------------------------------------------------------------------------
local checking = false
local function Recheck()
    checking = false
    local changed = false
    for i = #targets, 1, -1 do
        local t = targets[i]
        local ok, _, _, done = pcall(GetAchievementCriteriaInfo, t.id, t.index)
        if ok and done == true then
            RemoveWaypoint(t)
            table.remove(targets, i)
            changed = true
            JQ.Print(t.name .. " explored.")
        end
    end
    if changed and #targets == 0 and C_Map and C_Map.ClearUserWaypoint and not TomTom then pcall(C_Map.ClearUserWaypoint) end
    Refresh()
    if page and page:IsVisible() then QueueScan() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
for _, name in ipairs({ "MAP_EXPLORATION_UPDATED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "CRITERIA_UPDATE", "ACHIEVEMENT_EARNED" }) do
    pcall(ev.RegisterEvent, ev, name)
end
ev:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_LegacySystem" then JQ.Try(WHERE .. " (setting up)", Setup) end
        return
    end
    if checking or not (Drawing() or (page and page:IsVisible())) then return end
    checking = true
    -- the game ticks the challenge a moment after the place is found
    C_Timer.After(1.5, function() JQ.Try(WHERE, Recheck) end)
end)

JQ.AddModule({
    key = KEY,
    label = "Explore challenge waypoints",
    description = "In Legacy Challenges, each place of an Explore challenge you haven't found yet shows its coordinates as a button. Click it for a TomTom waypoint and to see the place outlined on the world map; shift-click for every place still missing in that challenge; right-click to clear. Places drop off as you explore them.",
    default = true,
    onLoad = function()
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
        if loaded and loaded("Blizzard_LegacySystem") then JQ.Try(WHERE .. " (setting up)", Setup) end
        if WorldMapFrame then
            WorldMapFrame:HookScript("OnShow", function() JQ.Try(WHERE .. " (map marks)", Refresh) end)
        end
        -- the two map switches in OpenMap's own menu too
        local api = OpenMapAPI
        if api and api.RegisterMenuToggle then
            for _, t in ipairs({ { KEY_ZONE, "Places to explore: this zone" }, { KEY_ALL, "Places to explore: every zone" } }) do
                pcall(api.RegisterMenuToggle, "JaseTools", {
                    id = t[1], label = t[2], section = "JaseTools", tab = "show",
                    get = function() return JQ.IsEnabled(KEY) and JQ.IsEnabled(t[1]) end,
                    set = function(on)
                        if on and not JQ.IsEnabled(KEY) then JQ.SetEnabled(KEY, true) end
                        JQ.SetEnabled(t[1], on)
                    end,
                })
            end
        end
    end,
    onEnable = function()
        QueueScan()
        Refresh()
    end,
    onDisable = function()
        ClearTargets(true)
        HideButtons()
        Refresh()
    end,
})

JQ.AddModule({
    key = KEY_ZONE,
    label = "Show this zone's places on the map",
    description = "Outlines and fills in pink, on the world map (OpenMap's or the game's own), every place still to explore in the zone the map shows and the zone you're in. Needs Explore challenge waypoints.",
    default = false,
    onEnable = function() Refresh() end,
    onDisable = function() Refresh() end,
})

JQ.AddModule({
    key = KEY_ALL,
    label = "Show every zone's places on the map",
    description = "The same for every zone at once: every place still to explore in Eastern Kingdoms and Kalimdor, in pink on the world map. Needs Explore challenge waypoints.",
    default = false,
    onEnable = function() Refresh() end,
    onDisable = function() Refresh() end,
})
