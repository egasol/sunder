local addonFrame = CreateFrame("Frame")

local DEFAULTS = {
    showCounter = true,
    showPips = true,
    iconSize = 22,
    pulseSpeed = 3,
}

local settings = {}

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

local PIP_SIZE     = 5
local PIP_GAP      = 3
local MAX_STACKS   = 5

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
        self.glow:SetAlpha(0.45 + 0.45 * math.sin(self.pulseTime * settings.pulseSpeed))
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
    local iconSize = settings.iconSize
    indicator:SetSize(iconSize + 2, iconSize + PIP_SIZE + PIP_GAP + 2)
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
    iconBorder:SetSize(iconSize + 2, iconSize + 2)
    iconBorder:SetPoint("TOPLEFT", indicator, "TOPLEFT", 0, 0)
    iconBorder:SetColorTexture(0, 0, 0, 1)
    indicator.iconBorder = iconBorder

    -- Sunder Armor spell icon, edge-trimmed exactly like WoW's debuff frames
    local icon = indicator:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
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
    indicator.iconSize = iconSize

    nameplate.SunderIndicator = indicator
    return indicator
end

local function ApplyIndicatorLayout(nameplate, indicator)
    local healthBar = GetNameplateHealthBar(nameplate)
    if not healthBar then
        return
    end

    local iconSize = settings.iconSize

    indicator:ClearAllPoints()
    indicator:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", -1, -3)
    indicator:SetSize(iconSize + 2, iconSize + PIP_SIZE + PIP_GAP + 2)

    indicator.iconBorder:SetSize(iconSize + 2, iconSize + 2)
    indicator.icon:ClearAllPoints()
    indicator.icon:SetPoint("TOPLEFT", indicator.iconBorder, "TOPLEFT", 1, -1)
    indicator.icon:SetSize(iconSize, iconSize)

    indicator.count:ClearAllPoints()
    indicator.count:SetPoint("BOTTOMRIGHT", indicator.icon, "BOTTOMRIGHT", 2, -1)

    for j = 1, MAX_STACKS do
        indicator.pips[j]:ClearAllPoints()
        indicator.pips[j]:SetPoint("TOPLEFT", indicator.icon, "BOTTOMLEFT", (j - 1) * (PIP_SIZE + PIP_GAP), -(PIP_GAP + 1))
    end

    indicator.iconSize = iconSize
end

local function SetIndicatorVisual(indicator, stacks)
    if stacks <= 0 then
        StopPulse(indicator)
        indicator:Hide()
        return
    end

    local isMax = stacks >= MAX_STACKS
    -- Amber while building, cyan-blue when maxed
    local r, g, b = isMax and 0.2 or 1.0,
                    isMax and 0.8 or 0.65,
                    isMax and 0.5 or 0.0

    -- Icon border tint
    indicator.iconBorder:SetColorTexture(r * 0.55, g * 0.55, b * 0.55, 1)

    -- Glow: pulse green at max, hidden otherwise
    -- Set with visible base alpha so the pulse effect is actually visible
    indicator.glow:SetColorTexture(r, g, b, isMax and 0.4 or 0)
    if isMax then
        StartPulse(indicator)
    else
        StopPulse(indicator)
    end

    -- Count badge: hidden at 1 (obvious), shown at 2+ only if enabled
    if settings.showCounter and stacks > 1 then
        indicator.count:SetText(stacks)
        indicator.count:SetTextColor(isMax and 0.3 or 1, 1, isMax and 0.3 or 1, 1)
    else
        indicator.count:SetText("")
    end

    -- Fill pips: lit = stack colour, unlit = dark grey, only if enabled
    if settings.showPips then
        for j = 1, MAX_STACKS do
            if j <= stacks then
                indicator.pips[j]:SetColorTexture(r, g, b, 0.92)
            else
                indicator.pips[j]:SetColorTexture(0.15, 0.15, 0.15, 0.70)
            end
        end
    else
        -- Hide all pips if disabled
        for j = 1, MAX_STACKS do
            indicator.pips[j]:SetColorTexture(0, 0, 0, 0)
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

    ApplyIndicatorLayout(nameplate, indicator)

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

local function CreateOptionsUI()
    local frame = CreateFrame("Frame", "SunderOptionsFrame", UIParent)
    frame:SetSize(320, 280)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    -- Background texture
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

    -- Border (simple dark frame)
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border:SetHeight(2)

    local borderBottom = frame:CreateTexture(nil, "BORDER")
    borderBottom:SetAllPoints(frame)
    borderBottom:SetColorTexture(0.3, 0.3, 0.3, 1)
    borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(2)

    local borderLeft = frame:CreateTexture(nil, "BORDER")
    borderLeft:SetColorTexture(0.3, 0.3, 0.3, 1)
    borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(2)

    local borderRight = frame:CreateTexture(nil, "BORDER")
    borderRight:SetColorTexture(0.3, 0.3, 0.3, 1)
    borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderRight:SetWidth(2)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("Sunder Configuration")

    -- Show Counter checkbox
    local counterCB = CreateFrame("CheckButton", "SunderCounterCB", frame, "UICheckButtonTemplate")
    counterCB:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
    counterCB:SetChecked(settings.showCounter)
    counterCB.label = counterCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    counterCB.label:SetPoint("LEFT", counterCB, "RIGHT", 5, 0)
    counterCB.label:SetText("Show Stack Counter")
    counterCB:SetScript("OnClick", function(self)
        settings.showCounter = self:GetChecked()
        SunderDB.showCounter = settings.showCounter
        RefreshAllNameplates()
    end)

    -- Show Pips checkbox
    local pipsCB = CreateFrame("CheckButton", "SunderPipsCB", frame, "UICheckButtonTemplate")
    pipsCB:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -80)
    pipsCB:SetChecked(settings.showPips)
    pipsCB.label = pipsCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pipsCB.label:SetPoint("LEFT", pipsCB, "RIGHT", 5, 0)
    pipsCB.label:SetText("Show Stack Pips")
    pipsCB:SetScript("OnClick", function(self)
        settings.showPips = self:GetChecked()
        SunderDB.showPips = settings.showPips
        RefreshAllNameplates()
    end)

    -- Icon Size slider
    local iconSizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    iconSizeLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -115)
    iconSizeLabel:SetText("Icon Size:")

    local iconSizeSlider = CreateFrame("Slider", "SunderIconSizeSlider", frame, "OptionsSliderTemplate")
    iconSizeSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -140)
    iconSizeSlider:SetSize(270, 20)
    iconSizeSlider:SetMinMaxValues(16, 32)
    iconSizeSlider:SetValue(settings.iconSize)
    iconSizeSlider:SetValueStep(1)
    iconSizeSlider:SetScript("OnValueChanged", function(self, value)
        settings.iconSize = math.floor(value)
        SunderDB.iconSize = settings.iconSize
        iconSizeSlider.text:SetText("Icon Size: " .. settings.iconSize .. "px")
        -- Resize all existing indicators in place for immediate visual feedback
        local plates = C_NamePlate.GetNamePlates() or {}
        for _, plate in ipairs(plates) do
            if plate.SunderIndicator then
                ApplyIndicatorLayout(plate, plate.SunderIndicator)
            end
        end
        RefreshAllNameplates()
    end)
    iconSizeSlider.text = iconSizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconSizeSlider.text:SetPoint("BOTTOM", iconSizeSlider, "TOP", 0, 2)
    iconSizeSlider.text:SetText("Icon Size: " .. settings.iconSize .. "px")

    -- Pulse Speed slider
    local pulseSpeedLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pulseSpeedLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -195)
    pulseSpeedLabel:SetText("Pulse Speed:")

    local pulseSpeedSlider = CreateFrame("Slider", "SunderPulseSpeedSlider", frame, "OptionsSliderTemplate")
    pulseSpeedSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -220)
    pulseSpeedSlider:SetSize(270, 20)
    pulseSpeedSlider:SetMinMaxValues(0.5, 6)
    pulseSpeedSlider:SetValue(settings.pulseSpeed)
    pulseSpeedSlider:SetValueStep(0.1)
    pulseSpeedSlider:SetScript("OnValueChanged", function(self, value)
        settings.pulseSpeed = tonumber(string.format("%.1f", value))
        SunderDB.pulseSpeed = settings.pulseSpeed
        pulseSpeedSlider.text:SetText("Pulse Speed: " .. settings.pulseSpeed)
        RefreshAllNameplates()
    end)
    pulseSpeedSlider.text = pulseSpeedSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pulseSpeedSlider.text:SetPoint("BOTTOM", pulseSpeedSlider, "TOP", 0, 2)
    pulseSpeedSlider.text:SetText("Pulse Speed: " .. settings.pulseSpeed)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.UpdateValues = function(self)
        counterCB:SetChecked(settings.showCounter)
        pipsCB:SetChecked(settings.showPips)
        iconSizeSlider:SetValue(settings.iconSize)
        iconSizeSlider.text:SetText("Icon Size: " .. settings.iconSize .. "px")
        pulseSpeedSlider:SetValue(settings.pulseSpeed)
        pulseSpeedSlider.text:SetText("Pulse Speed: " .. settings.pulseSpeed)
    end

    return frame
end

local optionsFrame = nil

local function PrintStatus()
    print("Sunder: " .. (isEnabled and "enabled" or "disabled"))
end

SLASH_SUNDER1 = "/sunder"
SlashCmdList.SUNDER = function(msg)
    local command = string.lower(strtrim(msg or ""))

    if command == "options" or command == "config" or command == "settings" then
        if not optionsFrame then
            optionsFrame = CreateOptionsUI()
        end
        optionsFrame:UpdateValues()
        optionsFrame:Show()
        return
    end

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

    print("Sunder commands:")
    print("/sunder -- toggle")
    print("/sunder on|off|toggle")
    print("/sunder status")
    print("/sunder options|config|settings")
end

addonFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" and string.upper(unit or "") == "SUNDER" then
        if not SunderDB then
            SunderDB = {}
        end
        for k, v in pairs(DEFAULTS) do
            if SunderDB[k] == nil then
                SunderDB[k] = v
            end
        end
        for k, v in pairs(SunderDB) do
            settings[k] = v
        end
        return
    end

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

addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addonFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addonFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
addonFrame:RegisterEvent("UNIT_AURA")
addonFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
