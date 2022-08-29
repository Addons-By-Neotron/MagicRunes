--[[
**********************************************************************
MagicRunes - Death Knight rune cooldown displaye
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
]]

if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then
    return
end

MagicRunes = LibStub("AceAddon-3.0"):NewAddon("Magic Runes", "AceEvent-3.0", "FixedLibBars-1.0",
        "AceTimer-3.0", "AceConsole-3.0")
local mod = MagicRunes

local L = LibStub("AceLocale-3.0"):GetLocale("MagicRunes", false)

-- Silently fail embedding if it doesn't exist
local LibStub = LibStub
local LDBIcon = LibStub("LibDBIcon-1.0", true)
local LDB = LibStub("LibDataBroker-1.1", true)
local AceGUIWidgetLSMlists = AceGUIWidgetLSMlists

local Logger = LibStub("LibLogger-1.0", true)

local C = LibStub("AceConfigDialog-3.0")
local media = LibStub("LibSharedMedia-3.0")

local UnitExists = UnitExists
local UnitAura = UnitAura
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetRuneCooldown = GetRuneCooldown
local GetRuneType = GetRuneType
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local PlaySoundFile = PlaySoundFile
local fmt = string.format
local max = max
local cos = math.cos
local min = min
local pairs = pairs
local ipairs = ipairs
local select = select
local sort = sort
local tostring = tostring
local type = type
local unpack = unpack
local TWOPI = math.pi * 2
local ceil = math.ceil

local gcd = 1.5
local playerInCombat = InCombatLockdown()
local idleAlphaLevel
local addonEnabled = false
local db, isInGroup
local bars, hiddenBars = nil, nil
local runebars = {}

if Logger then
    Logger:Embed(mod)
else
    -- Enable info messages
    mod.info = function(self, ...)
        mod:Print(fmt(...))
    end
    mod.error = mod.info
    mod.warn = mod.info
    -- But disable debugging
    mod.debug = function(self, ...)
    end
    mod.trace = mod.debug
    mod.spam = mod.debug
end

local options

local runeInfo = {
    { "Blood", "B" },
    { "Unholy", "U" };
    { "Frost", "F" },
    { "Death", "D" },
}

local runeSets = {
    ["Blizzard Improved"] = {
        "Interface\\AddOns\\MagicRunes\\Textures\\BlizzardBlood.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\BlizzardFrost.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\BlizzardUnholy.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\BlizzardDeath.tga",
    },
    ["Blizzard"] = {
        "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood",
        "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost",
        "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy";
        "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death"
    },
    Japanese = {
        "Interface\\AddOns\\MagicRunes\\Textures\\JapaneseBlood.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\JapaneseFrost.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\JapaneseUnholy.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\JapaneseDeath.tga",
    },
    ["DKI/Vixen"] = {
        "Interface\\AddOns\\MagicRunes\\Textures\\VixenBlood.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\VixenFrost.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\VixenUnholy.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\VixenDeath.tga",
    },
    ["Gloss Orb by Camalus"] = {
        "Interface\\AddOns\\MagicRunes\\Textures\\GlossOrbBlood.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\GlossOrbFrost.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\GlossOrbUnholy.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\GlossOrbDeath.tga",
    },
    ["Punished by Lichborne"] = {
        "Interface\\AddOns\\MagicRunes\\Textures\\PunishedBlood.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\PunishedFrost.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\PunishedUnholy.tga",
        "Interface\\AddOns\\MagicRunes\\Textures\\PunishedDeath.tga",
    },
}

if GetRuneType == nil then
    GetRuneType = GetSpecialization()
end

mod.spellCache = {}

function mod:GetRuneIcon(icon, set)
    if not set or not runeSets[set] then
        set = db.runeSet or "Blizzard"
    end
    return runeSets[set][icon]
end

do
    local sets
    function mod:GetRuneSetList()
        if not sets then
            sets = {}
            for runeSet in pairs(runeSets) do
                sets[runeSet] = runeSet
            end
        end
        return sets
    end
end

local defaults = {
    profile = {
        displayType = mod.RUNE_DISPLAY,
        flashMode = 2,
        runeSet = "Blizzard",
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
        texture = "Minimalist",
        bgtexture = "Minimalist",
        timerOnIcon = false,
        thickness = 25,
        showSpark = true,
        minimapIcon = {}
    }
}

local function CacheSpellInfo(name, id, id2)
    local localizedName, _, icon = GetSpellInfo(id)
    if not localizedName then
        id = id2
        localizedName, _, icon = GetSpellInfo(id)
    end
    mod.spellCache[name] = { name = localizedName, icon = icon, id = id, shortname = name }
    mod.spellCache[localizedName] = mod.spellCache[name]
end

function mod:GetRuneInfo(runeid, set)
    if not runeid or runeid < 1 or runeid > 6 then
        return
    end

    local type = GetRuneType(runeid)
    local info = runeInfo[type] or runeInfo[1] -- seems sometimes the rune id is not correct. hmm
    local icon = mod:GetRuneIcon(type, set)
    if mod._vertical then
        return info[2], icon, type, db.colors[info[1]]
    else
        return L[info[1]], icon, type, db.colors[info[1]]
    end
end

function mod:OnInitialize()
    mod:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleBlizzardRuneFrameEvent")

    -- Register some sound effects since they normally aren't available
    media:Register("sound", "Drop", [[Sound\Interface\DropOnGround.wav]])
    media:Register("sound", "Error", [[Sound\Interface\Error.wav]])
    media:Register("sound", "Magic Click", [[Sound\Interface\MagicClick.wav]])
    media:Register("sound", "Ping", [[Sound\Interface\MapPing.wav]])
    media:Register("sound", "Socket Clunk", [[Sound\Interface\JewelcraftingFinalize.wav]])
    media:Register("sound", "Whisper Ping", [[Sound\Interface\iTellMessage.wav]])
    media:Register("sound", "Whisper", [[Sound\Interface\igTextPopupPing02.wav]])

    self.db = LibStub("AceDB-3.0"):New("MagicRunesDB", defaults, "Default")
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
    MagicRunesDB.point = nil
    MagicRunesDB.presets = nil
    db = self.db.profile
    idleAlphaLevel = playerInCombat and db.alphaReady or db.alphaOOC
    mod._readyFlash2 = db.readyFlashDuration / 2
    mod:UpdateLocalVariables()

    -- spells
    CacheSpellInfo("BLOODPLAGUE", 59879, 55078)
    CacheSpellInfo("FROSTFEVER", 59921, 55095)

    -- bar types
    mod.RUNIC_BAR = 1
    mod.RUNE_BAR = 2
    mod.DOT_BAR = 3
    mod.BUFF_BAR = 4

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
        self.ldb = LDB:NewDataObject("Magic Runes",
                {
                    type = "launcher",
                    label = L["Magic Runes"],
                    icon = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
                    tooltiptext = L["|cffffff00Left click|r to open the configuration screen.\n|cffffff00Right click|r to toggle the Magic Target window lock."],
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
    function(a, b)
        -- BarId
        if db.reverseSort then
            return (a.sortValue or 100) > (b.sortValue or 100)
        else
            return (a.sortValue or 100) < (b.sortValue or 100)
        end
    end,
    function(a, b)
        --  Rune, Time
        local arune = a.type or a.sortValue
        local brune = b.type or b.sortValue
        if arune == brune then
            if db.reverseSort then
                return a.value > b.value
            else
                return a.value < b.value
            end
        elseif db.reverseSort then
            return arune > brune
        else
            return arune < brune
        end
    end,

    function(a, b)
        --  Rune, Reverse Time
        local arune = a.type or a.sortValue
        local brune = b.type or b.sortValue
        if arune == brune then
            if db.reverseSort then
                return a.value < b.value
            else
                return a.value > b.value
            end
        elseif db.reverseSort then
            return arune > brune
        end
        return arune < brune
    end,

    function(a, b)
        -- Time, Rune
        if a.value == b.value then
            if db.reverseSort then
                return (a.type or a.sortValue) > (b.type or b.sortValue)
            else
                return (a.type or a.sortValue) < (b.type or b.sortValue)
            end
        elseif db.reverseSort then
            return a.value > b.value
        end
        return a.value < b.value
    end,
    function(a, b)
        -- Reverse Time, Rune
        if a.value == b.value then
            if db.reverseSort then
                return (a.type or a.sortValue) > (b.type or b.sortValue)
            else
                return (a.type or a.sortValue) < (b.type or b.sortValue)
            end
        elseif db.reverseSort then
            return a.value < b.value
        end
        return a.value > b.value
    end,
}

function mod:OnEnable()
    if not bars then
        bars = mod:NewBarGroup(L["Runes"], nil, db.length, db.thickness)
        bars:SetColorAt(1.00, 1, 1, 0, 1)
        bars:SetColorAt(0.00, 0.5, 0.5, 0, 1)
        bars.RegisterCallback(self, "AnchorMoved")
        bars.ReverseGrowth = mod.__ReverseGrowth
        mod.runebars = runebars
        mod.bars = bars
        mod:UpdateLocalVariables()

        hiddenBars = mod:NewBarGroup("Hidden Bars", nil, 200, 20)
        hiddenBars:Hide()
    end

    mod:ApplyProfile()
    if self.SetLogLevel then
        mod:SetLogLevel(self.logLevels.TRACE)
    end
    mod:RegisterEvent("UNIT_EXITED_VEHICLE", "HandleBlizzardRuneFrameEvent")
    mod:RegisterEvent("RUNE_POWER_UPDATE")
    if _G.GetRuneType then
        mod:RegisterEvent("RUNE_TYPE_UPDATE")
    else
        mod:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "RefreshRuneTypes")
    end
    mod:RegisterEvent("PLAYER_REGEN_ENABLED")
    mod:RegisterEvent("PLAYER_REGEN_DISABLED")
    mod:RegisterEvent("UNIT_POWER_UPDATE", "UpdateRunicPower")
    mod:RegisterEvent("UNIT_MAXPOWER", "UpdateRunicPower")
    mod:RegisterEvent("PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED")
    mod:RegisterEvent("PLAYER_DEAD", "PLAYER_REGEN_ENABLED")
    mod:RegisterEvent("PLAYER_ALIVE", "PLAYER_REGEN_ENABLED")
    mod:RegisterEvent("UNIT_AURA", "UpdateBuffStatus")
    mod:RegisterEvent("PLAYER_TARGET_CHANGED", "UpdateBuffStatus")


end

-- We mess around with bars so restore them to a prestine state
-- Yes, this is evil and all but... so much fun... muahahaha
function mod:ReleaseBar(bar)
    bar.barId = nil
    bar.type = nil
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
    bar.ownerGroup:RemoveBar(bar.name)
    bar.label:SetTextColor(1, 1, 1, 1)
    bar.timerLabel:SetTextColor(1, 1, 1, 1)
end

function mod:CreateBars()
    for id, bar in pairs(runebars) do
        if bar then
            mod:ReleaseBar(bar)
            runebars[id] = nil
        end
    end

    if not db.bars then
        return
    end
    for id, data in ipairs(db.bars) do
        if not data.hide then
            local bar = bars:NewCounterBar("MagicRunes:" .. id, "", db.showRemaining and 0 or 10, 10)

            if not bar.overlayTexture then
                bar.overlayTexture = bar:CreateTexture(nil, "OVERLAY")
                bar.overlayTexture:SetTexture("Interface/Buttons/UI-Listbox-Highlight2")
                bar.overlayTexture:SetBlendMode("ADD")
                bar.overlayTexture:SetVertexColor(1, 1, 1, 0.6)
                bar.overlayTexture:SetAllPoints()
            else
                bar.overlayTexture:Show()
            end
            bar.overlayTexture:SetAlpha(0)
            bar.barId = id
            bar.sortValue = data.sortValue or id
            bar:SetFrameLevel(100 + id) -- this is here to ensure a "consistent" order of the icons in case they are sorted somehow

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
                local icon = media:Fetch("statusbar", "Empty")
                if icon then
                    bar:SetIcon()
                    bar:ShowIcon()
                else
                    bar:HideIcon();
                end
            elseif data.type == mod.DOT_BAR then
                --	    mod:UpdateRunicPower()
                mod:SetBarLabel(id, data)
                mod:SetBarColor(bar, db.colors[data.spell])
                bar:SetIcon(mod.spellCache[data.spell].icon)
            end
            if not db.showIcon then
                bar:HideIcon()
            end
            if not db.showLabel then
                bar:HideLabel()
            end
            if not db.showTimer then
                bar:HideTimerLabel()
            end
        end
    end
end

function mod:UpdateBarIcons()
    for id, data in pairs(db.bars) do
        if data.type == mod.RUNE_BAR and runebars[id] then
            runebars[id]:SetIcon(mod:GetRuneIcon(GetRuneType(data.runeid)))
        end
    end
    if mod.modules.RuneBars then
        for id, f in pairs(mod.modules.RuneBars.bars) do
            f.icon:SetTexture(mod:GetRuneIcon(GetRuneType(f.runeId)))
        end
    end
end

function mod:OnDisable()
    mod:UnregisterAllEvents()
end

do
    local numActiveRunes = 0
    local activeRunes = {}
    local now, updated, data, bar, playAlert, tmp, newValue
    local numActiveDots, scriptActive, resort, currentRunicPower, currentMaxRunicPower

    local runeData = { {}, {}, {}, {}, {}, {} }
    local runeAlphaLevels = { 1, 1, 1, 1, 1, 1 }
    local readyFlash = {}
    local targetSpellInfo = {
        BLOODPLAGUE = {},
        FROSTFEVER = {},
    }

    function mod:UpdateRemainingTimes()
        if db.flashTimes and db.flashMode == 2 then
            mod:RefreshBarColors()
        end
        for id, barData in ipairs(db.bars) do
            bar = runebars[id]
            if bar and barData.type ~= mod.RUNIC_BAR then
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

    local function UpdateBuffDurations(spellInfo)
        for id, data in pairs(spellInfo) do
            if data.expirationTime ~= nil then
                if not data.ready then
                    data.remaining = data.expirationTime - now
                    data.value = data.duration - data.remaining
                    if data.remaining > 0 then
                        numActiveDots = numActiveDots + 1
                        if data.remaining < gcd and not data.notified then
                            if db.soundOccasion == 2 then
                                playAlert = true
                            end
                            data.notified = db.soundOccasion
                        end
                    end
                else
                    if data.notified == 3 then
                        playAlert = true
                    end
                    data.notified = nil
                end
            else
                -- just set defaults
                data.remaining = 0
                data.duration = 0
                data.expirationTime = 0
                data.ready = 0
            end
        end
    end

    local function UpdateRuneDetails(t)
        for id = 1, 6 do
            data = runeData[id]
            data.remaining = max((data.start or 0) + (data.duration or 0) - now, 0)
            data.value = (data.duration or 10) - (data.remaining or 0)
            if data.ready or data.remaining <= 0 then
                data.alpha = idleAlphaLevel
                if data.flashing then
                    data.flashTime = nil
                    data.flashPeriod = nil
                    data.flashing = nil
                end
                if data.notified == 3 then
                    playAlert = true
                end
                data.notified = nil
            elseif data.remaining < gcd then
                if not data.notified then
                    if db.soundOccasion == 2 then
                        playAlert = true
                    end
                    data.notified = db.soundOccasion
                end

                if mod.flashTimer then
                    if not data.flashing then
                        data.alpha = 1.0
                        data.flashTime = 0
                        data.flashPeriod = data.remaining / mod.flashTimer
                        data.flashing = true
                    else
                        if t then
                            data.flashTime = data.flashTime + t
                        end
                        if data.flashTime > TWOPI then
                            data.flashTime = data.flashTime - TWOPI
                        end
                        data.alpha = (cos(data.flashTime / data.flashPeriod) + 1) / 2
                    end
                else
                    if db.fadeAlphaGCD then
                        tmp = data.remaining / gcd
                        data.alpha = db.alphaGCD * tmp + idleAlphaLevel * (1 - tmp)
                    else
                        data.alpha = db.alphaGCD
                    end
                end
            elseif db.fadeAlpha then
                tmp = (data.remaining - gcd) / (10 - gcd)
                data.alpha = db.alphaActive * tmp + db.alphaGCD * (1 - tmp)
            else
                data.alpha = db.alphaActive
            end
        end
    end

    local function DoReadyFlash()
        for id, data in pairs(readyFlash) do
            if data then
                local duration = now - data.start
                bar = data.bar
                if duration > db.readyFlashDuration then
                    readyFlash[id] = nil
                    bar.overlayTexture:SetAlpha(0)
                elseif duration >= mod._readyFlash2 then
                    bar.overlayTexture:SetAlpha((db.readyFlashDuration - duration) / mod._readyFlash2)
                else
                    bar.overlayTexture:SetAlpha(duration / mod._readyFlash2)
                end
            end
        end
    end

    function mod:AddReadyFlash(bar)
        for id, data in pairs(readyFlash) do
            if data and data.bar == bar then
                data.start = now
                return
            end
        end
        if not inserted then
            readyFlash[#readyFlash + 1] = { start = now, bar = bar }
        end
    end

    local function UpdateBarDisplay()
        -- Check each bar for update
        for id, barData in ipairs(db.bars) do
            bar = runebars[id]
            if bar then
                if barData.type == mod.RUNIC_BAR then
                    if bar.value ~= currentRunicPower or
                            bar.maxValue ~= currentMaxRunicPower then
                        bar.value = currentRunicPower
                        bar:SetMaxValue(currentMaxRunicPower)
                        if db.showTimer then
                            bar.timerLabel:SetText(tostring(currentRunicPower))
                        end
                    end
                    if bar.value == 0 then
                        bar:SetAlpha(idleAlphaLevel)
                    else
                        bar:SetAlpha(1.0)
                    end
                elseif barData.type == mod.DOT_BAR or barData.type == mod.RUNE_BAR then
                    local isRuneBar
                    if barData.type == mod.DOT_BAR then
                        data = targetSpellInfo[barData.spell]
                    else
                        isRuneBar = true
                        data = runeData[barData.runeid]
                        -- Handle death runes changes
                        if bar.type ~= data.type then
                            local name, icon, type, color = mod:GetRuneInfo(barData.runeid)
                            bar.type = data.type
                            bar:SetLabel(name)
                            bar:SetIcon(icon)
                            mod:SetBarColor(bar, color)
                        end
                    end

                    if data.flashing or isRuneBar then
                        bar:SetAlpha(data.alpha)
                    end

                    if data.ready or data.remaining <= 0 then
                        if barData.type == mod.DOT_BAR then
                            -- Hide inactive dot bars
                            if bar.ownerGroup ~= hiddenBars then
                                resort = true
                                bars:MoveBarToGroup(bar, hiddenBars)
                            end
                        end

                        if bar.notReady or numActiveRunes == 0 then
                            if db.showRemaining then
                                bar:SetValue(0)
                            else
                                bar:SetValue(bar.maxValue)
                            end
                            bar.timerLabel:SetText("")
                            bar.notReady = nil
                            if bar.gcdnotify then
                                if db.readyFlash and barData.type == mod.RUNE_BAR then
                                    mod:AddReadyFlash(bar)
                                end
                            end
                            bar.gcdnotify = nil
                        end
                    else
                        if barData.type == mod.DOT_BAR then
                            -- Show newly active dot bar
                            if bar.ownerGroup ~= bars then
                                hiddenBars:MoveBarToGroup(bar, bars)
                                resort = true
                            end
                        end
                        newValue = db.showRemaining and data.remaining or data.value
                        if bar.value ~= newValue then
                            if data.remaining < gcd then
                                bar.gcdnotify = true
                            end
                            bar:SetValue(newValue, data.duration)
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
    end

    function mod.UpdateBars(self, t)
        currentRunicPower = UnitPower("player")
        currentMaxRunicPower = UnitPowerMax("player")
        resort, playAlert = nil, nil
        numActiveDots = 0
        now = GetTime()

        -- Update the value and remaining time for all runes
        UpdateRuneDetails(t)

        -- this updates the remaining and current value of the dots/buffs
        UpdateBuffDurations(targetSpellInfo)

        -- Do the "rune is ready" flashing
        if db.readyFlash and #readyFlash > 0 then
            DoReadyFlash()
        end

        UpdateBarDisplay()

        if resort then
            mod:SetOrientation()
            mod:SetSize()
            hiddenBars:SortBars()
        elseif db.sortMethod > 1 then
            bars:SortBars()
        end

        if playAlert and mod.soundFile then
            PlaySoundFile(mod.soundFile)
        end

        -- Execute the update method in each module
        for name, module in pairs(mod.modules) do
            if module.OnUpdate then
                module:OnUpdate(t or 0, runeData, targetSpellInfo)
            end
        end


        -- Check whether or not to cancel the OnUpdate method
        if #readyFlash > 0                              -- animations
                or numActiveRunes > 0      -- runes are active
                or numActiveDots > 0       -- dot display active
                or currentRunicPower > 0   -- non-zero runic power
        then
            -- something is going on, and timer isn't active so enable it
            if not scriptActive then
                bars:SetScript("OnUpdate", mod.UpdateBars)
                scriptActive = true
            end
        elseif scriptActive then
            -- We're active, but have nothing to do - disable OnUpdate
            bars:SetScript("OnUpdate", nil)
            scriptActive = nil
        end
    end

    function mod:UpdateBuffStatus(event, unit)
        local spellInfo, filter
        if event == "PLAYER_TARGET_CHANGED" then
            unit = "target"
        end
        if unit == "target" then
            spellInfo = targetSpellInfo
            filter = "HARMFUL"
        else
            return
        end
        for _, data in pairs(spellInfo) do
            data.ready = true
            data.duration = 0
            data.expirationTime = 0
        end

        if UnitExists(unit) then
            -- don't update if the unit doesn't exist
            local info
            for id = 1, 40 do
                local name, _, _, _, duration, expirationTime, isMine = UnitAura(unit, id, filter)
                if name and isMine == "player" then
                    info = mod.spellCache[name]
                    if info then
                        data = spellInfo[info.shortname]
                        if data then
                            -- required since unholy blight shows up on the target too
                            data.expirationTime = expirationTime
                            data.duration = duration
                            data.ready = false
                        end
                    end
                end
            end
        end
        if not scriptActive then
            mod.UpdateBars()
        end
    end

    function mod:UpdateRuneStatus(id)
        local data = runeData[id]
        local change = false
        local start, duration, ready = GetRuneCooldown(id)
        if data.start ~= start or data.duration ~= duration or data.ready ~= ready then
            data.start = start
            data.duration = duration
            data.ready = ready
            changed = true
        end
        if not data.type then
            data.type = GetRuneType(id)
            changed = true
        end
        return changed
    end

    function mod:RUNE_POWER_UPDATE(_, _, _)
        for rune = 1,6 do
            if mod:UpdateRuneStatus(rune) then
                if runeData[rune].ready then
                    if activeRunes[rune] then
                        activeRunes[rune] = nil
                        numActiveRunes = numActiveRunes - 1
                    end
                else
                    if not activeRunes[rune] then
                        numActiveRunes = numActiveRunes + 1
                        activeRunes[rune] = true
                    end
                end
            end
        end
        if not scriptActive then
            mod:UpdateBars()
        end
    end

    function mod:RUNE_TYPE_UPDATE(_, rune)
        runeData[rune].type = GetRuneType(rune)
        if not scriptActive then
            mod:UpdateBars()
        end
    end

    function mod:RefreshRuneTypes()
        for rune = 1, 6 do
            runeData[rune].type = GetRuneType(rune)
        end
        if not scriptActive then
            mod:UpdateBars()
        end
    end

    function mod:UpdateRunicPower(event, unit)
        if unit and unit ~= "player" then
            return
        end
        local current = UnitPower("player")
        local max = UnitPowerMax("player")
        local bar
        for id, data in ipairs(db.bars) do
            bar = runebars[id]
            if data.type == mod.RUNIC_BAR and bar then
                bar.value = current
                bar:SetMaxValue(max)
                if db.showTimer then
                    bar.timerLabel:SetText(tostring(current))
                end
            end
        end
        if not scriptActive then
            mod:UpdateBars()
        end
    end
end

function mod:AnchorMoved(cbk, group, button)
    db.point = { group:GetPoint() }
end

function mod:SetBarColor(bar, color)
    if not color then
        return
    end
    local rf = 0.5 + color[1] / 2
    local gf = 0.5 + color[2] / 2
    local bf = 0.5 + color[3] / 2
    bar:UnsetAllColors()

    if db.flashTimes and db.flashMode == 2 then
        local offset = gcd / 10
        local interval = offset / (db.flashTimes * 2)
        local endVal
        if db.showRemaining then
            endVal = interval
            interval = -interval
        else
            endVal = 1 - interval
            offset = 1 - offset
        end
        for val = offset, endVal, (interval * 2) do
            bar:SetColorAt(val, color[1], color[2], color[3], color[4])
            if val ~= endVal then
                bar:SetColorAt(val + interval, rf, gf, bf, 1)
            end
        end
    end
    bar:SetColorAt(0, color[1], color[2], color[3], color[4])
    bar:SetColorAt(1, color[1], color[2], color[3], color[4])
    bar.overlayTexture:SetVertexColor(min(1, rf + 0.2), min(1, gf + 0.2), min(1, bf + 0.2), bar.overlayTexture:GetAlpha())
end

function mod:PLAYER_REGEN_ENABLED()
    playerInCombat = false
    idleAlphaLevel = db.alphaOOC
    mod:RefreshRuneTypes()
    for name, module in pairs(mod.modules) do
        if module.OnCombatChange then
            module:OnCombatChange(playerInCombat)
        end
    end
end

function mod:PLAYER_REGEN_DISABLED()
    playerInCombat = true
    idleAlphaLevel = db.alphaReady
    mod:RefreshRuneTypes()
    for name, module in pairs(mod.modules) do
        if module.OnCombatChange then
            module:OnCombatChange(playerInCombat)
        end
    end
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

    -- configure based on saved data
    for from, to in pairs(varChanges) do
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
    for id = 1, 6 do
        mod:UpdateRuneStatus(id)
    end
    mod.UpdateBars()
    bars:SortBars()

    for id, module in pairs(mod.modules) do
        if module.ApplyProfile then
            module:ApplyProfile()
        end
    end

    mod:HandleBlizzardRuneFrame()
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
    for id, module in pairs(mod.modules) do
        if module.ToggleLocked then
            module:ToggleLocked(db.locked)
        end
    end
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

function mod:HandleBlizzardRuneFrameEvent(event, arg1)
    if event == "UNIT_EXITED_VEHICLE" and arg1 ~= "player" then
        return
    end
    mod:HandleBlizzardRuneFrame()
end

function mod:HandleBlizzardRuneFrame(info, val)
    if info then
        db[info[#info]] = val
    end
    if RuneFrame then
        local visible = RuneFrame:IsVisible()
        if db.hideBlizzardFrame then
            if visible then
                RuneFrame:Hide()
            end
        elseif not visible then
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
        for _, param in ipairs(presetParameters) do
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

function mod:SortAllBars()
    hiddenBars:SortBars()
    bars:SortBars()
end
