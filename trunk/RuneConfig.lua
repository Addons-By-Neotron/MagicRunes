-- upvalues
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local unpack = unpack
local mod = MagicRunes
local LibStub = LibStub
local R = LibStub("AceConfigRegistry-3.0")
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local DBOpt = LibStub("AceDBOptions-3.0")
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local AceGUIWidgetLSMlists = AceGUIWidgetLSMlists
local media = LibStub("LibSharedMedia-3.0")
local db, bars, runebars

local defaultColors = {
   Blood  = { [1] = 1,   [2] = 0,   [3] = 0,   [4] = 1 },
   Unholy = { [1] = 0,   [2] = 0.7, [3] = 0,   [4] = 1 },
   Frost  = { [1] = 0,   [2] = 0.5, [3] = 1,   [4] = 1 },
   Death  = { [1] = 0.8, [2] = 0,   [3] = 0.9, [4] = 1 },
   Runic =  { [1] = 0.2, [2] = 0.7, [3] = 1,   [4] = 1 },
   Background = { [1] = 0.3, [2] = 0,3, [3] = 0.3, [4] = 0.5 },
}

local runeValues = {
   "Blood #1", "Blood #2",
   "Unholy #1", "Unholy #2",
   "Frost #1", "Frost #2",
}
local options = { 
   general = {
      type = "group",
      name = "General",
      get = "GetGlobalOption",
      handler = mod,
      order = 1,
      args = {
	 showRemaining = {
	    type = "toggle",
	    name = "Show remaining time",
	    desc = "Instead showing the time elapsed on the cooldown, show the time remaining. This means that the bars will shrink as the cooldown lowers instead of grow.",
	    width = "full",
	    set = function(_,val) db.showRemaining = val mod:UpdateRemainingTimes() end
	 },
	 minimapIcon = {
	    type = "toggle",
	    name = "Enable minimap icon",
	    desc = "Show am icon to open the config at the Minimap",
	    get = function() return not db.minimapIcon.hide end,
	    set = function(info, value) db.minimapIcon.hide = not value; LDBIcon[value and "Show" or "Hide"](LDBIcon, "MagicRunes") end,
	    disabled = function() return not LDBIcon end,
	 },
	 locked = {
	    type = "toggle",
	    name = "Lock bar positions",
	    width = "full",
	    set = function() mod:ToggleLocked() end,
	 },
	 hideBlizzardFrame = {
	    type = "toggle",
	    name = "Hide the Blizzard rune frame",
	    width = "full",
	    set = "HandleBlizzardRuneFrame",
	 },
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
	    name = 'Alert sound effect',
	    desc = 'The sound effect to play when the sound alert trigger occurs.',
	    values = AceGUIWidgetLSMlists.sound,
	    set = "SetSoundFile",
	    disabled = function() return db.soundOccasion == 1 end,
	    order = 100,
	 },
	 soundOccasion = {
	    type = "select",
	    name = "Alert sound trigger",
	    desc = "When to play the alert sound: On GCD => play when the remaining cooldown of a run goes below the global cooldown. On readiness => play when a rune becomes ready for use.",
	    values = {
	       "Never", "On GCD", "On readiness"
	    },
	    set = function(_,val) db.soundOccasion = val end,
	    order = 90,
	 },
	 preset = {
	    type = "select", 
	    name = "Load preset",
	    desc = "Presets are primarily here to give you a few ideas on how you can configure the bars. Note that the presets do now change font, texture or color options. The global scale is also not changed.",
	    values = "GetPresetList",
	    width  = "full",
	    order = 0,
	    set = function(_, preset)
		     if db.preset ~= preset then
			db.preset = preset
			for var,val in pairs(mod.presets[preset].data) do
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
      set = "SetColorOpt",
      get = "GetColorOpt",
      args = {
	 Blood = {
	    type = "color",
	    name = "Blood",
	    desc = "Color used for blood rune bars.",
	    hasAlpha = true,
	    order = 1,
	 },
	 Unholy = {
	    type = "color",
	    name = "Unholy",
	    desc = "Color used for unholy rune bars.",
	    hasAlpha = true,
	    order = 2,
	 },
	 Frost = {
	    type = "color",
	    name = "Frost",
	    desc = "Color used for frost rune bars.",
	    hasAlpha = true,
	    order = 3,
	 },
	 Death = {
	    type = "color",
	    name = "Death",
	    desc = "Color used for death rune bars.",
	    hasAlpha = true,
	    order = 4,
	 },
	 Runic = {
	    type = "color",
	    name = "Death",
	    desc = "Color used for the runic power bar.",
	    hasAlpha = true,
	    order = 5,
	 },
	 Background = {
	    type = "color",
	    name = "Background",
	    desc = "Color used for background texture.",
	    hasAlpha = true,
	    order = 10,
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
	    desc = "Show labels on the bars indicating the rune type. Note the timer cannot be shown on the icon while labels are enabled.",
	    set = function(_,val) db.showLabel = val mod:UpdateLabels() end,
	    order = 10,
	    
	 },
	 showTimer = {
	    type = "toggle",
	    name = "Show timer",
	    set = function(_,val) db.showTimer = val mod:UpdateLabels() end,
	    order = 20,
	 },	 
	 secondsOnly = {
	    type = "toggle",
	    name = "Seconds only",
	    desc = "Normally the time is shown with one decimal place when the remaining cooldown is less than the global cooldown. If this toggled on, only seconds will be shown.",
	    set = function(_,val) db.secondsOnly = val mod:UpdateLabels() end,
	    disabled = function() return not db.showTimer end,
	    order = 24,
	 },
	 timerOnIcon = {
	    type = "toggle",
	    name = "Show timer on icon",
	    desc = "Show the countdown timer on top of the icon instead of on the bar. This option is only available when labels are hidden.",
	    set = function(_,val) db.timerOnIcon = val mod:UpdateLabels() end,
	    disabled = function() return db.showLabel or not (db.showTimer and db.showIcon) end,
	    order = 25
	 },
	 showIcon = {
	    type = "toggle",
	    name = "Show icons",
	    set = function(_,val) db.showIcon = val mod:UpdateIcons() end,
	    order = 30
	 },
	 animateIcons = {
	    type = "toggle",
	    name = "Animate icons",
	    desc = "If enabled, the icons will move with the bar. If the bar texture is hidden, you'll get a display simply showing the cooldown using icons.",
	    set = function(_, val) db.animateIcons = val mod:SetOrientation() end,
	    order = 35,
	    disabled = function() return not db.showIcon end
	 },
	 showSpark = {
	    type = "toggle",
	    name = "Show spark",
	    desc = "Toggle whether or not to show the spark on active bars.",
	    set = function(_,val) db.showSpark = val mod:SetOrientation() end,
	    order = 38,
	    disabled = function() return db.animateIcons end
	 },
	 flashMode = {
	    type = "select",
	    name = "Flash mode",
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
	    name = "Number of flashes",
	    desc = "Number of times to flash bars when the remaining is less than the GCD. Set to zero to disable flashing.",
	    min = 1, max = 10, step = 1,
	    set = "SetFlashTimer",
	    hidden = function() return db.flashMode == 1 end,
	    order = 50,	    
	 },
	 readyFlash = {
	    type = "toggle",
	    name = "Flash when ready",
	    desc = "When a rune cooldown is finish, flash the bar as an extra notification source.",
	    set = "SetReadyFlashOpt",
	    order = 60,
	 },
	 readyFlashDuration = {
	    type = "range",
	    name = "Ready flash duration",
	    desc = "The time in seconds that the bar should flash when a rune becomes ready.",
	    set = "SetReadyFlashOpt",
	    min = 0.01, max = 2.5, step = 0.001,
	    disabled = function() return not db.readyFlash end,
	    order = 70,
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
	 },
	 fadeAlphaGCD = {
	    type = "toggle",
	    name = "Fade alpha from gcd to ready",
	    desc = "Fade the alpha level between the GCD level and the ready level. This option is ignored if the alpha flash notification is enabled.",
	    width = "full",
	    set = "SetGlobalOption",
	    disabled = function() return db.flashMode == 3 end,
	    order = 145,
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
	    min = 20, max = 500, step = 0.01,
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
	    set = function(_,val) db.sortMethod = val bars:SetSortFunction(mod.sortFunctions[val]) bars:SortBars() end,
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
	    desc = 'The texture used for active bars.',
	    values = AceGUIWidgetLSMlists.statusbar, 
	    set = function(_,val) db.texture = val mod:SetTexture() end,
	    order = 3
	 },
	 bgtexture = {
	    type = 'select',
	    dialogControl = 'LSM30_Statusbar',
	    name = 'Background Texture',
	    desc = 'The background texture for the bars. .',
	    values = AceGUIWidgetLSMlists.statusbar, 
	    set = function(_,val) db.bgtexture = val mod:SetTexture() end,
	    order = 4
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
	    hidden = true,
	 },
	 runeid = {
	    type = "select",
	    name = "Rune #",
	    values = runeValues,
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
	 hide = {
	    type = "toggle",
	    name = "Hide bar",
	    desc = "Toggle visibility of this bar.",
	    order = 40,
	 },
--	 delete = {
--	    type = "execute",
--	    name = "Delete bar",
--	    func = function() end,
--	    order = 20000
--	 },
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
	    func = "AddNewBar",
	    hidden = true
	 }
      }
   }   
}

mod.options = options


function mod:AddNewBar()
   db.bars[#db.bars+1] = {
      type = mod.RUNE_BAR,
      runeid = 1,
      runes = 1,
      icon = mod:GetRuneIcon(1)
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
   if var == "runes" and (not data.icon or data.icon == "" or data.icon == mod:GetRuneIcon(data.runes)) then
      data.icon = mod:GetRuneIcon(val)
   end
   data[var] = val
   mod:CreateBars()
   mod.UpdateBars()
   mod:SetupBarOptions(true) 
end


do
   local configPanes = {}
   function mod:OptReg(optname, tbl, dispname, cmd)
      local regtable
      if dispname then
	 optname = "Magic Runes"..optname
	 AC:RegisterOptionsTable(optname, tbl, cmd)
	 if not cmd then
	    regtable = ACD:AddToBlizOptions(optname, dispname, "Magic Runes")
	 end
      else
	 AC:RegisterOptionsTable(optname, tbl, cmd)
	 if not cmd then
	    regtable = ACD:AddToBlizOptions(optname, "Magic Runes")
	 end
      end
      configPanes[#configPanes+1] = optname
      return regtable
   end
   function mod:NotifyChange()
      for _,name in ipairs(configPanes) do
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
      for id,data in ipairs(db.bars) do
	 local bar = {}
	 bar.order = id
	 for key,val in pairs(options.runebar) do
	    bar[key] = val
	 end
	 if data.type == mod.RUNE_BAR then
	    bar.name = runeValues[data.runeid]
	 else
	    bar.name = "Runic bar"
	 end
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
   options.profile = DBOpt:GetOptionsTable(self.db)
   mod.main = mod:OptReg("Magic Runes", options.general)
   mod:OptReg(": Bar Alpha", options.alpha, "Alpha Levels")
   mod:OptReg(": Bar Colors", options.colors, "Colors")
   mod:OptReg(": Bar Decorations", options.deco, "Decorations")
   mod:OptReg(": Bar Layout", options.sizing, "Layout and Sorting")
   mod:OptReg(": Font & Texture", options.looks, "Font & Texture")
   mod.text = mod:OptReg(": Profiles", options.profile, "Profiles")
   mod:SetupBarOptions()
   

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

function mod:UpdateLocalVariables()
   db = mod.db.profile
   bars = mod.bars
   runebars = mod.runebars
end

function mod:SetIconScale(val)
   for _,bar in pairs(runebars) do
      if bar then
	 bar.icon:SetWidth(db.thickness * val)
	 bar.icon:SetHeight(db.thickness * val)
      end
   end
end

function mod:SetTexture()
   bars:SetTexture(media:Fetch("statusbar", db.texture))
   for _,bar in pairs(runebars) do
      if bar then bar.bgtexture:SetTexture(media:Fetch("statusbar", db.bgtexture)) end
   end
end

function mod:SetFont()
   bars:SetFont(media:Fetch("font", db.font), db.fontsize)
end

function mod:UpdateIcons()
   for id, data in ipairs(db.bars) do
      local bar = runebars[id]
      if bar then 
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
end

function mod:UpdateLabels()
   for id, data in ipairs(db.bars) do
      local bar = runebars[id]
      if bar then 
	 if db.showLabel then bar:ShowLabel() else bar:HideLabel() end
	 if db.showTimer then
	    bar:ShowTimerLabel()
	    if db.timerOnIcon and not db.showLabel then
	       bar.timerLabel:ClearAllPoints()
	       bar.timerLabel:SetPoint("CENTER", bar.icon, "CENTER")
	    else
	       bar:UpdateOrientationLayout()
	    end
	 else
	    bar:HideTimerLabel()
	 end
      end
   end
end

function mod:RefreshBarColors()
   local bg = db.colors.Background
   for id,bar in pairs(runebars) do
      if bar then 
	 local bdb = db.bars[id]
	 if bdb.type == mod.RUNE_BAR then
	    local name, _, _, color = mod:GetRuneInfo(bdb.runeid)
	    mod:SetBarColor(bar, color)
	 end
	 bar:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])
      end
   end
end

function mod:SetColorOpt(arg, r, g, b, a)
   local color = arg[#arg]
   db.colors[color][1] = r
   db.colors[color][2] = g
   db.colors[color][3] = b
   db.colors[color][4] = a
   mod:RefreshBarColors()
end

function mod:GetColorOpt(arg)
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

function mod:SetReadyFlashOpt(info, val)
   db[info[#info]] = val
   mod._readyFlash2 = db.readyFlashDuration/2
end

function mod:SetDefaultColors()
   -- Populate default colors
   if not db.colors then
      db.colors = defaultColors
   else
      for color, val in pairs(defaultColors) do
	 if not db.colors[color] then
	    db.colors[color] = val
	 end
      end
   end
end

function mod:SetBarLabel(id, data)
   if data.type == mod.RUNE_BAR then
      runebars[id]:SetLabel(mod:GetRuneInfo(data.runeid))
   else
      if mod._vertical then 
	 runebars[id]:SetLabel(data.shorttitle)
      else
	 runebars[id]:SetLabel(data.title)
      end
   end
end

function mod:SetOrientation(orientation)
   if not orientation then orientation = db.orientation end
   bars:SetOrientation(orientation)
   mod._vertical = (orientation == 2 or orientation == 4)
   for id,data in ipairs(db.bars) do
      local bar = runebars[id]
      if bar then 
	 if db.showIcon and db.animateIcons then
	    bar.icon:ClearAllPoints()
	    bar.icon:SetPoint("CENTER", bar.spark)
	    bar.spark:SetAlpha(0)
	 else
	    bar.spark:SetAlpha(db.showSpark and 1 or 0)
	 end
	 mod:SetBarLabel(id, data)
      end
   end
   
   mod:SetIconScale(db.iconScale)
   mod:UpdateLabels()
end

function mod:SetSize()
   bars:SetThickness(db.thickness)
   bars:SetLength(db.length)
   bars:SortBars()
   mod:SetIconScale(db.iconScale)
end

-- Set up the default rune 1 to 6 bars
function mod:SetDefaultBars()
   local bars = db.bars or {}
   if not db.bars then
      for id = 1,6 do
	 bars[#bars+1] = {
	    type = 2,
	    runeid = id,
	 }
      end
      db.bars = bars
   end
   if not bars[7] then
      -- make sure we got the runic bar
      bars[7] = { type = 1, title = "Runic", shorttitle = "R" }
   end
   mod:SetupBarOptions(true)
end

function mod:SetFlashTimer(_, val)
   if val then db.flashTimes = val end
   
   if db.flashTimes and db.flashTimes > 0 and db.flashMode == 3 then
      flashTimer = db.flashTimes * 2 * PI
   else
      flashTimer = nil
   end
   mod:RefreshBarColors()
end

function mod:SetSoundFile(_,val)
   if val then
      db.sound = val
   end
   mod.soundFile = media:Fetch("sound", db.sound)
end

