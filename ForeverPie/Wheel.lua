local _, ns = ...
local L = ns.L

-- Layout numbers mirror Blizzard_Gamepad/UI/Radials/GamepadRadial so the wheel lines up
-- with the native art (gamepad-radial-menu-* atlases).
local SEGMENT_ANGLE = 360 / ns.SEGMENT_COUNT
local HIGHLIGHT_DISTANCE = 150
local HIGHLIGHT_ROTATION_CORRECTION = 270
local SEGMENT_DISTANCE_STRAIGHT = 150
local SEGMENT_DISTANCE_DIAGONAL = 158
local SEGMENT_TEXT_WIDTH = 104
local LINE_GAP = 3
local AIM_THRESHOLD_SQ = 0.25
-- The stick counts as let go below this deflection (squared), which sends the aimed phrase.
local RELEASE_THRESHOLD_SQ = 0.04
local MOUSE_AIM_RADIUS = 45

-- Top to bottom inside a segment: LB phrase, plain phrase, RB phrase.
-- The same order is the page order of the header dots: LB pages left, RB pages right.
local LINE_ORDER = { ns.VARIANT_LB, ns.VARIANT_MAIN, ns.VARIANT_RB }
local VARIANT_KEY = { [ns.VARIANT_LB] = "PADLSHOULDER", [ns.VARIANT_RB] = "PADRSHOULDER" }
local PAGE_STEP = { PADLSHOULDER = -1, PADRSHOULDER = 1 }
-- The triggers step through the wheels: LT up the column of dots, RT down.
local WHEEL_STEP = { PADLTRIGGER = -1, PADRTRIGGER = 1 }
local MAIN_PAGE = 2
local DOT_SIZE, DOT_GAP = 15, 5
-- The column of wheel dots sits this far left of the wheel art.
local WHEEL_BAR_OFFSET = 30
local KEY_FALLBACK_TEXT = {
	PADLSHOULDER = "LB", PADRSHOULDER = "RB", PAD2 = "B",
	PADLTRIGGER = "LT", PADRTRIGGER = "RT",
	PADBACK = "Select", PADFORWARD = "Start", PADSOCIAL = "Share",
	PADLSTICK = "L3", PADRSTICK = "R3",
}

local wheel
local aim = 0
local sticky = false
local page = MAIN_PAGE
local passesInput = false
local shownAt = 0
local cancelled = false
-- Triggers currently held, so one pull switches one wheel however it was detected.
local triggerHeld = {}
local triggerEvents = {}

local function HasAtlas(atlas)
	return C_Texture.GetAtlasInfo(atlas) ~= nil
end
ns.HasAtlas = HasAtlas

local function PlayRadialSound(name)
	local kit = SOUNDKIT and SOUNDKIT[name]
	if kit then
		PlaySound(kit)
	end
end

-- Inline icon for a gamepad key, taken from the game's active icon set (Xbox, PlayStation, Switch...).
local function KeyIcon(key, size)
	local util = InputIconTextureSetUtility
	if util and util.GetActiveInputIconButtonTextures and InputIconTextureState then
		local ok, textures = pcall(util.GetActiveInputIconButtonTextures, key)
		local atlas = ok and type(textures) == "table" and textures[InputIconTextureState.Normal]
		if type(atlas) == "string" and HasAtlas(atlas) then
			return ("|A:%s:%d:%d|a"):format(atlas, size, size)
		end
	end
	return "|cffffffff[" .. (KEY_FALLBACK_TEXT[key] or key) .. "]|r"
end
ns.KeyIcon = KeyIcon

local function GetVariant()
	return LINE_ORDER[page]
end

------------------------------------------------------------
-- Construction
------------------------------------------------------------

local function CreatePrompt(parent, key)
	local ok, prompt = pcall(CreateFrame, "Frame", nil, parent, "InputIconTextureFrameTemplate")
	if ok and prompt and prompt.SetInputKey then
		prompt:SetSize(26, 26)
		prompt:SetInputKey(key)
		return prompt
	end
	-- Template missing: plain text stands in for the button icon.
	prompt = CreateFrame("Frame", nil, parent)
	prompt:SetSize(26, 26)
	local text = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("CENTER")
	text:SetText(KEY_FALLBACK_TEXT[key] or key)
	return prompt
end

local function CreateSegment(parent, background, index)
	local segment = CreateFrame("Frame", nil, parent)
	segment:SetSize(SEGMENT_TEXT_WIDTH, 100)
	local radians = math.rad((index - 1) * SEGMENT_ANGLE)
	local distance = (index % 2 == 0) and SEGMENT_DISTANCE_DIAGONAL or SEGMENT_DISTANCE_STRAIGHT
	segment:SetPoint("CENTER", background, "CENTER", distance * math.cos(radians), distance * math.sin(radians))

	segment.lines = {}
	for variant = 1, 3 do
		local line = segment:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		line:SetWidth(SEGMENT_TEXT_WIDTH)
		line:SetJustifyH("CENTER")
		segment.lines[variant] = line
	end
	return segment
end

local function CreateWheel()
	local frame = CreateFrame("Frame", "ForeverPieWheel", UIParent)
	frame:SetSize(400, 590)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:Hide()

	local background = frame:CreateTexture(nil, "OVERLAY", nil, -3)
	background:SetPoint("CENTER", 0, 10)
	if HasAtlas("gamepad-radial-menu-wheelbg") then
		background:SetAtlas("gamepad-radial-menu-wheelbg", true)
	else
		background:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		background:SetVertexColor(0, 0, 0, 0.8)
		background:SetSize(480, 480)
	end
	frame.Background = background

	local highlight = frame:CreateTexture(nil, "OVERLAY", nil, -2)
	if HasAtlas("gamepad-radial-menu-selected") then
		highlight:SetAtlas("gamepad-radial-menu-selected", true)
		highlight.rotates = true
	else
		highlight:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		highlight:SetVertexColor(1, 0.82, 0, 0.25)
		highlight:SetSize(120, 120)
	end
	highlight:Hide()
	frame.SegmentHighlight = highlight

	-- Header with the bumper indicator, laid out like the native "Main Menu" page bar.
	local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	header:SetPoint("BOTTOM", frame, "TOP", 0, 25)
	header:SetTextColor(1, 1, 1)
	header:SetText(L["Quick Chat"])
	frame.HeaderText = header

	local topBar = frame:CreateTexture(nil, "OVERLAY", nil, -2)
	topBar:SetPoint("TOP", header, "BOTTOM", 0, 4)
	if HasAtlas("gamepad-radial-menu-toptext") then
		topBar:SetAtlas("gamepad-radial-menu-toptext", true)
	else
		topBar:SetColorTexture(0, 0, 0, 0.6)
		topBar:SetSize(380, 56)
	end

	frame.dots = {}
	local function CreateDot(variant)
		local dot = frame:CreateTexture(nil, "OVERLAY")
		dot:SetSize(15, 15)
		frame.dots[variant] = dot
		return dot
	end
	local centerDot = CreateDot(ns.VARIANT_MAIN)
	centerDot:SetPoint("TOP", header, "BOTTOM", 0, -24)
	local leftDot = CreateDot(ns.VARIANT_LB)
	leftDot:SetPoint("RIGHT", centerDot, "LEFT", -5, 0)
	local rightDot = CreateDot(ns.VARIANT_RB)
	rightDot:SetPoint("LEFT", centerDot, "RIGHT", 5, 0)

	frame.prompts = {}
	frame.prompts[ns.VARIANT_LB] = CreatePrompt(frame, "PADLSHOULDER")
	frame.prompts[ns.VARIANT_LB]:SetPoint("RIGHT", leftDot, "LEFT", -3, -2)
	frame.prompts[ns.VARIANT_RB] = CreatePrompt(frame, "PADRSHOULDER")
	frame.prompts[ns.VARIANT_RB]:SetPoint("LEFT", rightDot, "RIGHT", 3, -2)

	-- Wheel switcher: the same indicator turned upright on the left, LT above the dots and RT
	-- below. One dot per wheel; only laid out when there is more than one wheel.
	local wheelBar = frame:CreateTexture(nil, "OVERLAY", nil, -2)
	wheelBar:SetPoint("CENTER", background, "LEFT", -WHEEL_BAR_OFFSET, 0)
	if HasAtlas("gamepad-radial-menu-toptext") then
		wheelBar:SetAtlas("gamepad-radial-menu-toptext", true)
		wheelBar:SetRotation(math.rad(90))
	else
		wheelBar:SetColorTexture(0, 0, 0, 0.6)
		wheelBar:SetSize(56, 300)
	end
	frame.WheelBar = wheelBar

	frame.wheelDots = {}
	for index = 1, ns.MAX_WHEELS do
		-- Buttons, so the mouse test mode can switch wheels with a click.
		local dot = CreateFrame("Button", nil, frame)
		dot:SetSize(DOT_SIZE, DOT_SIZE)
		dot.Art = dot:CreateTexture(nil, "OVERLAY")
		dot.Art:SetAllPoints()
		dot:SetScript("OnClick", function()
			ns.SelectWheel(index)
		end)
		frame.wheelDots[index] = dot
	end
	frame.wheelPrompts = {
		CreatePrompt(frame, "PADLTRIGGER"),
		CreatePrompt(frame, "PADRTRIGGER"),
	}

	-- Footer bar: button hints and the chat channel of the aimed phrase.
	local bottomBar = frame:CreateTexture(nil, "OVERLAY", nil, -1)
	bottomBar:SetPoint("CENTER", frame, "BOTTOM", 0, -5)
	if HasAtlas("gamepad-radial-menu-bottomtext") then
		bottomBar:SetAtlas("gamepad-radial-menu-bottomtext", true)
	else
		bottomBar:SetColorTexture(0, 0, 0, 0.6)
		bottomBar:SetSize(380, 70)
	end

	local hints = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	hints:SetPoint("CENTER", bottomBar, "CENTER", 0, 12)
	frame.Hints = hints

	local channel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	channel:SetPoint("CENTER", bottomBar, "CENTER", 0, -12)
	frame.Channel = channel

	-- Hub: full text of the aimed phrase.
	local hub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hub:SetPoint("CENTER", background, "CENTER")
	hub:SetWidth(96)
	hub:SetJustifyH("CENTER")
	hub:SetWordWrap(true)
	hub:SetMaxLines(5)
	frame.Hub = hub

	frame.segments = {}
	for index = 1, ns.SEGMENT_COUNT do
		frame.segments[index] = CreateSegment(frame, background, index)
	end

	return frame
end

------------------------------------------------------------
-- Refresh
------------------------------------------------------------

local function RefreshSegment(segment, index, variant)
	local isAimed = index == aim
	local totalHeight, shown = 0, 0

	for _, lineVariant in ipairs(LINE_ORDER) do
		local line = segment.lines[lineVariant]
		local label, count = ns.GetPhraseLabel(index, lineVariant)
		if count > 1 then
			-- Random group marker: how many messages the slot picks from.
			label = label .. " |cff8fd6ff(" .. count .. ")|r"
		end
		if count == 0 then
			line:Hide()
		else
			local isSelected = lineVariant == variant
			local key = VARIANT_KEY[lineVariant]

			-- The phrase the held bumper selects is drawn large; the other two stay small and dim.
			if isSelected then
				line:SetFontObject(GameFontNormalMed3 or GameFontNormalLarge)
				line:SetWordWrap(true)
				line:SetMaxLines(2)
				if isAimed then
					line:SetTextColor(1, 1, 1)
				else
					line:SetTextColor(1, 0.82, 0)
				end
				line:SetAlpha(1)
			else
				line:SetFontObject(GameFontNormalSmall)
				line:SetWordWrap(false)
				line:SetMaxLines(1)
				line:SetTextColor(0.72, 0.72, 0.72)
				line:SetAlpha(0.8)
			end

			if key then
				label = KeyIcon(key, isSelected and 20 or 15) .. "  " .. label
			end
			line:SetText(label)
			line:Show()

			totalHeight = totalHeight + line:GetStringHeight()
			shown = shown + 1
		end
	end

	if shown == 0 then
		segment:Hide()
		return
	end
	segment:Show()

	local y = (totalHeight + LINE_GAP * (shown - 1)) / 2
	for _, lineVariant in ipairs(LINE_ORDER) do
		local line = segment.lines[lineVariant]
		if line:IsShown() then
			line:ClearAllPoints()
			line:SetPoint("TOP", segment, "CENTER", 0, y)
			y = y - line:GetStringHeight() - LINE_GAP
		end
	end
end

local function RefreshHighlight()
	local highlight = wheel.SegmentHighlight
	if aim == 0 then
		highlight:Hide()
		return
	end
	local degrees = (aim - 1) * SEGMENT_ANGLE
	highlight:ClearAllPoints()
	highlight:SetPoint("CENTER", wheel.Background, "CENTER",
		HIGHLIGHT_DISTANCE * math.cos(math.rad(degrees)),
		HIGHLIGHT_DISTANCE * math.sin(math.rad(degrees)))
	if highlight.rotates then
		highlight:SetRotation(math.rad(degrees - HIGHLIGHT_ROTATION_CORRECTION))
	end
	highlight:Show()
end

local function RefreshFooter(variant)
	-- Sending is "point the stick and let it go"; the mouse test mode sends on click.
	local sendHint = "|cffffffff" .. (sticky and L["Click"] or L["Release the stick"]) .. "|r"
	wheel.Hints:SetText(("%s - %s     %s %s"):format(sendHint, L["Send"], KeyIcon("PAD2", 20), L["Cancel"]))

	if aim == 0 then
		wheel.Hub:SetText(L["Aim with the stick"])
		wheel.Hub:SetTextColor(0.6, 0.6, 0.6)
		wheel.Channel:SetText("")
		return
	end

	local text, channel, count = ns.ResolvePhrase(aim, variant)
	if text and count > 1 then
		text = ns.GetPhraseLabel(aim, variant) .. "\n|cff8fd6ff" .. L["Random: %d phrases"]:format(count) .. "|r"
	end
	if not text then
		wheel.Hub:SetText(L["(empty)"])
		wheel.Hub:SetTextColor(0.6, 0.6, 0.6)
		wheel.Channel:SetText("")
		return
	end

	wheel.Hub:SetText(text)
	wheel.Hub:SetTextColor(1, 1, 1)
	if channel == "COMMAND" then
		wheel.Channel:SetText(ns.CHANNEL_NAMES.COMMAND)
	else
		wheel.Channel:SetText(L["To: %s"]:format(ns.CHANNEL_NAMES[channel] or channel))
	end
	local color = ChatTypeInfo and ChatTypeInfo[channel]
	if color then
		wheel.Channel:SetTextColor(color.r, color.g, color.b)
	else
		wheel.Channel:SetTextColor(1, 1, 1)
	end
end

local function SetDotActive(texture, isActive)
	if HasAtlas("gamepad-radialgamemenu-cursorbg-neutral") then
		texture:SetAtlas("gamepad-radialgamemenu-cursorbg-" .. (isActive and "neutral" or "inactive"))
	else
		texture:SetColorTexture(1, 0.82, 0, isActive and 1 or 0.25)
	end
end

-- Lays the wheel dots out as a column centered on the wheel, first wheel on top.
local function RefreshWheelBar()
	local count = ns.GetWheelCount()
	local visible = count > 1
	wheel.WheelBar:SetShown(visible)
	for _, prompt in ipairs(wheel.wheelPrompts) do
		prompt:SetShown(visible)
	end

	local step = DOT_SIZE + DOT_GAP
	local top = (count - 1) * step / 2
	for index, dot in ipairs(wheel.wheelDots) do
		dot:SetShown(visible and index <= count)
		if dot:IsShown() then
			dot:ClearAllPoints()
			dot:SetPoint("CENTER", wheel.Background, "LEFT", -WHEEL_BAR_OFFSET, top - (index - 1) * step)
			dot:EnableMouse(sticky)
			SetDotActive(dot.Art, index == ns.db.wheel)
		end
	end
	if visible then
		wheel.wheelPrompts[1]:ClearAllPoints()
		wheel.wheelPrompts[1]:SetPoint("BOTTOM", wheel.wheelDots[1], "TOP", 0, 3)
		wheel.wheelPrompts[2]:ClearAllPoints()
		wheel.wheelPrompts[2]:SetPoint("TOP", wheel.wheelDots[count], "BOTTOM", 0, -3)
	end
end

local function Refresh()
	if not wheel or not wheel:IsShown() then
		return
	end
	local variant = GetVariant()
	wheel:SetScale(ns.db.scale)
	wheel.HeaderText:SetText(ns.GetWheelTitle())

	for index, segment in ipairs(wheel.segments) do
		RefreshSegment(segment, index, variant)
	end

	for dotVariant, dot in pairs(wheel.dots) do
		SetDotActive(dot, dotVariant == variant)
	end
	for promptVariant, prompt in pairs(wheel.prompts) do
		prompt:SetAlpha(promptVariant == variant and 1 or 0.55)
	end
	RefreshWheelBar()

	RefreshHighlight()
	RefreshFooter(variant)
end
ns.RefreshWheel = Refresh

------------------------------------------------------------
-- Input
------------------------------------------------------------

local function SetAim(index)
	if index == aim then
		return
	end
	aim = index
	if index ~= 0 then
		PlayRadialSound("GAMEPAD_RADIAL_MENU_HIGHLIGHT")
	end
	Refresh()
end

local function AimFromVector(x, y, thresholdSq)
	if x * x + y * y <= thresholdSq then
		return
	end
	local degrees = math.deg(math.atan2(y, x))
	if degrees < -SEGMENT_ANGLE / 2 then
		degrees = degrees + 360
	end
	local index = math.floor((degrees + SEGMENT_ANGLE) / SEGMENT_ANGLE + 0.5)
	if index > ns.SEGMENT_COUNT then
		index = 1
	end
	SetAim(index)
end

-- LB and RB page through the three phrase sets with single presses, like the tabs of the
-- game's own menu wheel, wrapping around at the ends. Nothing has to be held.
local function TurnPage(step)
	page = (page + step - 1) % #LINE_ORDER + 1
	PlayRadialSound("GAMEPAD_RADIAL_MENU_TAB_OVER")
	Refresh()
end

-- LT and RT step through the wheels the same way, wrapping around. Unlike the page, the wheel
-- is remembered: the one picked here is the one that opens next time.
function ns.SelectWheel(index)
	if index ~= ns.db.wheel and ns.GetWheel(index) then
		PlayRadialSound("GAMEPAD_RADIAL_MENU_TAB_OVER")
		ns.SetCurrentWheel(index)
	end
end

local function PullTrigger(button)
	if triggerHeld[button] then
		return
	end
	triggerHeld[button] = true
	local count = ns.GetWheelCount()
	if count > 1 then
		ns.SelectWheel((ns.db.wheel + WHEEL_STEP[button] - 1) % count + 1)
	end
end

local function Confirm()
	if aim ~= 0 then
		ns.SendPhrase(aim, GetVariant())
	end
	wheel:Hide()
end

-- Same rules as the game's menu wheel: push the stick past the threshold to pick a segment,
-- let it spring back to send it. After a cancel nothing is picked until the stick recenters.
local function HandleStick(x, y)
	local lengthSq = x * x + y * y
	if cancelled then
		if lengthSq > RELEASE_THRESHOLD_SQ then
			return
		end
		cancelled = false
	end
	if lengthSq < RELEASE_THRESHOLD_SQ and aim ~= 0 then
		Confirm()
	else
		AimFromVector(x, y, AIM_THRESHOLD_SQ)
	end
end


-- Only the wheel's own buttons are kept from the game; everything else (abilities, jump...)
-- keeps working while the wheel is open. Releases always pass, so the game never sees a
-- button as stuck. In combat nothing can be swallowed: there the wheel's buttons also do
-- their normal game action.
local function IsWheelButton(button)
	return PAGE_STEP[button] or WHEEL_STEP[button] or button == "PAD2" or button == ns.OPEN_KEY
end

local function OnGamePadButtonDown(_, button)
	if button == ns.OPEN_KEY and shownAt == GetTime() then
		-- The very press that opened the wheel.
		return
	end
	local used = IsWheelButton(button)
	if passesInput and ns.SetSwallow(wheel, used) and used then
		C_Timer.After(0, function()
			ns.SetSwallow(wheel, false)
		end)
	end

	if PAGE_STEP[button] then
		TurnPage(PAGE_STEP[button])
	elseif WHEEL_STEP[button] then
		triggerEvents[button] = true
		PullTrigger(button)
	elseif button == "PAD2" then
		wheel:Hide()
	elseif used then
		-- The open button again: drops the current pick like the stick click does in the
		-- game's menu, or closes the wheel when nothing is picked.
		if aim ~= 0 then
			cancelled = true
			SetAim(0)
		else
			wheel:Hide()
		end
	end
end

-- The aiming stick is taken from the game (so the camera stays put), the other one is passed on
-- (so the character keeps walking). The return value alone isn't honored for addon frames, so
-- the frame is switched between swallowing and passing for every stick event. That switch is
-- blocked in combat, where both sticks pass: aiming works, but the camera turns as well.
local function OnGamePadStick(self, stick, x, y)
	local aiming = stick == ns.AIM_STICK
	ns.SetSwallow(self, aiming)
	if aiming then
		HandleStick(x, y)
	end
	return not aiming
end

local function OnGamePadButtonUp(_, button)
	triggerHeld[button] = nil
end

local function OnUpdate()
	-- Triggers set up as modifiers may not arrive as button presses, so until a press event
	-- has been seen for a trigger its state is read from the device instead.
	for button in pairs(WHEEL_STEP) do
		if not triggerEvents[button] then
			local down = ns.IsPadButtonDown(button)
			if down == true then
				PullTrigger(button)
			elseif down == false then
				triggerHeld[button] = nil
			end
		end
	end

	if sticky then
		-- Mouse test mode: the cursor direction from the hub aims the wheel.
		local cursorX, cursorY = GetCursorPosition()
		local scale = wheel:GetEffectiveScale()
		local centerX, centerY = wheel.Background:GetCenter()
		if centerX then
			AimFromVector(cursorX / scale - centerX, cursorY / scale - centerY, MOUSE_AIM_RADIUS * MOUSE_AIM_RADIUS)
		end
	end
end

local function OnMouseUp(_, button)
	if not sticky then
		return
	end
	if button == "LeftButton" then
		Confirm()
	else
		wheel:Hide()
	end
end

local function OnMouseWheel(_, delta)
	if sticky then
		TurnPage(-delta)
	end
end

local function OnKeyDown(_, key)
	-- Mouse test mode only: Escape closes the wheel instead of reaching the game.
	if passesInput then
		ns.SetSwallow(wheel, key == "ESCAPE")
	end
	if key == "ESCAPE" then
		wheel:Hide()
	end
end

------------------------------------------------------------
-- Show / hide
------------------------------------------------------------

function ns.IsWheelShown()
	return wheel ~= nil and wheel:IsShown()
end

function ns.HideWheel()
	if wheel then
		wheel:Hide()
	end
end

-- Builds the wheel ahead of time (at login and after combat): its input pass-through can only
-- be set up out of combat.
function ns.PrepareWheel()
	if not wheel then
		wheel = CreateWheel()
		wheel:EnableGamePadButton(true)
		wheel:SetScript("OnGamePadButtonDown", OnGamePadButtonDown)
		wheel:SetScript("OnGamePadButtonUp", OnGamePadButtonUp)
		wheel:SetScript("OnUpdate", OnUpdate)
		wheel:SetScript("OnMouseUp", OnMouseUp)
		wheel:SetScript("OnMouseWheel", OnMouseWheel)
		wheel:SetScript("OnKeyDown", OnKeyDown)
		wheel:SetScript("OnHide", function()
			ns.wheelHiddenAt = GetTime()
			PlayRadialSound("GAMEPAD_RADIAL_MENU_CLOSE")
		end)
		-- The stick gets its own frame so its swallow / pass switching doesn't fight with the
		-- wheel's own, which is driven by button presses.
		wheel.StickCatcher = CreateFrame("Frame", nil, wheel)
		wheel.StickCatcher:SetScript("OnGamePadStick", OnGamePadStick)
	end
	if not passesInput then
		passesInput = ns.SetSwallow(wheel, false)
		-- The stick frame only starts listening once it is known to pass input on, so it can
		-- never be left swallowing the movement stick.
		if ns.SetSwallow(wheel.StickCatcher, false) then
			wheel.StickCatcher:EnableGamePadStick(true)
		end
	end
end

-- The wheel stays open until a phrase is sent or it is cancelled, like the game's own menu wheel.
-- stickyMode (used by /fpie toggle and the settings preview) adds mouse control: move to aim,
-- scroll to switch phrase, click a dot on the left to switch wheel, click to send.
-- It opens on the wheel that was shown last.
-- Returns true when the wheel was opened.
function ns.ShowWheel(stickyMode)
	if not ns.db then
		return false
	end
	-- Don't stack on top of the native main menu wheel.
	if GamepadRadial and GamepadRadial:IsShown() then
		return false
	end

	ns.PrepareWheel()

	sticky = stickyMode and true or false
	page = MAIN_PAGE
	aim = 0

	cancelled = false
	shownAt = GetTime()
	-- A trigger that is already held (as an action bar modifier, say) must not switch the wheel.
	for button in pairs(WHEEL_STEP) do
		triggerHeld[button] = ns.IsPadButtonDown(button) == true or nil
	end

	wheel:EnableMouse(sticky)
	wheel:EnableMouseWheel(sticky)
	wheel:EnableKeyboard(sticky)
	wheel:Show()
	PlayRadialSound("GAMEPAD_RADIAL_MENU_OPEN")
	Refresh()
	return true
end
