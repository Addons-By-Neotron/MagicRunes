--[[
**********************************************************************
MagicRunes Icon Display - Death Knight rune cooldown display, icon style
**********************************************************************
This file is part of Magic Runes, a World of Warcraft Addon

Magic Runes is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Magic Runes is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with Magic Runes.  If not, see <http://www.gnu.org/licenses/>.

**********************************************************************

This file is used for an optiona advanced icon-only display mode
]]

if not MagicRunes then return end -- not a DK

local LibStub = LibStub
local L = LibStub("AceLocale-3.0"):GetLocale("MagicRunes", false)
local LBF = LibStub("LibButtonFacade", true)
local media = LibStub("LibSharedMedia-3.0")

local pairs = pairs
local _G = _G
local select = select
local UIParent = UIParent
local ipairs = ipairs
local ceil = math.ceil
local unpack = unpack
local sin = math.sin
local cos = math.cos
local degreeToRadian = math.pi / 180

local mod = MagicRunes
local plugin = {}
local icons = {}
local lbfGroup
local iconFrame 
local iconFrameSize
local db


-- Different layout options
plugin.STYLE_STRAIGHT    = 1
plugin.STYLE_CIRCLE = 2


-- Also includes defaults
local defaults = {
   runeSet = "Blizzard Improved", 
   vertSpacing = 1,
   horizSpacing = 1,
   scale = 1.0,
   layout = 1,
   runeOrder = 1,
   width = 6,
   edgeSize = 16,
   inset = 4,
   backdropColors = {
      backgroundColor = { 0, 0, 0, 0.5},
      borderColor = { 0.88, 0.88, 0.88, 0.8 },
   },
   background = "Solid",
   border = "None",
   style = plugin.STYLE_STRAIGHT, 
   -- Ellipsis layout
   majorRadius = 100,
   minorRadius = 80,
   spread = 216,
   startAngle = 180,
}

local runeOrder = {
   { 1, 2, 3, 4, 5, 6}, -- BBUUFF
   { 1, 3, 5, 2, 4, 6}, -- BUFBUF
   { 1, 2, 5, 6, 3, 4}, -- BBFFUU
   { 1, 2, 5, 3, 6, 4}, -- BBFUFU
   { 5, 3, 6, 4, 1, 2}, -- FUFUBB
   { 1, 5, 3, 4, 6, 2}, -- BFUUFB
   { 1, 3, 5, 6, 4, 2}, -- BUFFUB

}


-- Called every on update cycle
local nextUpdateDelay = 0
function plugin:OnUpdate(time, runeData)
   if not db.enabled then return end
   nextUpdateDelay = nextUpdateDelay - time
   if time == 0 or nextUpdateDelay <= 0 then
      nextUpdateDelay = 0.05 
      for id, data in pairs(runeData) do
	 local f = icons[id]
	 f:SetAlpha(data.alpha)
	 if not data.ready and data.start and data.duration then
	    f.cooldown:SetCooldown(data.start, data.duration)
	 end
	 
	 -- Handle death runes changes
	 if f.type ~= data.type then
	    f.type = data.type
	    f.icon:SetTexture(mod:GetRuneIcon(f.type, db.runeSet))
	 end	 
      end
   end
end

function plugin:SkinChanged(skinId, gloss, backdrop, group, button, colors)
   db.skinId = skinId
   db.gloss = gloss
   db.backdrop = backdrop
   db.colors = colors
end

function plugin:OnEnable()
   plugin:SetupDefaultOptions()
   -- Skin setup
   if LBF then
      lbfGroup = LBF:Group("MagicRunes", "Icon Display")
      lbfGroup.SkinID = db.skinId or "Blizzard"
      lbfGroup.Backdrop = db.backdrop
      lbfGroup.Gloss = db.gloss
      lbfGroup.Colors = db.colors or {}
      
      LBF:RegisterSkinCallback("MagicRunes", self.SkinChanged, self)
   end

   iconFrame = CreateFrame("Frame", "MagicRunesIconFrame", UIParent)
   iconFrame:SetScale(db.scale)
   iconFrame:SetMovable(true)
   iconFrame:SetFrameLevel(0)
   iconFrame:SetScript("OnDragStart",
		       function(self) self:StartMoving() end)
   iconFrame:SetScript("OnDragStop",
		       function(self)
			  plugin:SavePosition()
			  self:StopMovingOrSizing()
		       end)
   
   for id = 1, 6 do
      local fn = "MagicRunesIcon"..id
      
      -- Rune frame
      local f = CreateFrame("Button", fn , iconFrame, "ActionButtonTemplate")
      iconFrameSize = f:GetWidth()
      f:EnableMouse(false)
      f.cooldown = _G[fn.."Cooldown"]
      f.icon = _G[fn.."Icon"]
      local icon, type = select(2, mod:GetRuneInfo(id, db.runeSet))
      f.icon:SetTexture(icon)
      f.type = type
      f.runeId = id
      icons[id] = f
      
      if lbfGroup then
	 -- Button Facade support
	 lbfGroup:AddButton(f)
      end
   end
   plugin:SetupOptions()
   plugin:ApplyProfile()
end

function plugin:ApplyProfile()
   plugin:SetupDefaultOptions()
   plugin:ToggleLocked(mod.db.profile.locked)
   plugin:AnchorIcons()
   plugin:LoadPosition()

   if db.enabled then iconFrame:Show() else iconFrame:Hide() end
   for id = 1,6 do
      icons[id].icon:SetTexture(mod:GetRuneIcon(icons[id].type, db.runeSet))
   end
end

function plugin:SavePosition()
   local s = iconFrame:GetEffectiveScale()
   local top = iconFrame:GetTop()
   if not top then return end -- hmm
   if db.flipy then
      db.posy = iconFrame:GetBottom() * s
      db.anchor = "BOTTOM"
   else
      db.posy =  top * s - UIParent:GetHeight()*UIParent:GetEffectiveScale() 
      db.anchor = "TOP"
   end
   if db.flipx then
      db.anchor = db.anchor .. "RIGHT"
      db.posx = iconFrame:GetRight() * s - UIParent:GetWidth()*UIParent:GetEffectiveScale() 
   else
      db.anchor = db.anchor .. "LEFT"
      db.posx = iconFrame:GetLeft() * s
   end
end

function plugin:LoadPosition(bin)
   local posx = db.posx 
   local posy = db.posy
   local anchor = db.anchor
   iconFrame:ClearAllPoints()
   if not anchor then anchor = "TOPLEFT" end

   local s = iconFrame:GetEffectiveScale()

   if posx and posy then
      iconFrame:SetPoint(anchor, posx/s, posy/s)
   else
      iconFrame:SetPoint(anchor, UIParent, "CENTER")
   end
end

function plugin:AnchorIcons()
   for id = 1,6 do icons[id]:ClearAllPoints() end

   if db.style == plugin.STYLE_STRAIGHT then
      local anchor, xmulti, ymulti, otheranchor
      local count = 1
      
      local inset = 0
      if db.border ~= "None" then
	 inset = db.edgeSize / 2
      end
      
      if db.flipy then
	 anchor = "BOTTOM"
	 ymulti = 1
      else
	 anchor = "TOP"
	 ymulti = -1
      end
      
      if db.flipx then
	 anchor = anchor .. "RIGHT"
	 xmulti = -1 
      else
	 anchor = anchor .. "LEFT"
	 xmulti = 1
      end
      
      local hpadding = (iconFrameSize + (db.horizSpacing or 0))
      local vpadding = (iconFrameSize + (db.vertSpacing or 0))
      
      local height = inset
      local xoffset = inset
      
      for _,id in ipairs(runeOrder[db.runeOrder]) do
	 if count > db.width then
	    xoffset = inset
	    count = 1
	    height = height + vpadding
	 end
	 
	 icons[id]:SetPoint(anchor, iconFrame, anchor, xmulti*xoffset, ymulti*height)
	 
	 count = count + 1
	 xoffset = xoffset + hpadding
      end
      iconFrame:SetHeight(inset*2 + ceil(6/db.width)*vpadding-db.vertSpacing)
      iconFrame:SetWidth(inset*2 + db.width*hpadding)
   elseif db.style == plugin.STYLE_CIRCLE then
      local iconPositions = {}
      local angle = db.startAngle* degreeToRadian
      local step = db.spread / 6 * degreeToRadian
      local mx = db.majorRadius
      local my = db.minorRadius
      local minx, miny, maxx, maxy = 0, 0, 0, 0
      local inset = icons[1]:GetWidth()/2
      if db.border ~= "None" then
	 inset = inset + db.edgeSize/2
      end
      
      for _,id in ipairs(runeOrder[db.runeOrder]) do
	 local x = mx * cos(angle)
	 local y = my * sin(angle)
	 if x < minx then minx = x end
	 if x > maxx then maxx = x end
	 if y < miny then miny = y end
	 if y > maxy then maxy = y end
	 iconPositions[#iconPositions+1] = { id = id, x = x, y = y } 
	 angle = angle + step
      end
      for _,data in ipairs(iconPositions) do
	 icons[data.id]:SetPoint("CENTER", iconFrame, "TOPLEFT", inset + data.x - minx, -(inset + data.y - miny))
      end
      iconFrame:SetWidth(maxx - minx + inset*2)
      iconFrame:SetHeight(maxy - miny + inset*2)
   end
   plugin:FixBackdrop()
end

-- set up the backgrop for the icon frame
function plugin:FixBackdrop()   
   local bgFrame = iconFrame:GetBackdrop()
   if not bgFrame then
      bgFrame = {
	 insets = {left = 1, right = 1, top = 1, bottom = 1}
      }
   end

   local edge = 0
   if db.border ~= "None" then
      edge = db.edgeSize
   end
   bgFrame.edgeSize = edge
   bgFrame.insets.left   = db.inset
   bgFrame.insets.right  = db.inset
   bgFrame.insets.top    = db.inset
   bgFrame.insets.bottom = db.inset


   bgFrame.edgeFile = media:Fetch("border", db.border)
   bgFrame.bgFile = media:Fetch("background", db.background)
   iconFrame:SetBackdrop(bgFrame)
   iconFrame:SetBackdropColor(unpack(db.backdropColors.backgroundColor))
   iconFrame:SetBackdropBorderColor(unpack(db.backdropColors.borderColor))
end

function plugin:ToggleLocked(locked)
   if locked then
      iconFrame:RegisterForDrag()
      iconFrame:EnableMouse(false)
   else
      iconFrame:RegisterForDrag("LeftButton")
      iconFrame:EnableMouse(true)
   end      
end


-- Configuration stuff

local options = {
   type = "group",
   name = L["Icon Display"],
   handler = plugin,
   get = "GetOption",
   set = "SetOption",
   args = {
      enabled = {
	 type = "toggle",
	 name = L["Enable Icon Display"], 
      },
      layout = {
	 type = "group",
	 name = L["Layout"],
	 hidden = "IsDisabled",
	 args = {
	    style = {
	       type = "select",
	       name = L["Layout Style"],
	       width = "full",
	       values = {
		  [plugin.STYLE_STRAIGHT] = L["Normal"],
		  [plugin.STYLE_CIRCLE] = L["Circle"],
	       },
	       order = 1,
	    },
	    vertSpacing = {
	       type = "range",
	       name = L["Vertical Spacing"],
	       width = "full",
	       min = -10, max = 60, step = 0.01,
	       order = 3,
	       hidden = "NotStyleStraight",
	    }, 
	    horizSpacing = {
	       type = "range",
	       name = L["Horizontal Spacing"],
	       width = "full",
	       min = -10, max = 60, step = 0.01,
	       order = 3,
	       hidden = "NotStyleStraight",
	    }, 
	    scale = {
	       type = "range",
	       name = L["Icon Scale"],
	       width = "full",
	       min = 0.01, max = 5, step = 0.01,
	       order = 10
	    },
	    majorRadius = {
	       type = "range",
	       name = L["Major Axis Radius"],
	       width="full",
	       desc = L["The radius of the major axis of the ellipse (horizontal radius)."],
	       min = 10, max = 500, step = 1,
	       order = 3,
	       hidden = "NotStyleCircle",
	    },
	    minorRadius = {
	       type = "range",
	       name = L["Minor Axis Radius"],
	       width="full",
	       desc = L["The radius of the minor axis of the ellipse (vertical radius)."],
	       min = 10, max = 500, step = 1,
	       order = 3,
	       hidden = "NotStyleCircle",
	    },
	    spread = {
	       type = "range",
	       name = L["Icon Spread"],
	       width="full",
	       desc = L["The number of degrees to spread the icons over - 180 degrees is a half circle, 360 degrees is a full circle."],
	       min = 0, max = 360, step = 0.1,
	       order = 3,
	       hidden = "NotStyleCircle",
	    },
	    startAngle = {
	       type = "range",
	       name = L["Start Angle"],
	       width="full",
	       desc = L["The angle to start putting the icons on."],
	       min = 0, max = 360, step = 0.1,
	       order = 3,
	       hidden = "NotStyleCircle",
	    },
	    width = {
	       type = "range",
	       name = L["Width"],
	       width="full",
	       desc = L["Number of icons per row."],
	       min = 1, max = 6, step = 1,
	       order = 4,
	       hidden = "NotStyleStraight",
	    },
	    runeOrder = {
	       type = "select",
	       name = L["Rune Order"],
	       values = {
		  "BBUUFF",
		  "BUFBUF",
		  "BBFFUU",
		  "BBFUFU",
		  "FUFUBB",
		  "BFUUFB",
		  "BUFFUB", 
	       },
	       order = 30
	    },
	    runeSet = {
	       type = "select",
	       name = L["Rune Icon Set"],
	       values = mod:GetRuneSetList(),
	       order = 35
	    },
	    flipx = {
	       type = "toggle",
	       name = L["Flip horizontal growth direction"],
	       width = "full",
	       desc = L["If toggled, the icons will expand to the left instead of to the right."],
	       order = 40, 
	    },
	    flipy = {
	       type = "toggle",
	       width = "full",
	       name = L["Flip vertical growth direction"],
	       desc = L["If toggled, the icons will expand upwards instead of downwards."],
	       order = 40, 
	    },
	 }
      },
      backgroundFrame = {
	 type = "group",
	 name = L["Background Frame"],
	 hidden = "IsDisabled",	 
	 args = {
	    background = {
	       type = 'select',
	       dialogControl = 'LSM30_Background',
	       name = L["Background Texture"],
	       desc = L["The background texture used for the bin."], 
	       order = 20,
	       values = AceGUIWidgetLSMlists.background, 
	    },
	    border = {
	       type = 'select',
	       dialogControl = 'LSM30_Border',
	       name = L["Border Texture"],
	       desc = L["The border texture used for the bin."],
	       order = 40,
	       values = AceGUIWidgetLSMlists.border, 
	    },
	    backgroundColor = {
	       type = "color",
	       name = L["Background Color"],
	       hasAlpha = true,
	       set = "SetColorOpt",
	       get = "GetColorOpt",
	       order = 30,
	    },
	    borderColor = {
	       type = "color",
	       name = L["Border color"],
	       hasAlpha = true,
	       set = "SetColorOpt",
	       get = "GetColorOpt",
	       order = 50,
	    },
	    edgeSize = {
	       type = "range",
	       name = L["Edge size"],
	       desc = L["Width of the border."],
	       min = 1, max = 50, step = 0.1,
	    },
	    inset = {
	       type = "range",
	       name = L["Inset size"],
	       desc = L["Width of the border."],
	       min = 1, max = 50, step = 0.1,
	    },
	 }
      }
   }
}


function plugin:NotStyleStraight()
   return db.style ~= plugin.STYLE_STRAIGHT
end

function plugin:NotStyleCircle()
   return db.style ~= plugin.STYLE_CIRCLE
end

-- setup the options
function plugin:SetupOptions()
   mod:OptReg("Magic Runes", options, L["Icon Display"]) -- fixme: plugin config
end

function plugin:GetOption(info)
   return db[info[#info]]
end

function plugin:SetOption(info, val)
   local var = info[#info]
   db[var] = val

   -- Do any actions required due to change in parameters
   if var == "scale" then
      iconFrame:SetScale(val)
   elseif var == "runeSet" then
      for id = 1,6 do
	 icons[id].icon:SetTexture(mod:GetRuneIcon(icons[id].type, db.runeSet))
      end
   elseif var == "enabled" then
      if val then iconFrame:Show() else iconFrame:Hide() end
   else
      plugin:AnchorIcons()
   end
end

function plugin:SetColorOpt(arg, r, g, b, a)
   local color = arg[#arg]
   db.backdropColors[color][1] = r
   db.backdropColors[color][2] = g
   db.backdropColors[color][3] = b
   db.backdropColors[color][4] = a
   plugin:FixBackdrop()
end

function plugin:GetColorOpt(arg)
   local color = arg[#arg]
   return unpack(db.backdropColors[color])
end

function plugin:IsDisabled() return not db.enabled end

function plugin:SetupDefaultOptions()
   db = mod.db.profile.icondisplay
   if not db then
      db = defaults
      mod.db.profile.icondisplay = db
   else
      for key, val in pairs(defaults) do
	 if db[key] == nil then
	    db[key] = val
	 end
      end
   end   
end

-- Register with the mothership
mod:RegisterPlugin("IconDisplay", plugin)


