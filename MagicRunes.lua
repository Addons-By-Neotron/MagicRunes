--[[
**********************************************************************
MagicRunes - Death Knight rune cooldown displaye
**********************************************************************
This file is part of MagicBars, a World of Warcraft Addon

MagicBars is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MagicBars is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MagicBars.  If not, see <http://www.gnu.org/licenses/>.

**********************************************************************
]]

if not LibStub:GetLibrary("LibBars-1.0", true) then
   LoadAddOn("LibBars-1.0") -- hrm..
end

MagicRunes = LibStub("AceAddon-3.0"):NewAddon("MagicBars", "AceEvent-3.0", "LibBars-1.0", 
					      "AceTimer-3.0", "AceConsole-3.0")
local R = LibStub("AceConfigRegistry-3.0")

-- Silently fail embedding if it doesn't exist
local LibStub = LibStub
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local Logger = LibStub("LibLogger-1.0", true)

local C = LibStub("AceConfigDialog-3.0")
local DBOpt = LibStub("AceDBOptions-3.0")
local media = LibStub("LibSharedMedia-3.0")
local mod = MagicRunes
local currentbars

local InCombatLockdown = InCombatLockdown
local fmt = string.format
local time = GetTime
local max = max
local GetRuneCooldown = GetRuneCooldown
local GetRuneType = GetRuneType
local type = type
local pairs = pairs
local min = min
local tostring = tostring
local next = next
local sort = sort
local select = select
local unpack = unpack
local vertical 
local gcd = 1.5
local flashTimer
local playerInCombat = InCombatLockdown()

if Logger then
   Logger:Embed(MagicRunes)
else
   -- Enable info messages
   mod.info = function(self, ...) mod:Print(fmt(...)) end
   mod.error = info
   mod.warn = info
   -- But disable debugging
   mod.debug = function(self, ...) end
   mod.trace = mod.debug
   mod.spam = mod.debug
end

local addonEnabled = false
local db, isInGroup
local bars 

runebars = {}

if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then
   local runecache = { }
   local GRC = GetRuneCooldown
   function GetRuneCooldown(id)
      if runecache[id] then
	 return unpack(runecache[id])
      else
	 return GRC(id)
      end
   end

   function mod:TriggerRune(id, ready, timeout)
      id = id or random(6)
      if not ready then
	 runecache[id] = {
	    GetTime()-(timeout or 0), 10, false
	 }
      else
	 runecache[id] = nil
      end
      mod:RUNE_POWER_UPDATE(_, id, ready)
   end
end


local options

local runeInfo = {
   { "Blood",  "B", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood"}, 
   { "Unholy", "U", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy"};
   { "Frost",  "F", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost"},
   { "Death",  "D", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death" },
}

local comboIcons = {
   runeInfo[1][3], -- BLOOD
   runeInfo[2][3], -- UNHOLY
   runeInfo[3][3], -- FROST
   runeInfo[2][3], -- FU  (unholy)
   runeInfo[4][3], -- FUB (death)
}

local colors = {
   Blood  = { [1] = 1,   [2] = 0,   [3] = 0,   [4] = 1 },
   Unholy = { [1] = 0,   [2] = 0.7, [3] = 0,   [4] = 1 },
   Frost  = { [1] = 0,   [2] = 0.5, [3] = 1,   [4] = 1 },
   Death  = { [1] = 0.8, [2] = 0,   [3] = 0.9, [4] = 1 },
}

local defaults = {
   profile = {
      displayType = mod.RUNE_DISPLAY,
      flashMode = 2,
      flashTimes = 2,
      sound = "None",
      font = "Friz Quadrata TT",
      fontsize = 14,
      hideAnchor = true,
      iconScale = 1.0,
      length = 250,
      orientation = 1,
      scale = 1.0,
      showIcon = true,
      showLabel = true,
      showTimer = true,
      showTooltip = true,
      alphaOOC = 1.0,
      alphaReady = 1.0,
      alphaGCD = 1.0,
      alphaActive = 0.5,
      fadeAlpha = true,
      sortMethod = 1,
      spacing = 1,
      texture =  "Minimalist",
      thickness = 25,
   }
}

local function GetRuneInfo(runeid)
   local type = GetRuneType(runeid)
   local info = runeInfo[type]
   if vertical then 
      return info[2], info[3], type, db.colors[info[1]]
   else
      return info[1], info[3], type, db.colors[info[1]]
   end
end

local function RefreshBarColors()
   for id,bar in ipairs(runebars) do
      local bdb = db.bars[id]
      if bdb.type == mod.RUNE_BAR then
	 local name, _, _, color = GetRuneInfo(bdb.runeid)
	 mod:SetBarColor(bar, color)
      end
   end
end

local function SetColorOpt(arg, r, g, b, a)
   local color = arg[#arg]
   db.colors[color][1] = r
   db.colors[color][2] = g
   db.colors[color][3] = b
   db.colors[color][4] = a
   RefreshBarColors()
end

local function GetColorOpt(arg)
   return unpack(db.colors[arg[#arg]])
end

function mod:SetBarColorOpt(arg, r, g, b, a)
   local barId = tonumber(arg[#arg-1])
   local color = db.bars[barId].color or {}
   color[1] = r
   color[2] = g
   color[3] = b
   color[4] = a
   db.bars[barId].color = color
   mod:SetBarColor(runebars[barId], color)
end

function mod:GetBarColorOpt(arg)
   local barId = tonumber(arg[#arg-1])
   local color = db.bars[barId].color
   if color then
      return unpack(color)
   end
end

function mod:SetDefaultColors()
   -- Populate default colors
   if not db.colors then
      db.colors = colors
   else
      for color, val in pairs(colors) do
	 if not db.colors[color] then
	    db.colors[color] = val
	 end
      end
   end
end

function mod:OnInitialize()
   self.db = LibStub("AceDB-3.0"):New("MagicRunesDB", defaults, "Default")
   self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
   MagicRunesDB.point = nil
   db = self.db.profile

   -- bar types
   mod.RUNIC_BAR = 1
   mod.RUNE_BAR  = 2

   -- upgrade
   if db.width then
      db.thickness = db.height
      db.length = db.width
      db.width = nil
      db.height = nil
   end

   -- initial rune status
   for id = 1,6 do mod:UpdateRuneStatus(id) end
   
   mod:SetDefaultColors()
   
   if LDB then
      self.ldb =
	 LDB:NewDataObject("Magic Runes",
			   {
			      type =  "launcher", 
			      label = "Magic Runes",
			      icon = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
			      tooltiptext = ("|cffffff00Left click|r to open the configuration screen.\n"..
					     (mod.TriggerRune and "|cffffff00Middle click|r to emulate rune use.\n" or "")..
					     "|cffffff00Right click|r to toggle the Magic Target window lock."), 
			      OnClick = function(clickedframe, button)
					   if button == "LeftButton" then
					      mod:ToggleConfigDialog()
					   elseif button == "MiddleButton" and
					      mod.TriggerRune then
					      mod:TriggerRune(6)
					      mod:TriggerRune(4)
					      mod:TriggerRune(2, false, 1.5)
					      mod:TriggerRune(1, false, 3.0)
					      mod:TriggerRune(3, false, 4.5)
					      mod:TriggerRune(5, false, 6.0)
					   elseif button == "RightButton" then
					      mod:ToggleLocked()
					   end
					end,
			   })
   end
   
   
   
   options.profile = DBOpt:GetOptionsTable(self.db)

   mod:SetupOptions()
end

local sortFunctions = {
   
   function(a, b) -- BarId
      if db.reverseSort then
	 return a.barId > b.barId
      else
	 return a.barId < b.barId
      end
   end,
   function(a, b) --  Rune, Time
      local sortval
      local arune = a.type or 0
      local brune = b.type or 0
      if arune == brune then
	 sortval = a.value < b.value
      else
	 sortval = arune < brune 
      end
      if db.reverseSort then return not sortval else return sortval end
   end, 

   function(a, b) --  Rune, Reverse Time
      local sortval
      local arune = a.type or 0
      local brune = b.type or 0
      if arune == brune then
	 sortval = a.value > b.value
      else
	 sortval = arune < brune 
      end
      if db.reverseSort then return not sortval else return sortval end
   end, 
   
   function(a, b) -- Time, Rune
      local sortval
      if a.value == b.value then
	 sortval = (a.type or 0) < (b.type or 0)
      else
	 sortval = a.value < b.value
      end
      if db.reverseSort then return not sortval else return sortval end
   end, 
   function(a, b) -- Reverse Time, Rune
      local sortval
      if a.value == b.value then
	 sortval = (a.type or 0) < (b.type or 0)
      else
	 sortval = a.value > b.value
      end
      if db.reverseSort then return not sortval else return sortval end
   end, 
}

function mod:OnEnable()
   if not bars then
      bars = mod:NewBarGroup("Runes",nil,  db.length, db.thickness)
      bars:SetColorAt(1.00, 1, 1, 0, 1)
      bars:SetColorAt(0.00, 0.5, 0.5,0, 1)
      bars.RegisterCallback(self, "AnchorMoved")
   end

   mod:ApplyProfile()
   if self.SetLogLevel then
      mod:SetLogLevel(self.logLevels.TRACE)
   end
   mod:RegisterEvent("RUNE_POWER_UPDATE")
   mod:RegisterEvent("RUNE_TYPE_UPDATE")
   mod:RegisterEvent("PLAYER_REGEN_ENABLED")
   mod:RegisterEvent("PLAYER_REGEN_DISABLED")
end

-- We mess around with bars so restore them to a prestine state
-- Yes, this is evil and all but... so much fun... muahahaha
function mod:ReleaseBar(bar)
   bar.barId = nil
   bar.type  = nil
   bar.notReady = nil
   bar.iconPath = nil
   bar.gcdnotify = false
   bar:SetScript("OnEnter", nil)
   bar:SetScript("OnLeave", nil)
   bar:EnableMouse(false)
   bar:SetValue(0)
   bar:SetScale(1)
   bar.spark:SetAlpha(1)
   bars:RemoveBar(bar.name)
end

function mod:CreateBars()
   for id,bar in ipairs(runebars) do
      mod:ReleaseBar(bar)
      runebars[id] = nil
   end
   
   if not db.bars then return end
   
   for id,data in ipairs(db.bars) do
      local bar = bars:NewCounterBar("MagicRunes:"..id, "", db.showRemaining and 0 or 10, 10)
--      bar:SetScript("OnEnter", Bar_OnEnter);
--      bar:SetScript("OnLeave", Bar_OnLeave);
      bar:EnableMouse(true)
      bar.barId  = id
      bar:SetFrameLevel(id)
      runebars[id] = bar
      
      if data.type == mod.RUNE_BAR then
	 local name, icon, type, color = GetRuneInfo(data.runeid)
	 bar.type = type
	 bar:SetIcon(icon) 
	 bar:SetLabel(name) 
	 if not db.showIcon then bar:HideIcon() end
	 mod:SetBarColor(bar, color)
      end
      if not db.showLabel then bar:HideLabel() end
      if not db.showTimer then bar:HideTimerLabel() end
   end
end

function mod:SetIconScale(val)
   for _,bar in ipairs(runebars) do
      bar.icon:SetWidth(db.thickness * val)
      bar.icon:SetHeight(db.thickness * val)
   end
end
function mod:SetTexture()
   bars:SetTexture(media:Fetch("statusbar", db.texture))
end

function mod:SetFont()
   bars:SetFont(media:Fetch("font", db.font), db.fontsize)
end

function mod:UpdateIcons()
   for id, data in ipairs(db.bars) do
      local bar = runebars[id]
      if db.showIcon and db.animateIcons then
	 bar.spark:SetAlpha(0)
      else
	 bar.spark:SetAlpha(1)
      end

      if db.showIcon then
	 bar:ShowIcon()
      else
	 bar:HideIcon()
      end
   end
end

function mod:UpdateLabels()
   for id, data in ipairs(db.bars) do
      local bar = runebars[id]
      if db.showLabel then bar:ShowLabel() else bar:HideLabel() end
      if db.showTimer then bar:ShowTimerLabel() else bar:HideTimerLabel() end
   end
end

function mod:OnDisable()
   mod:UnregisterEvent("RUNE_POWER_UPDATE")
   mod:UnregisterEvent("RUNE_TYPE_UPDATE")
   mod:UnregisterEvent("PLAYER_REGEN_ENABLED")
   mod:UnregisterEvent("PLAYER_REGEN_DISABLED")
end

local function Bar_UpdateTooltip(self, tooltip)
-- 
--    tooltip:ClearLines()
--    local tti = tooltipInfo[self.name]
--    if tti and tti.name then
--       tooltip:AddLine(tti.name, 0.85, 0.85, 0.1)
--       tooltip:AddLine(fmt(lvlFmt, tti.level, tti.type), 1, 1, 1)
--       tooltip:AddLine(" ")
--       tooltip:AddDoubleLine("Health:", fmt("%.0f%%", 100*self.value/self.maxValue), nil, nil, nil, 1, 1, 1)
--       if tti.target then
-- 	 tooltip:AddDoubleLine("Target:", db.coloredNames and coloredNames[tti.target] or tti.target, nil, nil, nil, 1, 1, 1)
--       end
--       if self.color and colorToText[self.color] and InCombatLockdown() then
-- 	 local c = db.colors[self.color]
-- 	 tooltip:AddDoubleLine("Status:", colorToText[self.color], nil, nil, nil, c[1], c[2], c[3])
--       else
-- 	 local c = db.colors.Normal
-- 	 tooltip:AddDoubleLine("Status:", "Idle", nil, nil, nil, c[1], c[2], c[3])
--       end
--       if mmtargets[self.name] then
-- 	 tooltip:AddDoubleLine("MagicMarker Assigment:", mmtargets[self.name].cc, nil, nil, nil, 1, 1, 1)
--       end
--       tooltip:AddLine(" ")
--       if next(tti.targets) then 
-- 	 tooltip:AddLine("Currently targeted by:", 0.85, 0.85, 0.1);
-- 	 local sorted = mod.get()
-- 	 for id in pairs(tti.targets) do
-- 	    sorted[#sorted+1] = id
-- 	 end
-- 	 sort(sorted)
-- 	 if db.coloredNames then
-- 	    for id,name in ipairs(sorted) do
-- 	       sorted[id] = coloredNames[name]
-- 	    end
-- 	 end
-- 	 tooltip:AddLine(tconcat(sorted, ", "), 1, 1, 1, 1)
-- 	 mod.del(sorted)
--       else
-- 	 tooltip:AddLine("Not targeted by anyone.");
--       end
--    else
--       tooltip:AddLine(self.label:GetText(), 0.85, 0.85, 0.1)
--       tooltip:AddLine(" ")
--       tooltip:AddLine("Not targeted by anyone.");
--    end
--    tooltip:Show()
end

local function Bar_OnEnter()
   if not db.showTooltip  then return end
   local tooltip = GameTooltip
   local self = this
   tooltip:SetOwner(self, "ANCHOR_CURSOR")
   Bar_UpdateTooltip(self, tooltip)
   this.tooltipShowing = true
end

local function Bar_OnLeave()
   if not db.showTooltip  then return end
   GameTooltip:Hide()
   this.tooltipShowing = nil
end

do
   local numActiveRunes = 0
   local activeRunes = {}
   
   local runeData = { {}, {}, {}, {}, {}, {} }
   local now, updated, data, bar, playAlert, tmp

   function mod:UpdateRemainingTimes()
      if db.flashTimes and db.flashMode == 2 then
	 RefreshBarColors()
      end
      for id,barData in ipairs(db.bars) do
	 bar = runebars[id]
	 if barData.type == mod.RUNE_BAR then
	    data = runeData[barData.runeid]
	    if data.remaining <= 0 then
	       if db.showRemaining then
		  bar:SetValue(0)
	       else
		  bar:SetValue(bar.maxValue)
	       end
	    else
	       if db.showRemaining then
		  bar:SetValue(data.remaining)
	       else
		  bar:SetValue(data.value)
	       end
	    end
	 end
      end
   end

   function mod.UpdateBars()
      now = GetTime()
      playAlert = nil
      for id = 1,6 do
	 data = runeData[id]
	 data.remaining = max(data.start + data.duration - now, 0)
	 data.value = data.duration - data.remaining
      end
      -- Check each bar for update
      for id,barData in ipairs(db.bars) do
	 bar = runebars[id]
	 if barData.type == mod.RUNE_BAR then
	    data = runeData[barData.runeid]
	    -- Handle death runes changes
	    if bar.type ~= data.type then
	       local name, icon, type, color = GetRuneInfo(barData.runeid)
	       bar.type = data.type
	       bar:SetLabel(name) 
	       bar:SetIcon(icon) 
	       mod:SetBarColor(bar, color)
	    end

	    if data.ready or data.remaining <= 0 then
	       -- DEBUG FOR NON-DK CLASSES
	       if mod.TriggerRune and not data.ready then 
		  mod:TriggerRune(barData.runeid, true)
	       end
	       if bar.notReady or numActiveRunes == 0 then
		  bar:SetAlpha(playerInCombat and db.alphaReady or db.alphaOOC)
		  if db.showRemaining then
		     bar:SetValue(0)
		  else
		     bar:SetValue(bar.maxValue)
		  end
		  bar.timerLabel:SetText("")
		  bar.notReady = nil
		  if bar.flashing then bar:StopFlash() end
		  bar.gcdnotify = nil
	       end
	    else
	       newValue = db.showRemaining and data.remaining or data.value
	       if bar.value ~= newValue then
		  if data.remaining < gcd then
		     if not bar.gcdnotify then 
			if flashTimer and not bar.flashing then
			   bar:SetAlpha(1.0)
			   bar:Flash(data.remaining/flashTimer)
			else
			   bar:SetAlpha(db.alphaGCD)
			end
			bar.gcdnotify = true
			playAlert = true
		     end
		  else
		     if db.fadeAlpha then
			tmp = (data.remaining-gcd)/(10-gcd)
			bar:SetAlpha(db.alphaActive*tmp + db.alphaGCD*(1-tmp))
		     else
			bar:SetAlpha(db.alphaActive)
		     end
		  end
		  bar:SetValue(newValue)
		  if db.showTimer then
		     if data.remaining == 0 then
			bar.timerLabel:SetText("")
		     elseif data.remaining > 2.0 or vertical then
			bar.timerLabel:SetText(fmt("%.0f", data.remaining))
		     else
			bar.timerLabel:SetText(fmt("%.1f", data.remaining))
		     end
		  end
	       end
	       bar.notReady = true
	    end
	 end
      end
      if db.sortMethod > 1 then 
	 bars:SortBars()	
      end
      if playAlert and mod.soundFile then
	 PlaySoundFile(mod.soundFile)
      end
   end
   
   function mod:UpdateRuneStatus(id)
      local data = runeData[id]
      data.start, data.duration, data.ready = GetRuneCooldown(id)
      if not data.type then
	 data.type = GetRuneType(id)
      end
   end
   
   function mod:RUNE_POWER_UPDATE(_, rune, usable)
      if rune >= 7 then return end

      mod:UpdateRuneStatus(rune)
      if usable then
	 if activeRunes[rune] then
	    activeRunes[rune] = nil
	    numActiveRunes = numActiveRunes - 1
	 end
	 if numActiveRunes == 0 then
	    bars:SetScript("OnUpdate", nil)
	    mod.UpdateBars()
	 end
      else
	 if not activeRunes[rune] then
	    numActiveRunes = numActiveRunes + 1
	    activeRunes[rune] = true
	 end
	 if numActiveRunes == 1 then
	    bars:SetScript("OnUpdate", mod.UpdateBars)
	 end
      end
   end
   
   function mod:RUNE_TYPE_UPDATE(_, rune)
      runeData[rune].type = GetRuneType(rune)
      mod:UpdateBars()
   end   
end

function mod:AnchorMoved(cbk, group, button)
   db.point = { group:GetPoint() }
end

function mod:SetBarColor(bar, color)
   if not color then return end
   local rf = 0.5+color[1]/2
   local gf = 0.5+color[2]/2
   local bf = 0.5+color[3]/2
   bar:UnsetAllColors()

   if db.flashTimes and db.flashMode == 2 then
      local offset = gcd/10
      local interval = offset/(db.flashTimes*2)
      local endVal
      if db.showRemaining then
	 endVal = interval
	 interval = -interval
      else
	 endVal = 1-interval
	 offset = 1-offset
      end
      for val = offset,endVal,(interval*2) do
	 bar:SetColorAt(val, color[1], color[2], color[3], color[4])
	 if val ~= endVal then bar:SetColorAt(val+interval, rf, gf, bf, 1) end
      end
   end
   bar:SetColorAt(0, color[1], color[2], color[3], color[4])
   bar:SetColorAt(1, color[1], color[2], color[3], color[4])
end

function mod:PLAYER_REGEN_ENABLED()
   playerInCombat = false
   mod.UpdateBars()
end


function mod:PLAYER_REGEN_DISABLED()
   playerInCombat = true
   mod.UpdateBars()
end

-- Config option handling below

local function GetMediaList(type)
   local arrlist = media:List(type)
   local keylist = {}
   for _,val in pairs(arrlist) do
      keylist[val] = val
   end
   return keylist
end

-- Set up the default rune 1 to 6 bars
function mod:SetDefaultBars()
   if db.bars then return end -- already set up
   local bars = {}
   for id = 1,6 do
      bars[#bars+1] = {
	 type = 2,
	 runeid = id,
      }
   end
   db.bars = bars
end


function mod:SetFlashTimer(_, val)
   if val then db.flashTimes = val end
   
   if db.flashTimes and db.flashTimes > 0 and db.flashMode == 3 then
      flashTimer = db.flashTimes * 2 * math.pi
   else
      flashTimer = nil
   end
   RefreshBarColors()
end

function mod:SetSoundFile(_,val)
   if val then
      db.sound = val
   end
   mod.soundFile = media:Fetch("sound", db.sound)
end

local varChanges = {
   showlabel = "showLabel",
   showtimer = "showTimer",
   sortmethod = "sortMethod",
   hideanchor = "hideAnchor",
   iconscale = "iconScale"
}

function mod:ApplyProfile()
   -- configure based on saved data
   for from,to in pairs(varChanges) do
      if db[from] then
	 db[to] = db[from]
	 db[from] = nil
      end
   end
   bars:ClearAllPoints()
   if db.point then
      bars:SetPoint(unpack(db.point))
   else
      bars:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -300)
   end
   bars:ReverseGrowth(db.growup)
   if db.locked then bars:Lock() else bars:Unlock() end
   if db.hideAnchor and db.locked then bars:HideAnchor() else bars:ShowAnchor() end
   mod:SetSoundFile()
   bars:SetSortFunction(bars.NOOP)
   mod:SetDefaultColors()
   mod:SetDefaultBars()
   mod:CreateBars()
   mod:SetFlashTimer()
   mod:SetTexture()
   mod:SetFont()
   mod:SetSize()
   mod:SetOrientation(db.orientation)
--   mod:SetupBarOptions(true)
   bars:SetSortFunction(sortFunctions[db.sortMethod])
   bars:SetScale(db.scale)
   bars:SetSpacing(db.spacing)
   mod.UpdateBars()
   bars:SortBars()
end

function mod:SetBarLabel(id, data)
   if data.type == mod.RUNE_BAR then
      runebars[id]:SetLabel(GetRuneInfo(data.runeid))
   else
      if vertical then 
	 runebars[id]:SetLabel(data.shorttitle)
      else
	 runebars[id]:SetLabel(data.title)
      end
   end
end

function mod:SetOrientation(orientation)
   bars:SetOrientation(orientation)
   vertical = (orientation == 2 or orientation == 4)
   for id,data in ipairs(db.bars) do
      local bar = runebars[id]
      if db.showIcon and db.animateIcons then
	 bar.icon:ClearAllPoints()
	 bar.icon:SetPoint("CENTER", bar.spark)
	 bar.spark:SetAlpha(0)
      else
	 bar.spark:SetAlpha(1)
      end
      mod:SetBarLabel(id, data)
   end
   mod:SetIconScale(db.iconScale)
end

function mod:SetSize()
   bars:SetThickness(db.thickness)
   bars:SetLength(db.length)
   bars:SortBars()
   mod:SetIconScale(db.iconScale)
end

function mod:OnProfileChanged(event, newdb)
   db = self.db.profile
   mod:ApplyProfile()
end

function mod:ToggleConfigDialog()
   InterfaceOptionsFrame_OpenToCategory(mod.text)
   InterfaceOptionsFrame_OpenToCategory(mod.main)
end

function mod:ToggleLocked()
   db.locked = not db.locked
   if db.locked then bars:Lock() else bars:Unlock() end
   if db.hideAnchor then
      -- Show anchor if we're unlocked but lock it again if we're locked
      if db.locked then bars:HideAnchor() else bars:ShowAnchor() end
   end
   bars:SortBars()
   mod:info("The bars are now %s.", db.locked and "locked" or "unlocked")
end

function mod:GetGlobalOption(info)
   return db[info[#info]]
end

function mod:SetGlobalOption(info, val)
   local var = info[#info]
   db[info[#info]] = val
   mod.UpdateBars()
end

options = { 
   general = {
      type = "group",
      name = "General",
      get = "GetGlobalOption",
      handler = mod,
      order = 1,
      args = {
--	 showTooltip = {
--	    type = "toggle",
--	    width = "full",
--	    name = "Show mouseover tooltip", 
--	    get = function() return db.showTooltip end,
--	 },
	 showRemaining = {
	    type = "toggle",
	    name = "Show remaining time",
	    desc = "Instead showing the time elapsed on the cooldown, show the time remaining. This means that the bars will shrink as the cooldown lowers instead of grow.",
	    width = "full",
	    set = function(_,val) db.showRemaining = val mod:UpdateRemainingTimes() end
	 },
	 locked = {
	    type = "toggle",
	    name = "Lock bar positions",
	    width = "full",
	    set = function() mod:ToggleLocked() end,
	 },
--	 growup = {
--	    type = "toggle",
--	    name = "Reverse growth direction",
--	    width = "full",
--	    set = function()
--		     db.growup = not db.growup
--		     bars:ReverseGrowth(db.growup)
--		  end,
--	 },
	 hideAnchor = {
	    type = "toggle",
	    name = "Hide anchor when bars are locked.",
	    width = "full",	
	    set = function()
		     db.hideAnchor = not db.hideAnchor
		     if db.locked and db.hideAnchor then
			bars:HideAnchor()
		     else
			bars:ShowAnchor()
		     end
		     mod:info("The anchor will be %s when the bars are locked.", db.hideAnchor and "hidden" or "shown") 
		  end,
	 },
	 sound = {
	    type = 'select',
	    dialogControl = 'LSM30_Sound',
	    name = 'Alert Sound',
	    desc = 'Sound to play when a rune is one global cooldown away from being ready.',
	    values = AceGUIWidgetLSMlists.sound,
	    set = "SetSoundFile",
	 },
	 preset = {
	    type = "select", 
	    name = "Load Preset",
	    desc = "Presets are primarily here to give you a few ideas on how you can configure the bars. Note that the presets do now change font, texture or color options. The global scale is also not changed.",
	    values = "GetPresetList",
	    width  = "full",
	    order = 0,
	    set = function(_, preset)
		     if db.preset ~= preset then
			db.preset = preset
			for var,val in pairs(mod.presets[preset].data) do
			   mod:debug("Setting %s to %s", var, tostring(val))
			   db[var] = val
			end
			mod:ApplyProfile()
			mod:NotifyChange()
		     end
		  end
	 }
      },
   },
   colors = {
      type = "group",
      name = "Colors",
      order = 9,
      handler = mod,
      set = SetColorOpt,
      get = GetColorOpt,
      args = {
	 Blood = {
	    type = "color",
	    name = "Blood",
	    desc = "Color used for blood rune bars.",
	    hasAlpha = true, 
	 },
	 Unholy = {
	    type = "color",
	    name = "Unholy",
	    desc = "Color used for unholy rune bars.",
	    hasAlpha = true, 
	 },
	 Frost = {
	    type = "color",
	    name = "Frost",
	    desc = "Color used for frost rune bars.",
	    hasAlpha = true, 
	 },
	 Death = {
	    type = "color",
	    name = "Death",
	    desc = "Color used for death rune bars.",
	    hasAlpha = true, 
	 },
      },
   },
   deco = {
      type = "group",
      name = "Decoration and Effects",
      handler = mod,
      get = "GetGlobalOption",
      args = {
	 showLabel = {
	    type = "toggle",
	    name = "Show labels",
	    set = function(_,val) db.showLabel = val mod:UpdateLabels() end,
	    order = 10,
	    
	 },
	 showTimer = {
	    type = "toggle",
	    name = "Show timer",
	    set = function(_,val) db.showTimer = val mod:UpdateLabels() end,
	    order = 20,
	 },
	 showIcon = {
	    type = "toggle",
	    name = "Show icons",
	    set = function(_,val) db.showIcon = val mod:UpdateIcons() end,
	    order = 30
	 },
	 animateIcons = {
	    type = "toggle",
	    name = "Animate Icons",
	    desc = "If enabled, the icons will move with the bar. If the bar texture is hidden, you'll get a display simply showing the cooldown using icons.",
	    set = function(_, val) db.animateIcons = val mod:SetOrientation(db.orientation) end,
	    order = 35,
	    disabled = function() return not db.showIcon end
	 },
	 flashMode = {
	    type = "select",
	    name = "Flash Mode",
	    desc = "Type of flashing to use to indicate imminent readiness.",
	    values = {
	       "None",
	       "Color Flash",
	       "Alpha Flash"
	    },
	    set = function(_,val) db.flashMode = val mod:SetFlashTimer() end,
	    order = 40,
	 },
	 flashTimes = {
	    type = "range",
	    name = "Number of Flashes",
	    desc = "Number of times to flash bars when the remaining is less than the GCD. Set to zero to disable flashing.",
	    min = 1, max = 10, step = 1,
	    set = "SetFlashTimer",
	    hidden = function() return db.flashMode == 1 end,
	    order = 50,	    
	 },
      },
   },
   alpha = {
      type = "group",
      name = "Alpha Settings",
      handler = mod,
      get = "GetGlobalOption",
      args = {
	 alphaOOC = {
	    type = "range",
	    name = "Out of combat alpha",
	    desc = "Alpha level for ready runes when out of combat.",
	    width = "full",
	    min = 0, max = 1, step = 0.01,
	    set = "SetGlobalOption",
	    order = 100,
	 },
	 alphaReady = {
	    type = "range",
	    name = "In-Combat ready rune alpha",
	    desc = "Alpha level of ready runes when in combat.",
	    width = "full",
	    min = 0, max = 1, step = 0.01,
	    set = "SetGlobalOption",
	    order = 110,
	 },
	 alphaGCD = {
	    type = "range",
	    name = "In-GCD active rune alpha",
	    desc = "Alpha level of active runes when the remaining cooldown is shorter the global cooldown.",
	    width = "full",
	    min = 0, max = 1, step = 0.01,
	    set = "SetGlobalOption",
	    order = 120,
	 },
	 alphaActive = {
	    type = "range",
	    name = "Out-of-GCD active rune alpha",
	    desc = "Alpha level of active runes when the remaining cooldown is longer than the global cooldown.",
	    width = "full",
	    min = 0, max = 1, step = 0.01,
	    set = "SetGlobalOption",
	    order = 130,
	 },
	 fadeAlpha = {
	    type = "toggle",
	    name = "Fade alpha level of active runes",
	    desc = "Fade alpha level between the in GCD and out of GCD alpha level. This can be used to make the rune cooldown displays become incrementally more visible as the cooldown decreases.", 
	    width = "full",
	    set = "SetGlobalOption",
	    order = 140,
	 }
      }
   },
   sizing = {
      type = "group",
      name = "Bar Layout",
      order = 4,
      handler = mod,
      get = "GetGlobalOption",
      args = {
	 length = {
	    type = "range",
	    name = "Length",
	    width = "full",
	    min = 100, max = 500, step = 0.01,
	    set = function(_,val) db.length = val mod:SetSize() end,
	    order = 1
	 }, 
	 thickness = {
	    type = "range",
	    name = "Thickness",
	    width = "full",
	    min = 1, max = 150, step = 0.01,
	    set = function(_,val) db.thickness = val mod:SetSize() end,
	    order = 2
	 }, 
	 spacing = {
	    type = "range",
	    name = "Spacing",
	    width = "full",
	    min = -30, max = 30, step = 0.01,
	    set = function(_,val) db.spacing = val bars:SetSpacing(val) end,
	    order = 3
	 }, 
	 scale = {
	    type = "range",
	    name = "Overall Scale",
	    width = "full",
	    min = 0.01, max = 5, step = 0.01,
	    set = function(_,val) db.scale = val bars:SetScale(val) end,
	    order = 4
	 },
	 iconScale = {
	    type = "range",
	    name = "Icon Scale",
	    width = "full",
	    min = 0.01, max = 50, step = 0.01,
	    set = function(_,val) db.iconScale = val mod:SetIconScale(val) end,
	    order = 4
	 },
	 orientation = {
	    type = "select",
	    name = "Orientation",
	    values = {
	       "Horizontal, Left",
	       "Vertical, Bottom",
	       "Horizontal, Right",
	       "Vertical, Top"
	    },
	    set = function(_,val) db.orientation = val mod:SetOrientation(val) end,
	    order = 5,
	 },
	 sortMethod = {
	    type = "select",
	    name = "Sort Method",
	    set = function(_,val) db.sortMethod = val bars:SetSortFunction(sortFunctions[val]) bars:SortBars() end,
	    values = {
	       "Rune Order",
	       "Rune Type, Time",
	       "Rune Type, Reverse Time",
	       "Time, Rune Type",
	       "Reverse Time, Rune Type",
	    },
	    order = 50
	 },
	 reverseSort = {
	    type = "toggle",
	    name = "Reverse Sorting",
	    set = function(_,val) db.reverseSort = val bars:SortBars() end,
	    order = 60
	 },
      },
   },
   looks = {
      type = "group",
      name = "Font and Texture",
      order = 3,
      handler = mod,
      get = "GetGlobalOption",
      args = {
	 texture = {
	    type = 'select',
	    dialogControl = 'LSM30_Statusbar',
	    name = 'Texture',
	    desc = 'The background texture used for the bars.',
	    values = AceGUIWidgetLSMlists.statusbar, 
	    set = function(_,val) db.texture = val mod:SetTexture() end,
	    order = 3
	 },
	 font = {
	    type = 'select',
	    dialogControl = 'LSM30_Font',
	    name = 'Font',
	    desc = 'Font used on the bars',
	    values = AceGUIWidgetLSMlists.font, 
	    set = function(_,key) db.font = key  mod:SetFont() end,
	    order = 2,
	 },
	 fontsize = {
	    order = 1, 
	    type = "range",
	    width="full",
	    name = "Font size",
	    min = 1, max = 30, step = 0.01,
	    set = function(_,val) db.fontsize = val mod:SetFont() end,
	    order = 1
	 },
      },
   },
   runebar = {
      type = "group",
      name = "Bar #",
      args = {
	 type = {
	    type = "select",
	    name = "Type",
	    values = { "Runic Bar", "Rune Bar" },
	    order = 10,
	 },
	 runeid = {
	    type = "select",
	    name = "Rune #",
	    values = {
	       "Blood #1", "Blood #2",
	       "Unholy #1", "Unholy #2",
	       "Frost #1", "Frost #2",
	    },
	    hidden = "NotBarTypeRuneBar",
	    order = 20,
	 },
	 title = {
	    type = "input",
	    name = "Label",
	    desc = "Label used on horizontal bars",
	    hidden = "BarTypeRuneBar",
	    order = 25,
	 },
	 shorttitle = {
	    type = "input",
	    name = "Short Label",
	    desc = "Label used for vertical bars",
	    hidden = "BarTypeRuneBar",
	    order = 28,
	 },
	 color = {
	    type = "color",
	    name = "Color",
	    desc = "Bar color",
	    hasAlpha = true,
	    set = "SetBarColorOpt",
	    get = "GetBarColorOpt",
	    hidden = "BarTypeRuneBar", 
	    order = 30,
	 },
	 delete = {
	    type = "execute",
	    name = "Delete bar",
	    func = function() end,
	    order = 20000
	 },
      }
   },
   bars = {
      type = "group",
      name = "Bar Configuration",
      handler = mod,
      set = "SetBarOption",
      get = "GetBarOption",
      args = {
	 newbar = {
	    type = "execute",
	    name = "Add a new bar",
	    desc = "Create a new bar.",
	    func = "AddNewBar"
	 }
      }
   }   
}


function mod:AddNewBar()
   db.bars[#db.bars+1] = {
      type = mod.RUNE_BAR,
      runeid = 1,
      runes = 1,
      icon = comboIcons[1]
   }
   mod:CreateBars()
   mod:SetupBarOptions(true)
end

function mod:BarTypeRuneBar(info)
   return db.bars[tonumber(info[#info-1])].type == mod.RUNE_BAR
end

function mod:NotBarTypeComboBar(info)
   return db.bars[tonumber(info[#info-1])].type ~= mod.COMBO_BAR
end

function mod:NotBarTypeRuneBar(info)   
   return db.bars[tonumber(info[#info-1])].type ~= mod.RUNE_BAR
end

function mod:NotBarTypeRunicBar(info)
   return db.bars[tonumber(info[#info-1])].type ~= mod.RUNIC_BAR
end

function mod:GetBarOption(info)
   local var = info[#info]
   local id  = tonumber(info[#info-1])
   return db.bars[id][var]
end

function mod:SetBarOption(info, val)
   local var = info[#info]
   local id  = tonumber(info[#info-1])
   local data = db.bars[id]

   -- If using the default icon, change it when we modify the type
   if var == "runes" and (not data.icon or data.icon == "" or data.icon == comboIcons[data.runes]) then
      data.icon = comboIcons[val]
   end
   data[var] = val
   mod.UpdateBars()
end


do
   local configPanes = {}
   function mod:OptReg(optname, tbl, dispname, cmd)
      local regtable
      if dispname then
	 optname = "Magic Runes"..optname
	 LibStub("AceConfig-3.0"):RegisterOptionsTable(optname, tbl, cmd)
	 if not cmd then
	    regtable = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(optname, dispname, "Magic Runes")
	 end
      else
	 LibStub("AceConfig-3.0"):RegisterOptionsTable(optname, tbl, cmd)
	 if not cmd then
	    regtable = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(optname, "Magic Runes")
	 end
      end
      configPanes[#configPanes+1] = optname
      return regtable
   end
   function mod:NotifyChange()
      for _,name in ipairs(configPanes) do
	 mod:debug("Notifying change for "..name)
	 R:NotifyChange(name)
      end
   end

end

function mod:SetupBarOptions(reload)
   local args = options.bars.args
   for id in pairs(args) do
      if id ~= "newbar" then
	 args[id] = nil
      end
   end
   if db.bars then
      for id in ipairs(db.bars) do
	 local bar = {}
	 for key,val in pairs(options.runebar) do
	    bar[key] = val
	 end
	 bar.name = bar.name .. id
	 args[tostring(id)] = bar
      end
   end
   if reload then 
      R:NotifyChange("Magic Runes: Bar Configuration")
   else
      mod:OptReg(": Bar Configuration", options.bars, "Bar Configuration")
   end
end

function mod:SetupOptions()
   mod.main = mod:OptReg("Magic Runes", options.general)
   mod:OptReg(": Bar Alpha", options.alpha, "Alpha Levels")
   mod:OptReg(": Bar Colors", options.colors, "Colors")
   mod:OptReg(": Bar Decorations", options.deco, "Decorations")
   mod:OptReg(": Bar Layout", options.sizing, "Layout and Sorting")
   mod:OptReg(": Font & Texture", options.looks, "Font & Texture")
   mod.text = mod:OptReg(": Profiles", options.profile, "Profiles")
--   mod:SetupBarOptions()
   

   mod:OptReg("Magic Runes CmdLine", {
		 name = "Command Line",
		 type = "group",
		 args = {
		    config = {
		       type = "execute",
		       name = "Show configuration dialog",
		       func = function() mod:ToggleConfigDialog() end,
		       dialogHidden = true
		    },
		 }
	      }, nil,  { "magrune", "magicrunes" })
end



do
   -- DEV FUNCTION FOR CREATING PRESETS
   local presetParameters = {
      "orientation", "showLabel", "showTimer", "showIcon",
      "spacing", "length", "thickness", "iconScale",
      "animateIcons", "showRemaining"
   }
   
   function mod:SavePreset(name)
      local presets = MagicRunesDB.presets or {}
      presets[name] = {}
      for _,param in ipairs(presetParameters) do
	 presets[name][param] = db[param]
      end
      MagicRunesDB.presets = presets
   end
end
