local addonFrame = CreateFrame("Frame")

local sunderSpellName = GetSpellInfo(7386)
local sunderSpellIds = {
    [7386] = true,
    [7405] = true,
    [8380] = true,
    [11596] = true,
    [11597] = true,
}

local trackedNameplates = {}
local isEnabled = true

local ICON_SIZE    = 22
local PIP_SIZE     = 5
local PIP_GAP      = 3
local MAX_STACKS   = 5
local PULSE_SPEED  = 3  -- radians per second

local sunderIconTexture = GetSpellTexture(7386)

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function GetSunderStacks(unit)
    for i = 1, 40 do
        local name, _, count, _, _, _, _, _, _, spellId = UnitDebuff(unit, i)
        if not name then
            break
        end

        if (sunderSpellName and name == sunderSpellName) or sunderSpellIds[spellId] then
            if type(count) == "number" and count > 0 then
                return count
            end
            return 1
        end
    end

    return 0
end

local function GetNameplateHealthBar(nameplate)
    if not nameplate or not nameplate.UnitFrame then
        return nil
    end

    return nameplate.UnitFrame.healthBar or nameplate.UnitFrame.HealthBar
end

local function StopPulse(indicator)
    indicator:SetScript("OnUpdate", nil)
    indicator.glow:SetAlpha(0)
end

local function StartPulse(indicator)
    indicator.pulseTime = indicator.pulseTime or 0
    indicator:SetScript("OnUpdate", function(self, elapsed)
        self.pulseTime = self.pulseTime + elapsed
        self.glow:SetAlpha(0.45 + 0.45 * math.sin(self.pulseTime * PULSE_SPEED))
    end)
end

local function BuildIndicator(nameplate)
    if nameplate.SunderIndicator then
        return nameplate.SunderIndicator
    end

    local healthBar = GetNameplateHealthBar(nameplate)
    if not healthBar then
        return nil
    end

    -- Root container sits just below the health bar, left-aligned
    local indicator = CreateFrame("Frame", nil, nameplate)
    indicator:SetFrameStrata(nameplate:GetFrameStrata())
    indicator:SetFrameLevel(healthBar:GetFrameLevel() + 15)
    indicator:SetSize(ICON_SIZE + 2, ICON_SIZE + PIP_SIZE + PIP_GAP + 2)
    indicator:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", -1, -3)
    indicator:Hide()

    -- Pulsing glow halo behind the icon (green at max stacks)
    local glow = indicator:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT",     indicator, "TOPLEFT",     -3,  3)
    glow:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT",  3, -3)
    glow:SetColorTexture(0, 1, 0, 0)
    indicator.glow = glow

    -- Dark 1px border framing the icon (WoW debuff icon style)
    local iconBorder = indicator:CreateTexture(nil, "BORDER")
    iconBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    iconBorder:SetPoint("TOPLEFT", indicator, "TOPLEFT", 0, 0)
    iconBorder:SetColorTexture(0, 0, 0, 1)
    indicator.iconBorder = iconBorder

    -- Sunder Armor spell icon, edge-trimmed exactly like WoW's debuff frames
    local icon = indicator:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", 1, -1)
    icon:SetTexture(sunderIconTexture)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    indicator.icon = icon

    -- Stack count badge — bottom-right of icon, identical to default debuff display
    local count = indicator:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -1)
    count:SetJustifyH("RIGHT")
    count:SetShadowColor(0, 0, 0, 1)
    count:SetShadowOffset(1, -1)
    indicator.count = count

    -- Five pip squares below the icon, one per stack
    local pips = {}
    for j = 1, MAX_STACKS do
        local pip = indicator:CreateTexture(nil, "ARTWORK")
        pip:SetSize(PIP_SIZE, PIP_SIZE - 1)
        pip:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", (j - 1) * (PIP_SIZE + PIP_GAP), -(PIP_GAP + 1))
        pips[j] = pip
    end
    indicator.pips = pips

    nameplate.SunderIndicator = indicator
    return indicator
end

local function SetIndicatorVisual(indicator, stacks)
    if stacks <= 0 then
        StopPulse(indicator)
        indicator:Hide()
        return
    end

    local isMax = stacks >= MAX_STACKS
    -- Amber while building, green when maxed
    local r, g, b = isMax and 0.2 or 1.0,
                    isMax and 1.0 or 0.65,
                    isMax and 0.2 or 0.0

    -- Icon border tint
    indicator.iconBorder:SetColorTexture(r * 0.55, g * 0.55, b * 0.55, 1)

    -- Glow: pulse green at max, hidden otherwise
    indicator.glow:SetColorTexture(r, g, b, 0)
    if isMax then
        StartPulse(indicator)
    else
        StopPulse(indicator)
    end

    -- Count badge: hidden at 1 (obvious), shown at 2+
    if stacks > 1 then
        indicator.count:SetText(stacks)
        indicator.count:SetTextColor(isMax and 0.3 or 1, 1, isMax and 0.3 or 1, 1)
    else
        indicator.count:SetText("")
    end

    -- Fill pips: lit = stack colour, unlit = dark grey
    for j = 1, MAX_STACKS do
        if j <= stacks then
            indicator.pips[j]:SetColorTexture(r, g, b, 0.92)
        else
            indicator.pips[j]:SetColorTexture(0.15, 0.15, 0.15, 0.70)
        end
    end

    indicator:Show()
end

local function HideAllIndicators()
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if plate.SunderIndicator then
            plate.SunderIndicator:Hide()
        end
    end
end

local function UpdateNameplate(unit)
    if not IsNameplateUnit(unit) then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then
        return
    end

    local indicator = BuildIndicator(nameplate)
    if not indicator then
        return
    end

    if not isEnabled then
        indicator:Hide()
        return
    end

    local stacks = GetSunderStacks(unit)
    SetIndicatorVisual(indicator, stacks)
end

local function RegisterNameplate(unit)
    if not IsNameplateUnit(unit) then
        return
    end

    trackedNameplates[unit] = true
    UpdateNameplate(unit)
end

local function UnregisterNameplate(unit)
    trackedNameplates[unit] = nil

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if nameplate and nameplate.SunderIndicator then
        nameplate.SunderIndicator:Hide()
    end
end

local function RefreshAllNameplates()
    if not isEnabled then
        HideAllIndicators()
        return
    end

    for unit in pairs(trackedNameplates) do
        UpdateNameplate(unit)
    end
end

local function PrintStatus()
    print("Sunder: " .. (isEnabled and "enabled" or "disabled"))
end

SLASH_SUNDER1 = "/sunder"
SlashCmdList.SUNDER = function(msg)
    local command = string.lower(strtrim(msg or ""))

    if command == "" or command == "toggle" then
        isEnabled = not isEnabled
        if not isEnabled then
            HideAllIndicators()
        else
            RefreshAllNameplates()
        end
        PrintStatus()
        return
    end

    if command == "on" then
        isEnabled = true
        RefreshAllNameplates()
        PrintStatus()
        return
    end

    if command == "off" then
        isEnabled = false
        HideAllIndicators()
        PrintStatus()
        return
    end

    if command == "status" then
        PrintStatus()
        return
    end

    print("Sunder commands: /sunder, /sunder toggle, /sunder on, /sunder off, /sunder status")
end

addonFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        wipe(trackedNameplates)

        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            if plate.namePlateUnitToken then
                RegisterNameplate(plate.namePlateUnitToken)
            end
        end
        return
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        RegisterNameplate(unit)
        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        UnregisterNameplate(unit)
        return
    end

    if event == "UNIT_AURA" then
        if trackedNameplates[unit] then
            UpdateNameplate(unit)
        end
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        RefreshAllNameplates()
    end
end)

addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addonFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addonFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
addonFrame:RegisterEvent("UNIT_AURA")
addonFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
