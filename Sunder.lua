local addonFrame = CreateFrame("Frame")

local DEFAULTS = {
    showCounter = true,
    showPips = true,
    iconSize = 22,
    pulseSpeed = 3,
}

local settings = {}

local sunderSpellName = GetSpellInfo(SUNDER_SPELL_ID)
local sunderSpellIds = {
    [SUNDER_SPELL_ID_RANK1] = true,
    [SUNDER_SPELL_ID_RANK2] = true,
    [SUNDER_SPELL_ID_RANK3] = true,
    [SUNDER_SPELL_ID_RANK4] = true,
    [SUNDER_SPELL_ID_RANK5] = true,
}

local trackedNameplates = {}
local isEnabled = true

local sunderIconTexture = GetSpellTexture(SUNDER_SPELL_ID)

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function GetSunderStacks(unit)
    for i = 1, SUNDER_DEBUFF_SCAN_MAX do
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
        self.glow:SetAlpha(SUNDER_PULSE_ALPHA_MIN + SUNDER_PULSE_ALPHA_MAX * math.sin(self.pulseTime * settings.pulseSpeed))
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
    indicator:SetFrameLevel(healthBar:GetFrameLevel() + SUNDER_FRAME_LEVEL_OFFSET)
    local iconSize = settings.iconSize
    indicator:SetSize(iconSize + SUNDER_ICON_BORDER_PAD,
                      iconSize + SUNDER_PIP_SIZE + SUNDER_PIP_GAP + SUNDER_ICON_BORDER_PAD)
    indicator:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT",
                       SUNDER_ICON_ANCHOR_X, SUNDER_ICON_ANCHOR_Y)
    indicator:Hide()

    -- Pulsing glow halo behind the icon (green at max stacks)
    local glow = indicator:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT",     indicator, "TOPLEFT",
                  -SUNDER_GLOW_MARGIN,  SUNDER_GLOW_MARGIN)
    glow:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT",
                   SUNDER_GLOW_MARGIN, -SUNDER_GLOW_MARGIN)
    glow:SetColorTexture(0, 1, 0, 0)
    indicator.glow = glow

    -- Dark 1px border framing the icon
    local iconBorder = indicator:CreateTexture(nil, "BORDER")
    iconBorder:SetSize(iconSize + SUNDER_ICON_BORDER_PAD, iconSize + SUNDER_ICON_BORDER_PAD)
    iconBorder:SetPoint("TOPLEFT", indicator, "TOPLEFT", 0, 0)
    iconBorder:SetColorTexture(0, 0, 0, 1)
    indicator.iconBorder = iconBorder

    -- Sunder Armor spell icon
    local icon = indicator:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("TOPLEFT", iconBorder, "TOPLEFT",
                   SUNDER_ICON_BORDER_INSET, -SUNDER_ICON_BORDER_INSET)
    icon:SetTexture(sunderIconTexture)
    icon:SetTexCoord(unpack(SUNDER_ICON_TEXCOORD))
    indicator.icon = icon

    -- Stack count badge — bottom-right of icon, identical to default debuff display
    local count = indicator:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT",
                    SUNDER_COUNT_OFFSET_X, SUNDER_COUNT_OFFSET_Y)
    count:SetJustifyH("RIGHT")
    count:SetShadowColor(0, 0, 0, 1)
    count:SetShadowOffset(SUNDER_SHADOW_OFFSET_X, SUNDER_SHADOW_OFFSET_Y)
    indicator.count = count

    -- Five pip squares below the icon, one per stack
    local pips = {}
    for j = 1, SUNDER_MAX_STACKS do
        local pip = indicator:CreateTexture(nil, "ARTWORK")
        pip:SetSize(SUNDER_PIP_SIZE, SUNDER_PIP_SIZE - 1)
        pip:SetPoint("TOPLEFT", icon, "BOTTOMLEFT",
                     (j - 1) * (SUNDER_PIP_SIZE + SUNDER_PIP_GAP), -(SUNDER_PIP_GAP + 1))
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
    indicator:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT",
                       SUNDER_ICON_ANCHOR_X, SUNDER_ICON_ANCHOR_Y)
    indicator:SetSize(iconSize + SUNDER_ICON_BORDER_PAD,
                      iconSize + SUNDER_PIP_SIZE + SUNDER_PIP_GAP + SUNDER_ICON_BORDER_PAD)

    indicator.iconBorder:SetSize(iconSize + SUNDER_ICON_BORDER_PAD,
                                 iconSize + SUNDER_ICON_BORDER_PAD)
    indicator.icon:ClearAllPoints()
    indicator.icon:SetPoint("TOPLEFT", indicator.iconBorder, "TOPLEFT",
                             SUNDER_ICON_BORDER_INSET, -SUNDER_ICON_BORDER_INSET)
    indicator.icon:SetSize(iconSize, iconSize)

    indicator.count:ClearAllPoints()
    indicator.count:SetPoint("BOTTOMRIGHT", indicator.icon, "BOTTOMRIGHT",
                              SUNDER_COUNT_OFFSET_X, SUNDER_COUNT_OFFSET_Y)

    for j = 1, SUNDER_MAX_STACKS do
        indicator.pips[j]:ClearAllPoints()
        indicator.pips[j]:SetPoint("TOPLEFT", indicator.icon, "BOTTOMLEFT",
                                   (j - 1) * (SUNDER_PIP_SIZE + SUNDER_PIP_GAP), -(SUNDER_PIP_GAP + 1))
    end

    indicator.iconSize = iconSize
end

local function SetIndicatorVisual(indicator, stacks)
    if stacks <= 0 then
        StopPulse(indicator)
        indicator:Hide()
        return
    end

    local isMax = stacks >= SUNDER_MAX_STACKS
    -- Amber while building, cyan-blue when maxed
    local r = isMax and SUNDER_COLOR_MAX_R or SUNDER_COLOR_BUILD_R
    local g = isMax and SUNDER_COLOR_MAX_G or SUNDER_COLOR_BUILD_G
    local b = isMax and SUNDER_COLOR_MAX_B or SUNDER_COLOR_BUILD_B

    -- Icon border tint
    indicator.iconBorder:SetColorTexture(r * SUNDER_BORDER_DARKEN,
                                         g * SUNDER_BORDER_DARKEN,
                                         b * SUNDER_BORDER_DARKEN, 1)

    -- Glow: pulse at max, hidden otherwise
    indicator.glow:SetColorTexture(r, g, b, isMax and SUNDER_PULSE_ALPHA_MAX or 0)
    if isMax then
        StartPulse(indicator)
    else
        StopPulse(indicator)
    end

    -- Count badge: hidden at 1 (obvious), shown at 2+ only if enabled
    if settings.showCounter and stacks > 1 then
        indicator.count:SetText(stacks)
        indicator.count:SetTextColor(isMax and SUNDER_COUNT_MAX_TINT or 1, 1,
                                     isMax and SUNDER_COUNT_MAX_TINT or 1, 1)
    else
        indicator.count:SetText("")
    end

    -- Fill pips: lit = stack colour, unlit = dark grey, only if enabled
    if settings.showPips then
        for j = 1, SUNDER_MAX_STACKS do
            if j <= stacks then
                indicator.pips[j]:SetColorTexture(r, g, b, SUNDER_PIP_LIT_ALPHA)
            else
                indicator.pips[j]:SetColorTexture(SUNDER_PIP_DIM_R, SUNDER_PIP_DIM_G,
                                                  SUNDER_PIP_DIM_B, SUNDER_PIP_DIM_ALPHA)
            end
        end
    else
        -- Hide all pips if disabled
        for j = 1, SUNDER_MAX_STACKS do
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
    frame:SetSize(SUNDER_OPTIONS_WIDTH, SUNDER_OPTIONS_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    -- Background texture
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(SUNDER_OPTIONS_BG_R, SUNDER_OPTIONS_BG_G,
                       SUNDER_OPTIONS_BG_B, SUNDER_OPTIONS_BG_A)

    -- Border (simple dark frame)
    local border = frame:CreateTexture(nil, "BORDER")
    border:SetAllPoints(frame)
    border:SetColorTexture(SUNDER_OPTIONS_BORDER_R, SUNDER_OPTIONS_BORDER_G,
                           SUNDER_OPTIONS_BORDER_B, 1)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border:SetHeight(2)

    local borderBottom = frame:CreateTexture(nil, "BORDER")
    borderBottom:SetAllPoints(frame)
    borderBottom:SetColorTexture(SUNDER_OPTIONS_BORDER_R, SUNDER_OPTIONS_BORDER_G,
                                 SUNDER_OPTIONS_BORDER_B, 1)
    borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetHeight(2)

    local borderLeft = frame:CreateTexture(nil, "BORDER")
    borderLeft:SetColorTexture(SUNDER_OPTIONS_BORDER_R, SUNDER_OPTIONS_BORDER_G,
                               SUNDER_OPTIONS_BORDER_B, 1)
    borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(2)

    local borderRight = frame:CreateTexture(nil, "BORDER")
    borderRight:SetColorTexture(SUNDER_OPTIONS_BORDER_R, SUNDER_OPTIONS_BORDER_G,
                                SUNDER_OPTIONS_BORDER_B, 1)
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
    iconSizeSlider:SetSize(SUNDER_SLIDER_WIDTH, 20)
    iconSizeSlider:SetMinMaxValues(SUNDER_ICON_SIZE_MIN, SUNDER_ICON_SIZE_MAX)
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
    pulseSpeedSlider:SetSize(SUNDER_SLIDER_WIDTH, 20)
    pulseSpeedSlider:SetMinMaxValues(SUNDER_PULSE_SPEED_MIN, SUNDER_PULSE_SPEED_MAX)
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
