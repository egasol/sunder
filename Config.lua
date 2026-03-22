-- Sunder - Static configuration constants
-- Edit these values to tweak the look and feel of the addon.
-- Changes here require a /reload to take effect.

-- Spell - all ranks of Sunder Armor
SUNDER_SPELL_ID_RANK1   = 7386
SUNDER_SPELL_ID_RANK2   = 7405
SUNDER_SPELL_ID_RANK3   = 8380
SUNDER_SPELL_ID_RANK4   = 11596
SUNDER_SPELL_ID_RANK5   = 11597
SUNDER_SPELL_ID         = SUNDER_SPELL_ID_RANK1  -- Used for name/icon lookup
SUNDER_MAX_STACKS       = 5      -- Maximum number of Sunder Armor stacks
SUNDER_DEBUFF_SCAN_MAX  = 40     -- How many debuff slots to scan per unit

-- Icon layout
SUNDER_FRAME_LEVEL_OFFSET   = 15    -- Frame level above the nameplate health bar
SUNDER_ICON_ANCHOR_X        = -1    -- Horizontal offset from health bar bottom-left
SUNDER_ICON_ANCHOR_Y        = -3    -- Vertical offset from health bar bottom-left
SUNDER_ICON_BORDER_PAD      = 2     -- Px added to icon size for the dark border frame
SUNDER_ICON_BORDER_INSET    = 1     -- Px the icon sits inside its border (top-left)
SUNDER_ICON_TEXCOORD        = { 0.07, 0.93, 0.07, 0.93 }  -- Edge crop, WoW debuff style

-- Pip layout
SUNDER_PIP_SIZE         = 5    -- Width and base height of each stack pip square
SUNDER_PIP_GAP          = 3    -- Gap between pips

-- Colors (R, G, B components, 0-1)
-- Building stacks (amber)
SUNDER_COLOR_BUILD_R    = 1.00
SUNDER_COLOR_BUILD_G    = 0.65
SUNDER_COLOR_BUILD_B    = 0.00
-- Max stacks (cyan-blue)
SUNDER_COLOR_MAX_R      = 0.20
SUNDER_COLOR_MAX_G      = 0.80
SUNDER_COLOR_MAX_B      = 0.50

-- Icon tint when at max stacks (steady, non-pulsing)
SUNDER_ICON_MAX_TINT_R  = 0.45
SUNDER_ICON_MAX_TINT_G  = 0.95
SUNDER_ICON_MAX_TINT_B  = 0.45

-- Derived color factors
SUNDER_BORDER_DARKEN    = 0.55  -- Border is this fraction of the stack color
SUNDER_PIP_LIT_ALPHA    = 0.92  -- Alpha for active (lit) pips
SUNDER_PIP_DIM_R        = 0.15  -- Inactive pip red
SUNDER_PIP_DIM_G        = 0.15  -- Inactive pip green
SUNDER_PIP_DIM_B        = 0.15  -- Inactive pip blue
SUNDER_PIP_DIM_ALPHA    = 0.70  -- Inactive pip alpha

-- Counter badge
SUNDER_COUNT_OFFSET_X   = 2    -- X offset of the count text from icon bottom-right
SUNDER_COUNT_OFFSET_Y   = -1   -- Y offset of the count text from icon bottom-right
SUNDER_COUNT_MAX_TINT   = 0.30  -- R/B tint on count text when at max stacks
SUNDER_SHADOW_OFFSET_X  = 1
SUNDER_SHADOW_OFFSET_Y  = -1

-- Options panel
SUNDER_OPTIONS_WIDTH    = 320
SUNDER_OPTIONS_HEIGHT   = 280
SUNDER_OPTIONS_BG_R     = 0.10
SUNDER_OPTIONS_BG_G     = 0.10
SUNDER_OPTIONS_BG_B     = 0.10
SUNDER_OPTIONS_BG_A     = 0.90
SUNDER_OPTIONS_BORDER_R = 0.30
SUNDER_OPTIONS_BORDER_G = 0.30
SUNDER_OPTIONS_BORDER_B = 0.30
SUNDER_SLIDER_WIDTH     = 270
SUNDER_ICON_SIZE_MIN    = 16
SUNDER_ICON_SIZE_MAX    = 32
