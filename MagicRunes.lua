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
local tinsert = table.insert
local tconcat = table.concat
local tremove = table.remove
local time = time
local type = type
local pairs = pairs
local min = min
local tostring = tostring
local next = next
local sort = sort
local select = select
local unpack = unpack

if Logger then
   Logger:Embed(MagicRunes)
else
   MagicRunes.info = function(self, ...) self:Print(fmt(...)) end
end


local addonEnabled = false
local db, isInGroup, inCombat
bars  = nil
local runebars = {}
local options
local numFilling = 0

local runeInfo = {
   { "Blood",  "B", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood"}, 
   { "Unholy", "U", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy"};
   { "Frost",  "F", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost"},
   { "Death",  "D", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death" }
}

local colors = {
   Blood  = { [1] = 1,   [2] = 0,   [3] = 0,   [4] = 1 },
   Unholy = { [1] = 0,   [2] = 0.7, [3] = 0,   [4] = 1 },
   Frost  = { [1] = 0,   [2] = 0.5, [3] = 1,   [4] = 1 },
   Death  = { [1] = 0.8, [2] = 0,   [3] = 0.9, [4] = 1 }
}

local defaults = {
   profile = {
      orientation = 1,
      growup = false,
      font = "Friz Quadrata TT",
      locked = false,
      hideanchor = false,
      texture =  "Minimalist",
      maxbars = 20,
      fontsize = 14,
      spacing = 1,
      length = 250,
      thickness = 25,
      fadebars = false,
      showTooltip = true,
      scale = 1.0,
   }
}

local function GetRuneInfo(runeid)
   local type = GetRuneType(runeid)
   local info = runeInfo[type]
   if db.orientation == 1 or db.orientation == 3 then
      return info[1], info[3], type, db.colors[info[1]]
   else
      return info[2], info[3], type, db.colors[info[1]]
   end
end

local function SetColorOpt(arg, r, g, b, a)
   local color = arg[#arg]
   db.colors[color][1] = r
   db.colors[color][2] = g
   db.colors[color][3] = b
   db.colors[color][4] = a

   for id = 1,6 do
      local name, _, _, color = GetRuneInfo(id)
      mod:SetBarColor(runebars[id], color)
   end
end

local function GetColorOpt(arg)
   return unpack(db.colors[arg[#arg]])
end


function mod:OnInitialize()
   self.db = LibStub("AceDB-3.0"):New("MagicRunesDB", defaults, "Default")
   self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileDeleted","OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
   MagicRunesDB.point = nil
   db = self.db.profile

   -- upgrade
   if db.width then
      db.thickness = db.height
      db.length = db.width
      db.width = nil
      db.height = nil
   end
   
   if not db.colors then  db.colors = colors end
   
   if LDB then
      self.ldb =
	 LDB:NewDataObject("Magic Runes",
			   {
			      type =  "launcher", 
			      label = "Magic Runes",
			      icon = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
			      tooltiptext = ("|cffffff00Left click|r to open the configuration screen.\n"..
					     "|cffffff00Right click|r to toggle the Magic Target window lock."), 
			      OnClick = function(clickedframe, button)
					   if button == "LeftButton" then
					      mod:ToggleConfigDialog()
					   elseif button == "RightButton" then
					      mod:ToggleLocked()
					   end
					end,
			   })
   end
   
   
   
   options.profile = DBOpt:GetOptionsTable(self.db)

   mod:SetupOptions()
end


local function BarSortFunc_RuneTime(a, b)
   if a.runeid == b.runeid then
      return a.value < b.value
   else
      return a.runeid < b.runeid
   end
end

local function BarSortFunc_TimeRune(a, b)
   if a.value == b.value then
      return a.runeid < b.runeid
   else
      return a.value < b.value
   end
end

function mod:OnEnable()
   if not bars then
      bars = self:NewBarGroup("Runes",nil,  db.length, db.thickness)
      bars:SetColorAt(1.00, 1, 1, 0, 1)
      bars:SetColorAt(0.00, 0.5, 0.5,0, 1)
      bars.RegisterCallback(self, "AnchorMoved")

      for id = 1, 6 do
	 local name, icon, type, color = GetRuneInfo(id)
	 local bar = bars:NewCounterBar("MagicRunes:"..id, name, 10, 10, icon)
	 bar:SetScript("OnEnter", Bar_OnEnter);
	 bar:SetScript("OnLeave", Bar_OnLeave);
	 bar.runeid = type
	 bar:EnableMouse(true)
	 mod:SetBarColor(bar, color)
	 runebars[id] = bar
      end
      bars:SetSortFunction(BarSortFunc_TimeRune)
   end

   self:ApplyProfile()
   if self.SetLogLevel then
      self:SetLogLevel(self.logLevels.TRACE)
   end
   self:RegisterEvent("RUNE_POWER_UPDATE")
   self:RegisterEvent("RUNE_TYPE_UPDATE")
end

function mod:SetTexture()
   bars:SetTexture(media:Fetch("statusbar", db.texture))
end

function mod:SetFont()
   bars:SetFont(media:Fetch("font", db.font), db.fontsize)
end

function mod:OnDisable()
   self:UnregisterEvent("RUNE_POWER_UPDATE")
   self:UnregisterEvent("RUNE_TYPE_UPDATE")
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
   local timer
   local activeRunes = {}
   local function UpdateBars()
      local now = GetTime()
      local changed = false
      for rune,active in pairs(activeRunes) do
	 if active then	    
	    local start, duration = GetRuneCooldown(rune)
	    local remaining = (start + duration - now)
	    local bar = runebars[rune]
	    if remaining < 0 then
	       remaining = 0
	       bar.value = duration
	       bar.timerLabel:SetText("")
	       activeRunes[rune] = nil
	    else
	       bar.value = duration - remaining
	       if remaining > 2.0 or (db.orientation == 2 or db.orientation == 4) then
		  bar.timerLabel:SetText(fmt("%.0f", remaining))
	       else
		  bar.timerLabel:SetText(fmt("%.1f", remaining))
	       end
	    end
	    bar:SetMaxValue(duration)	    
	    changed = true
	 end
      end
      if changed then
	 bars:SortBars()
      end
   end

   function mod:UpdateRuneBar(rune, usable)
      if usable then
	 -- Done cooling down
	 local bar = runebars[rune]
	 bar.value = 10
	 bar:SetValue(10)
	 bar.timerLabel:SetText("")
	 activeRunes[rune] = nil;
	 numFilling = numFilling - 1
	 if numFilling == 0 then
	    bars:SetScript("OnUpdate", nil)
	 end
      elseif not activeRunes[rune] then
	 activeRunes[rune] = true
	 numFilling = numFilling + 1
	 if numFilling == 1 then
	    bars:SetScript("OnUpdate", UpdateBars)
	 end
      end
   end
end

function mod:AnchorMoved(cbk, group, button)
   db.point = { group:GetPoint() }
end

function mod:SetBarColor(bar, color)
   bar:UnsetAllColors()
   bar:SetColorAt(1.0, color[1], color[2], color[3], color[4])
   if db.fadebars then
      bar:SetColorAt(0, color[1]*0.5, color[2]*0.5, color[3]*0.5, color[4])
   end
end

function mod:RUNE_POWER_UPDATE(_, rune, usable)
   if rune < 7 then
      mod:UpdateRuneBar(rune, usable)
   end
end

function mod:RUNE_TYPE_UPDATE(_, rune)
   local bar = runebars[rune]
   local name, icon, type, color = GetRuneInfo(rune)
   bar:SetLabel(name)
   bar:SetIcon(icon)
   bar.runeid = type
   mod:SetBarColor(runebars[rune], color)
   bars:SortBars()
end

function mod:PLAYER_REGEN_ENABLED()
end


function mod:PLAYER_REGEN_DISABLED()
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

function mod:ApplyProfile()
   -- configure based on saved data
   bars:ClearAllPoints()
   if db.point then
      bars:SetPoint(unpack(db.point))
   else
      bars:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -300)
   end
   bars:ReverseGrowth(db.growup)
   if db.locked then bars:Lock() else bars:Unlock() end
   if db.hideanchor and db.locked then bars:HideAnchor() else bars:ShowAnchor() end
   self:SetTexture()
   self:SetFont()
   self:SetSize()
   self:SetOrientation(db.orientation)
   bars:SetScale(db.scale)
   bars:SetSpacing(db.spacing)
   bars:SortBars()
end

function mod:SetOrientation(orientation)
   bars:SetOrientation(orientation)
   for id = 1,6 do
      runebars[id]:SetLabel(GetRuneInfo(id))
   end
end

function mod:SetSize()
   bars:SetThickness(db.thickness)
   bars:SetLength(db.length)
   bars:SortBars()
end

function mod:OnProfileChanged(event, newdb)
   if event ~= "OnProfileDeleted" then
      db = self.db.profile
      if not db.colors then db.colors = colors end -- set default if needed
      self:ApplyProfile()
   end
end

function mod:ToggleConfigDialog()
   InterfaceOptionsFrame_OpenToCategory(mod.text)
   InterfaceOptionsFrame_OpenToCategory(mod.main)
end

function mod:ToggleLocked()
   db.locked = not db.locked
   if db.locked then bars:Lock() else bars:Unlock() end
   if db.hideanchor then
      -- Show anchor if we're unlocked but lock it again if we're locked
      if db.locked then bars:HideAnchor() else bars:ShowAnchor() end
   end
   bars:SortBars()
   mod:info("The bars are now %s.", db.locked and "locked" or "unlocked")
end

options = { 
   general = {
      type = "group",
      name = "General",
      order = 1,
      args = {
	 ["showTooltip"] = {
	    type = "toggle",
	    width = "full",
	    name = "Show mouseover tooltip", 
	    get = function() return db.showTooltip end,
	    set = function() db.showTooltip = not db.showTooltip end,
	 },
	 ["lock"] = {
	    type = "toggle",
	    name = "Lock bar positions",
	    width = "full",
	    set = function() mod:ToggleLocked() end,
	    get = function() return db.locked end,
	 },
	 ["grow"] = {
	    type = "toggle",
	    name = "Reverse growth direction",
	    width = "full",
	    set = function()
		     db.growup = not db.growup
		     bars:ReverseGrowth(db.growup)
		  end,
	    get = function() return db.growup end
	 },
	 ["hideanchor"] = {
	    type = "toggle",
	    name = "Hide anchor when bars are locked.",
	    width = "full",	
	    set = function()
		     db.hideanchor = not db.hideanchor
		     if db.locked and db.hideanchor then
			bars:HideAnchor()
		     else
			bars:ShowAnchor()
		     end
		     mod:info("The anchor will be %s when the bars are locked.", db.hideanchor and "hidden" or "shown") 
		  end,
	    get = function() return db.hideanchor end
	 },
      },
   },
   colors = {
      type = "group",
      name = "Colors",
      order = 9,
      set = SetColorOpt,
      get = GetColorOpt,
      args = {
	 fadebars = {
	    type = "toggle",
	    name = "Fade bar color as they increase",
	    width = "full",
	    set = function()
		     db.fadebars = not db.fadebars
		     mod:info("Bar fading is %s.", db.fadebars and "enabled" or "disabled") 
		  end,
	    get = function() return db.fadebars end,
	    order = 0
	 },
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
   sizing = {
      type = "group",
      name = "Bar Layout",
      order = 4,
      args = {
	 length = {
	    type = "range",
	    name = "Length",
	    width = "full",
	    min = 100, max = 500, step = 0.01,
	    set = function(_,val) db.length = val mod:SetSize() end,
	    get = function() return db.length end,
	    order = 1
	 }, 
	 thickness = {
	    type = "range",
	    name = "Thickness",
	    width = "full",
	    min = 1, max = 150, step = 0.01,
	    set = function(_,val) db.thickness = val mod:SetSize() end,
	    get = function() return db.thickness end,
	    order = 2
	 }, 
	 spacing = {
	    type = "range",
	    name = "Spacing",
	    width = "full",
	    min = 0, max = 20, step = 0.01,
	    set = function(_,val) db.spacing = val bars:SetSpacing(val) end,
	    get = function() return db.spacing end, 
	    order = 3
	 }, 
	 scale = {
	    type = "range",
	    name = "Scale",
	    width = "full",
	    min = 0.01, max = 5, step = 0.05,
	    set = function(_,val) db.scale = val bars:SetScale(val) end,
	    get = function() return db.scale end,
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
	    get = function() return db.orientation end,
	    order = 5,
	 }
      }
   },
   looks = {
      type = "group",
      name = "Font and Texture",
      order = 3,
      args = {
	 texture = {
	    type = 'select',
	    dialogControl = 'LSM30_Statusbar',
	    name = 'Texture',
	    desc = 'The background texture used for the bars.',
	    values = AceGUIWidgetLSMlists.statusbar, 
	    set = function(_,val) db.texture = val mod:SetTexture() end,
	    get = function() return db.texture end,
	    order = 3
	 },
	 fontname = {
	    type = 'select',
	    dialogControl = 'LSM30_Font',
	    name = 'Font',
	    desc = 'Font used on the bars',
	    values = AceGUIWidgetLSMlists.font, 
	    get = function() return db.font  end,
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
	    get = function() return db.fontsize end,
	    order = 1
	 },
      },
   },
}


function mod:OptReg(optname, tbl, dispname, cmd)
   if dispname then
      optname = "Magic Runes"..optname
      LibStub("AceConfig-3.0"):RegisterOptionsTable(optname, tbl, cmd)
      if not cmd then
	 return LibStub("AceConfigDialog-3.0"):AddToBlizOptions(optname, dispname, "Magic Runes")
      end
   else
      LibStub("AceConfig-3.0"):RegisterOptionsTable(optname, tbl, cmd)
      if not cmd then
	 return LibStub("AceConfigDialog-3.0"):AddToBlizOptions(optname, "Magic Runes")
      end
   end
end

function mod:SetupOptions()
   mod.main = mod:OptReg("Magic Runes", options.general)
   mod:OptReg(": Profiles", options.profile, "Profiles")
   mod:OptReg(": bar sizing", options.sizing, "Bar Layout")
   mod:OptReg(": bar colors", options.colors, "Bar Colors")
   mod.text = mod:OptReg(": Font & Texture", options.looks, "Font & Texture")
   

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


