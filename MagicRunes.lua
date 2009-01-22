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

if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then
   return
end

if not LibStub:GetLibrary("LibBars-1.0", true) then
   LoadAddOn("LibBars-1.0") -- hrm..
end

MagicRunes = LibStub("AceAddon-3.0"):NewAddon("MagicBars", "AceEvent-3.0", "LibBars-1.0", 
					      "AceTimer-3.0", "AceConsole-3.0")
local mod = MagicRunes

-- Silently fail embedding if it doesn't exist
local LibStub = LibStub
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local LDB = LibStub("LibDataBroker-1.1", true)
local AceGUIWidgetLSMlists = AceGUIWidgetLSMlists

local Logger = LibStub("LibLogger-1.0", true)

local C = LibStub("AceConfigDialog-3.0")
local media = LibStub("LibSharedMedia-3.0")

local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetRuneCooldown = GetRuneCooldown
local GetRuneType = GetRuneType
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local PlaySoundFile = PlaySoundFile
local fmt = string.format
local max = max
local min = min
local pairs = pairs
local ipairs = ipairs
local select = select
local sort = sort
local tostring = tostring
local type = type
local unpack = unpack
local PI = math.pi

local gcd = 1.5
local flashTimer
local playerInCombat = InCombatLockdown()
local idleAlphaLevel
local addonEnabled = false
local db, isInGroup
local bars 
local runebars = {}

if Logger then
   Logger:Embed(mod)
else
   -- Enable info messages
   mod.info = function(self, ...) mod:Print(fmt(...)) end
   mod.error = mod.info
   mod.warn = mod.info
   -- But disable debugging
   mod.debug = function(self, ...) end
   mod.trace = mod.debug
   mod.spam = mod.debug
end

local options

local runeInfo = {
   { "Blood",  "B", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood"}, 
   { "Unholy", "U", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy"};
   { "Frost",  "F", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost"},
   { "Death",  "D", "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death" },
}

do
   local comboIcons = {
      runeInfo[1][3], -- BLOOD
      runeInfo[2][3], -- UNHOLY
      runeInfo[3][3], -- FROST
      runeInfo[4][3], -- FUB (death)
   }
   function mod:GetRuneIcon(icon)
      return comboIcons[icon]
   end
end

local defaults = {
   profile = {
      displayType = mod.RUNE_DISPLAY,
      flashMode = 2,
      hideBlizzardFrame = true,
      flashTimes = 2,
      readyFlash = true,
      readyFlashDuration = 0.5,
      sound = "None",
      soundOccasion = 1, -- Never
      font = "Friz Quadrata TT",
      fontsize = 14,
      hideAnchor = true,
      iconScale = 1.0,
      length = 250,
      secondsOnly = false, 
      orientation = 1,
      scale = 1.0,
      showIcon = true,
      showLabel = true,
      showTimer = true,
      alphaOOC = 1.0,
      alphaReady = 1.0,
      alphaGCD = 1.0,
      alphaActive = 0.5,
      fadeAlpha = true,
      sortMethod = 1,
      spacing = 1,
      texture   =  "Minimalist",
      bgtexture =  "Minimalist",
      timerOnIcon = false, 
      thickness = 25,
      showSpark = true,
      minimapIcon = {}
   }
}

function mod:GetRuneInfo(runeid)
   local type = GetRuneType(runeid)
   local info = runeInfo[type] or runeInfo[1] -- seems sometimes the rune id is not correct. hmm
   if mod._vertical then 
      return info[2], info[3], type, db.colors[info[1]]
   else
      return info[1], info[3], type, db.colors[info[1]]
   end
end

function mod:OnInitialize()
   self.db = LibStub("AceDB-3.0"):New("MagicRunesDB", defaults, "Default")
   self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
   MagicRunesDB.point = nil
   MagicRunesDB.presets = nil
   db = self.db.profile
   idleAlphaLevel = playerInCombat and db.alphaReady or db.alphaOOC
   mod._readyFlash2 = db.readyFlashDuration/2   
   mod:UpdateLocalVariables()

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
   mod:SetDefaultColors()
   
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
      if LDBIcon then
	 LDBIcon:Register("MagicRunes", self.ldb, db.minimapIcon)
      end
   end

   
   mod:SetupOptions()
end

mod.sortFunctions = {   
   function(a, b) -- BarId
      if db.reverseSort then
	 return (a.barId or 100) > (b.barId or 100)
      else
	 return (a.barId or 100) < (b.barId or 100)
      end
   end,
   function(a, b) --  Rune, Time
      local arune = a.type or 100
      local brune = b.type or 100
      if arune == brune then
	 if db.reverseSort then
	    return a.value > b.value
	 else
	    return a.value < b.value
	 end
      elseif db.reverseSort then
	 return  arune > brune
      else
	 return arune < brune
      end
   end, 

   function(a, b) --  Rune, Reverse Time
      local arune = a.type or 100
      local brune = b.type or 100
      if arune == brune then
	 if db.reverseSort then
	    return a.value < b.value
	 else
	    return  a.value > b.value
	 end
      elseif db.reverseSort then
	 return arune > brune 
      end
      return arune < brune 
   end, 
   
   function(a, b) -- Time, Rune
      if a.value == b.value then
	 if db.reverseSort then
	    return (a.type or 100) > (b.type or 100)
	 else
	    return (a.type or 100) < (b.type or 100)
	 end
      elseif db.reverseSort then
	 return a.value > b.value
      end
      return a.value < b.value
   end, 
   function(a, b) -- Reverse Time, Rune
      if a.value == b.value then
	 if db.reverseSort then
	    return (a.type or 100) >  (b.type or 100)
	 else
	    return (a.type or 100) < (b.type or 100)
	 end
      elseif db.reverseSort then
	 return a.value < b.value
      end
      return a.value > b.value
   end, 
}

function mod:OnEnable()
   if not bars then
      bars = mod:NewBarGroup("Runes",nil,  db.length, db.thickness)
      bars:SetColorAt(1.00, 1, 1, 0, 1)
      bars:SetColorAt(0.00, 0.5, 0.5,0, 1)
      bars.RegisterCallback(self, "AnchorMoved")
      bars.ReverseGrowth = mod.__ReverseGrowth
      mod.runebars = runebars
      mod.bars = bars
      mod:UpdateLocalVariables()
   end

   mod:ApplyProfile()
   if self.SetLogLevel then
      mod:SetLogLevel(self.logLevels.TRACE)
   end
   mod:RegisterEvent("RUNE_POWER_UPDATE")
   mod:RegisterEvent("RUNE_TYPE_UPDATE")
   mod:RegisterEvent("PLAYER_REGEN_ENABLED")
   mod:RegisterEvent("PLAYER_REGEN_DISABLED")
   mod:RegisterEvent("UNIT_RUNIC_POWER", "UpdateRunicPower")
   mod:RegisterEvent("UNIT_MAXRUNIC_POWER", "UpdateRunicPower")
   mod:RegisterEvent("PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED")
   mod:RegisterEvent("PLAYER_DEAD", "PLAYER_REGEN_ENABLED")
   mod:RegisterEvent("PLAYER_ALIVE", "PLAYER_REGEN_ENABLED")
end

-- We mess around with bars so restore them to a prestine state
-- Yes, this is evil and all but... so much fun... muahahaha
function mod:ReleaseBar(bar)
   bar.barId = nil
   bar.type  = nil
   bar.notReady = nil
   bar.iconPath = nil
   bar.overlayTexture:SetAlpha(0)
   bar.overlayTexture:Hide()
   bar.gcdnotify = false
   bar:SetScript("OnEnter", nil)
   bar:SetScript("OnLeave", nil)
   bar:SetValue(0)
   bar:SetScale(1)
   bar.spark:SetAlpha(1)
   bars:RemoveBar(bar.name)
end

function mod:CreateBars()
   for id,bar in pairs(runebars) do
      if bar then
	 mod:ReleaseBar(bar)
	 runebars[id] = nil
      end
   end
   
   if not db.bars then return end
   
   for id,data in ipairs(db.bars) do
      if not data.hide then
	 local bar = bars:NewCounterBar("MagicRunes:"..id, "", db.showRemaining and 0 or 10, 10)

	 if not bar.overlayTexture then
	    bar.overlayTexture =  bar:CreateTexture(nil, "OVERLAY")
	    bar.overlayTexture:SetTexture("Interface/Buttons/UI-Listbox-Highlight2")
	    bar.overlayTexture:SetBlendMode("ADD")
	    bar.overlayTexture:SetVertexColor(1,1,1,0.6)
	    bar.overlayTexture:SetAllPoints()
	 else
	    bar.overlayTexture:Show()
	 end
	 bar.overlayTexture:SetAlpha(0)
	 bar.barId  = id
	 bar:SetFrameLevel(100+id) -- this is here to ensure a "consistent" order of the icons in case they are sorted somehow
	 runebars[id] = bar
	 
	 if data.type == mod.RUNE_BAR then
	    local name, icon, type, color = mod:GetRuneInfo(data.runeid)
	    bar.type = type
	    bar:SetIcon(icon) 
	    bar:SetLabel(name) 
	    mod:SetBarColor(bar, color)
	 elseif data.type == mod.RUNIC_BAR then
	    mod:UpdateRunicPower()
	    mod:SetBarLabel(id, data)
	    mod:SetBarColor(bar, db.colors.Runic)
	    bar.icon:SetTexture(media:Fetch("statusbar", "Empty")) -- ugh
	 end
	 if not db.showIcon  then bar:HideIcon() end
	 if not db.showLabel then bar:HideLabel() end
	 if not db.showTimer then bar:HideTimerLabel() end
      end
   end
end

function mod:OnDisable()
   mod:UnregisterEvent("RUNE_POWER_UPDATE")
   mod:UnregisterEvent("RUNE_TYPE_UPDATE")
   mod:UnregisterEvent("UNIT_MAXRUNIC_POWER")
   mod:UnregisterEvent("UNIT_RUNIC_POWER")
   mod:UnregisterEvent("PLAYER_REGEN_ENABLED")
   mod:UnregisterEvent("PLAYER_REGEN_DISABLED")
   mod:UnregisterEvent("PLAYER_UNGHOST")
   mod:UnregisterEvent("PLAYER_DEAD")
   mod:UnregisterEvent("PLAYER_ALIVE")
end

do
   local numActiveRunes = 0
   local activeRunes = {}
   
   local runeData = { {}, {}, {}, {}, {}, {} }
   local now, updated, data, bar, playAlert, tmp, newValue
   local readyFlash = {}
   
   function mod:UpdateRemainingTimes()
      if db.flashTimes and db.flashMode == 2 then
	 mod:RefreshBarColors()
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

      local currentRunicPower = UnitPower("player")
      -- Update the value and remaining time for all runes
      for id = 1,6 do
	 data = runeData[id]
	 data.remaining = max((data.start or 0) + (data.duration or 0) - now, 0)
	 data.value = (data.duration or 10) - (data.remaining or 0)
      end

      -- Do the "rune is ready" flashing
      if db.readyFlash and #readyFlash > 0 then
	 for id,data in pairs(readyFlash) do
	    if data then
	       local duration = now - data.start
	       bar = data.bar
	       if not runeData[db.bars[bar.barId].runeid].ready or duration > db.readyFlashDuration then
		  readyFlash[id] = nil
		  bar.overlayTexture:SetAlpha(0)
	       elseif duration >= mod._readyFlash2 then
		  bar.overlayTexture:SetAlpha((db.readyFlashDuration - duration)/mod._readyFlash2)
	       else
		  bar.overlayTexture:SetAlpha(duration/mod._readyFlash2)
	       end
	    end
	 end
	 if #readyFlash == 0 and numActiveRunes == 0 then
	    bars:SetScript("OnUpdate", nil)
	 end
      end
      
      
      -- Check each bar for update
      for id,barData in ipairs(db.bars) do
	 bar = runebars[id]
	 if bar then
	    if barData.type == mod.RUNIC_BAR then
	       if bar.value ~= currentRunicPower then
		  bar:SetValue(currentRunicPower)
		  if db.showTimer then
		     bar.timerLabel:SetText(tostring(currentRunicPower))
		  end
	       end
	       if bar.value == 0 then
		  bar:SetAlpha(idleAlphaLevel)
	       else
		  bar:SetAlpha(1.0)
	       end
	    elseif barData.type == mod.RUNE_BAR then
	       data = runeData[barData.runeid]
	       -- Handle death runes changes
	       if bar.type ~= data.type then
		  local name, icon, type, color = mod:GetRuneInfo(barData.runeid)
		  bar.type = data.type
		  bar:SetLabel(name) 
		  bar:SetIcon(icon) 
		  mod:SetBarColor(bar, color)
	       end
	       
	       if data.ready or data.remaining <= 0 then
		  bar:SetAlpha(idleAlphaLevel)
		  if bar.notReady or numActiveRunes == 0 then
		     if db.showRemaining then
			bar:SetValue(0)
		     else
			bar:SetValue(bar.maxValue)
		     end
		     bar.timerLabel:SetText("")
		     bar.notReady = nil
		     if bar.flashing then bar:StopFlash() end
		     if bar.gcdnotify then
			if db.readyFlash then
			   tmp = #readyFlash
			   readyFlash[tmp+1] = { start = now, bar = bar }
			   if tmp == 0 and numActiveRunes == 0 then
			      bars:SetScript("OnUpdate", mod.UpdateBars)
			   end
			end
			if db.soundOccasion == 3 then
			   playAlert = true
			end		     
		     end
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
			   if db.soundOccasion == 2 then
			      playAlert = true
			   end
			elseif db.fadeAlphaGCD and not bar.flashing then
			   tmp = data.remaining/gcd
			   bar:SetAlpha(db.alphaGCD*tmp + idleAlphaLevel*(1-tmp))			
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
			elseif data.remaining > gcd or db.secondsOnly then
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
	 if numActiveRunes == 0 and #readyFlash == 0 then
	    if UnitPower("player") == 0 then
	       bars:SetScript("OnUpdate", nil)
	       mod.UpdateBars()
	    end
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

   function mod:RefreshRuneTypes()
      for rune = 1,6 do
	 runeData[rune].type = GetRuneType(rune)
      end
      mod:UpdateBars()
   end
   
   function mod:UpdateRunicPower(event,unit)
      if unit and unit ~= "player" then return end
      local current = UnitPower("player")
      local max = UnitPowerMax("player")
      local bar
      for id,data in ipairs(db.bars) do
	 bar = runebars[id]
	 if data.type == mod.RUNIC_BAR and bar then	    
	    bar.value = current
	    bar:SetMaxValue(max)
	    if db.showTimer then 
	       bar.timerLabel:SetText(tostring(current))
	    end
	 end
      end
      if numActiveRunes == 0 and #readyFlash == 0 then
	 if current == 0 then
	    bars:SetScript("OnUpdate", nil)
	    mod.UpdateBars()
	 else 
	    bars:SetScript("OnUpdate", mod.UpdateBars)
	 end
      end      
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
   bar.overlayTexture:SetVertexColor(min(1,rf+0.2), min(1, gf+0.2), min(1,bf+0.2), bar.overlayTexture:GetAlpha())
end

function mod:PLAYER_REGEN_ENABLED()
   playerInCombat = false
   idleAlphaLevel = db.alphaOOC
   mod:RefreshRuneTypes()
end


function mod:PLAYER_REGEN_DISABLED()
   playerInCombat = true
   idleAlphaLevel = db.alphaReady
   mod:RefreshRuneTypes()
end

-- Config option handling below
local varChanges = {
   showlabel = "showLabel",
   showtimer = "showTimer",
   sortmethod = "sortMethod",
   hideanchor = "hideAnchor",
   iconscale = "iconScale"
}

function mod:ApplyProfile()
   mod:HandleBlizzardRuneFrame()

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
   mod:ToggleLocked(db.locked)
   mod:SetSoundFile()
   bars:SetSortFunction(bars.NOOP)
   mod:SetDefaultColors()
   mod:SetDefaultBars()
   mod:CreateBars()
   mod:SetFlashTimer()
   mod:SetTexture()
   mod:SetFont()
   mod:SetSize()
   mod:SetOrientation()
   bars:SetSortFunction(mod.sortFunctions[db.sortMethod])
   bars:SetScale(db.scale)
   bars:SetSpacing(db.spacing)
   for id = 1,6 do mod:UpdateRuneStatus(id) end
   mod.UpdateBars()
   bars:SortBars()
end

function mod:OnProfileChanged(event, newdb)
   db = self.db.profile
   mod:UpdateLocalVariables()
   mod:ApplyProfile()
end

function mod:ToggleConfigDialog()
   InterfaceOptionsFrame_OpenToCategory(mod.text)
   InterfaceOptionsFrame_OpenToCategory(mod.main)
end

function mod:ToggleLocked(locked)
   if locked == nil then
      db.locked = not db.locked
   end
   if db.locked then
      bars:Lock()
   else
      bars:Unlock()
   end
   if db.hideAnchor then
      -- Show anchor if we're unlocked but lock it again if we're locked
      if db.locked then
	 if bars.button:IsVisible() then
	    bars:HideAnchor()
	 end
      elseif not bars.button:IsVisible() then
	 bars:ShowAnchor()
      end
   end
   bars:SortBars()
end

function mod:GetGlobalOption(info)
   return db[info[#info]]
end

function mod:SetGlobalOption(info, val)
   local var = info[#info]
   db[info[#info]] = val
   idleAlphaLevel = playerInCombat and db.alphaReady or db.alphaOOC
   mod.UpdateBars()
end

function mod:HandleBlizzardRuneFrame(info,val)
   if info then
      db[info[#info]] = val
   end
   if RuneFrame then
      if db.hideBlizzardFrame then
	 RuneFrame:Hide()
      else
	 RuneFrame:Show()
      end
   end
end

do
   -- DEV FUNCTION FOR CREATING PRESETS
   local presetParameters = {
      "orientation", "showLabel", "showTimer", "showIcon",
      "spacing", "length", "thickness", "iconScale",
      "animateIcons", "showRemaining",
      "alphaGCD", "alphaActive", "fadeAlpha",
      "flashMode", "flashTimes", "texture", "bgtexture",
      "timerOnIcon", "showSpark",
   }
   
   function mod:SavePreset(name, desc)
      local presets = MagicRunesDB.presets or {}
      presets[name] = { name = desc,
	 data = {}
      }
      for _,param in ipairs(presetParameters) do
	 presets[name].data[param] = db[param]
      end
      MagicRunesDB.presets = presets
   end
end

-- Override for the LibBars method. This makes it so the button doesn't move the bars when hidden or shown.
function mod:__ReverseGrowth(reverse)
	self.growup = reverse
	self.button:ClearAllPoints()
	if self.orientation % 2 == 0 then
		if reverse then
			self.button:SetPoint("TOPLEFT", self, "TOPRIGHT")
			self.button:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT")
		else
			self.button:SetPoint("TOPRIGHT", self, "TOPLEFT")
			self.button:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT")
		end
	else
		if reverse then
			self.button:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
			self.button:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT")
		else
			self.button:SetPoint("BOTTOMLEFT", self, "TOPLEFT")
			self.button:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT")
		end
	end
	self:SortBars()
end
