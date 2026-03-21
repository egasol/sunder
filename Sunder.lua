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

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function GetSunderStacks(unit)
    for i = 1, 40 do
        local name, _, _, count, _, _, _, _, _, spellId = UnitDebuff(unit, i)
        if not name then
            break
        end

        if (sunderSpellName and name == sunderSpellName) or sunderSpellIds[spellId] then
            if count and count > 0 then
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

local function BuildIndicator(nameplate)
    if nameplate.SunderIndicator then
        return nameplate.SunderIndicator
    end

    local healthBar = GetNameplateHealthBar(nameplate)
    if not healthBar then
        return nil
    end

    local indicator = CreateFrame("Frame", nil, nameplate)
    indicator:SetFrameStrata(nameplate:GetFrameStrata())
    indicator:SetFrameLevel((healthBar:GetFrameLevel() or nameplate:GetFrameLevel()) + 15)
    indicator:SetAllPoints(healthBar)
    indicator:Hide()

    indicator.borderTop = indicator:CreateTexture(nil, "OVERLAY")
    indicator.borderTop:SetHeight(2)
    indicator.borderTop:SetPoint("TOPLEFT", indicator, "TOPLEFT", -3, 3)
    indicator.borderTop:SetPoint("TOPRIGHT", indicator, "TOPRIGHT", 3, 3)

    indicator.borderBottom = indicator:CreateTexture(nil, "OVERLAY")
    indicator.borderBottom:SetHeight(2)
    indicator.borderBottom:SetPoint("BOTTOMLEFT", indicator, "BOTTOMLEFT", -3, -3)
    indicator.borderBottom:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 3, -3)

    indicator.borderLeft = indicator:CreateTexture(nil, "OVERLAY")
    indicator.borderLeft:SetWidth(2)
    indicator.borderLeft:SetPoint("TOPLEFT", indicator, "TOPLEFT", -3, 3)
    indicator.borderLeft:SetPoint("BOTTOMLEFT", indicator, "BOTTOMLEFT", -3, -3)

    indicator.borderRight = indicator:CreateTexture(nil, "OVERLAY")
    indicator.borderRight:SetWidth(2)
    indicator.borderRight:SetPoint("TOPRIGHT", indicator, "TOPRIGHT", 3, 3)
    indicator.borderRight:SetPoint("BOTTOMRIGHT", indicator, "BOTTOMRIGHT", 3, -3)

    indicator.text = indicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    indicator.text:SetPoint("CENTER", indicator, "CENTER", 0, 0)
    indicator.text:SetJustifyH("CENTER")
    indicator.text:SetJustifyV("MIDDLE")

    nameplate.SunderIndicator = indicator
    return indicator
end

local function SetIndicatorVisual(indicator, stacks)
    if stacks <= 0 then
        indicator:Hide()
        return
    end

    local r, g, b = 1, 0.82, 0.1
    local text = tostring(stacks)

    if stacks >= 5 then
        r, g, b = 0.2, 1, 0.2
        text = text .. " MAX"
    end

    indicator.borderTop:SetColorTexture(r, g, b, 0.95)
    indicator.borderBottom:SetColorTexture(r, g, b, 0.95)
    indicator.borderLeft:SetColorTexture(r, g, b, 0.95)
    indicator.borderRight:SetColorTexture(r, g, b, 0.95)

    indicator.text:SetText(text)
    indicator.text:SetTextColor(r, g, b, 1)
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
