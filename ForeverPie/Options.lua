local _, ns = ...
local L = ns.L

-- Everything on these pages is the addon's own: the selectors, the slider and the confirmation
-- window are built here instead of using the game's dropdown menus, StaticPopup and settings
-- controls. Those are shared with the game's own UI, and addon values passing through them left
-- taint behind that later surfaced as "ForeverPie has been blocked from an action only available
-- to the Blizzard UI". The pages are registered as plain canvases and touch nothing shared.

-- Editor order: clockwise from the top, the way the wheel is read.
-- Name tables resolve through L on every read.
local function LocalizedNames(keys)
	return setmetatable({}, { __index = function(_, index)
		return L[keys[index]]
	end })
end
local DIRECTION_NAMES = LocalizedNames({
	[3] = "Up", [2] = "Up-Right", [1] = "Right", [8] = "Down-Right",
	[7] = "Down", [6] = "Down-Left", [5] = "Left", [4] = "Up-Left",
})
local VARIANT_NAMES = LocalizedNames({
	[ns.VARIANT_MAIN] = "Main page",
	[ns.VARIANT_LB] = "LB page",
	[ns.VARIANT_RB] = "RB page",
})

local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0

local mainCategory

------------------------------------------------------------
-- Widgets
------------------------------------------------------------

local function CreatePanelButton(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function CreateCaption(panel, text, anchor, offsetY)
	local caption = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	caption:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
	caption:SetText(text)
	return caption
end

local function SetTooltip(frame, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

-- Dark box with a thin border, shared by the selectors and the windows.
local function AddBox(frame, alpha)
	local border = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0.6, 0.5, 0.25, 1)
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.05, 0.05, 0.05, alpha)
end

-- One option list shared by every selector. A screen-sized button under it closes the list on a
-- click anywhere else.
local SELECTOR_ROW_HEIGHT = 20
local selectorList

local function GetSelectorList()
	if selectorList then
		return selectorList
	end
	local dismiss = CreateFrame("Button", nil, UIParent)
	dismiss:SetFrameStrata("FULLSCREEN_DIALOG")
	dismiss:SetAllPoints(UIParent)
	dismiss:RegisterForClicks("AnyUp")
	dismiss:Hide()
	dismiss:SetScript("OnClick", function(self)
		self:Hide()
	end)

	local list = CreateFrame("Frame", nil, dismiss)
	list:EnableMouse(true)
	AddBox(list, 0.97)
	list.rows = {}
	list.dismiss = dismiss
	selectorList = list
	return list
end

local function GetSelectorRow(list, index)
	local row = list.rows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, list)
	row:SetHeight(SELECTOR_ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 2, -2 - (index - 1) * SELECTOR_ROW_HEIGHT)
	row:SetPoint("TOPRIGHT", -2, -2 - (index - 1) * SELECTOR_ROW_HEIGHT)
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.14)
	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.Text:SetPoint("LEFT", 8, 0)
	row.Text:SetPoint("RIGHT", -8, 0)
	row.Text:SetJustifyH("LEFT")
	row.Text:SetWordWrap(false)
	row:SetScript("OnClick", function(self)
		list.dismiss:Hide()
		self.owner.setValue(self.value)
		self.owner:Refresh()
	end)
	list.rows[index] = row
	return row
end

-- A dropdown: shows the current value, a click lists the options under it.
-- getOptions() returns { { value, text }, ... }; format (optional) wraps the shown text.
local function CreateSelector(parent, width, getOptions, getValue, setValue, format)
	local selector = CreateFrame("Button", nil, parent)
	selector:SetSize(width, 22)
	AddBox(selector, 0.8)
	selector.setValue = setValue

	local hover = selector:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.1)

	local arrow = selector:CreateTexture(nil, "OVERLAY")
	arrow:SetSize(12, 12)
	arrow:SetPoint("RIGHT", -5, 0)
	arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	arrow:SetRotation(-math.pi / 2)

	local text = selector:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", 8, 0)
	text:SetPoint("RIGHT", arrow, "LEFT", -4, 0)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)

	function selector:Refresh()
		local value = getValue()
		for _, option in ipairs(getOptions()) do
			if option[1] == value then
				text:SetText(format and format:format(option[2]) or option[2])
				return
			end
		end
		text:SetText("")
	end

	selector:SetScript("OnClick", function(self)
		local list = GetSelectorList()
		if list.dismiss:IsShown() and list.owner == self then
			list.dismiss:Hide()
			return
		end
		local options, value = getOptions(), getValue()
		for index, option in ipairs(options) do
			local row = GetSelectorRow(list, index)
			row.owner, row.value = self, option[1]
			row.Text:SetText(option[2])
			if option[1] == value then
				row.Text:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
			else
				row.Text:SetTextColor(1, 1, 1)
			end
			row:Show()
		end
		for index = #options + 1, #list.rows do
			list.rows[index]:Hide()
		end
		list.owner = self
		list:ClearAllPoints()
		list:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
		list:SetSize(math.max(width, 150), #options * SELECTOR_ROW_HEIGHT + 4)
		list.dismiss:Show()
	end)
	selector:SetScript("OnHide", function(self)
		if selectorList and selectorList.owner == self then
			selectorList.dismiss:Hide()
		end
	end)
	return selector
end

local function ChannelOptions(order)
	local options = {}
	for _, channel in ipairs(order) do
		table.insert(options, { channel, ns.CHANNEL_NAMES[channel] })
	end
	return options
end

-- Yes / No window for the actions that lose phrases.
local confirm

local function ShowConfirm(text, onAccept)
	if not confirm then
		confirm = CreateFrame("Frame", nil, UIParent)
		confirm:SetSize(380, 150)
		confirm:SetPoint("CENTER", 0, 80)
		confirm:SetFrameStrata("FULLSCREEN_DIALOG")
		confirm:EnableMouse(true)
		confirm:Hide()
		AddBox(confirm, 0.97)

		confirm.text = confirm:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		confirm.text:SetPoint("TOP", 0, -18)
		confirm.text:SetWidth(344)
		confirm.text:SetWordWrap(true)

		local no = CreatePanelButton(confirm, NO, 110, function()
			confirm:Hide()
		end)
		no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 5, 14)
		local yes = CreatePanelButton(confirm, YES, 110, function()
			confirm:Hide()
			confirm.onAccept()
		end)
		yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -5, 14)
	end
	confirm.text:SetText(text)
	confirm.onAccept = onAccept
	confirm:SetHeight(confirm.text:GetStringHeight() + 76)
	confirm:Show()
end

------------------------------------------------------------
-- General page
------------------------------------------------------------

local function CreateGeneralPanel()
	local panel = CreateFrame("Frame")
	panel:Hide()
	local TEXT_WIDTH = 560

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -22)
	title:SetText("Forever Pie")

	local controls = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	controls:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
	controls:SetWidth(TEXT_WIDTH)
	controls:SetJustifyH("LEFT")
	controls:SetWordWrap(true)
	controls:SetText(L["Hold RB and press R3 to open the wheel. LB and RB turn the page of phrases, LT and RT switch between the wheels: the wheel you used last opens next time."]
		.. "\n\n" .. L["Wheels and phrases are edited on the \"Phrases\" page."])

	local channelCaption = CreateCaption(panel, L["Default channel"], controls, -24)
	local channel = CreateSelector(panel, 240, function()
		return ChannelOptions(ns.CHANNEL_ORDER)
	end, function()
		return ns.db.channel
	end, function(value)
		ns.db.channel = value
		ns.RefreshWheel()
	end)
	channel:SetPoint("TOPLEFT", channelCaption, "BOTTOMLEFT", 0, -6)

	local channelHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	channelHelp:SetPoint("TOPLEFT", channel, "BOTTOMLEFT", 0, -8)
	channelHelp:SetWidth(TEXT_WIDTH)
	channelHelp:SetJustifyH("LEFT")
	channelHelp:SetWordWrap(true)
	channelHelp:SetText(L["Where phrases are sent. Auto: while you are in a group they go to the group chat (party, raid or instance), otherwise to Say.\n\nA phrase with its own type in the phrase editor (Yell, for example) always uses that type and ignores this setting."])

	local scaleCaption = CreateCaption(panel, L["Wheel scale"], channelHelp, -24)
	local slider = CreateFrame("Slider", nil, panel)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(240, 18)
	slider:SetPoint("TOPLEFT", scaleCaption, "BOTTOMLEFT", 0, -6)
	slider:EnableMouse(true)
	slider:SetMinMaxValues(0.7, 1.4)
	slider:SetValueStep(0.05)
	slider:SetObeyStepOnDrag(true)
	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(6)
	track:SetColorTexture(0, 0, 0, 0.7)
	local thumb = slider:CreateTexture(nil, "ARTWORK")
	thumb:SetSize(10, 18)
	thumb:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 1)
	slider:SetThumbTexture(thumb)

	local scaleText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	scaleText:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	slider:SetScript("OnValueChanged", function(_, value)
		-- Snapped here as well: dragging can report values between the steps.
		value = math.floor(value * 20 + 0.5) / 20
		ns.db.scale = value
		scaleText:SetText(("%d%%"):format(value * 100 + 0.5))
		ns.RefreshWheel()
	end)

	panel:SetScript("OnShow", function()
		channel:Refresh()
		slider:SetValue(ns.db.scale)
		scaleText:SetText(("%d%%"):format(ns.db.scale * 100 + 0.5))
	end)
	return panel
end

------------------------------------------------------------
-- Phrase editor: wheel tabs and a clickable copy of the wheel
------------------------------------------------------------

local PIE_SIZE = 380
local SLOT_WIDTH, SLOT_HEIGHT = 104, 21
-- Top to bottom inside a segment, same as on the real wheel.
local SLOT_ORDER = { ns.VARIANT_LB, ns.VARIANT_MAIN, ns.VARIANT_RB }
local SLOT_KEY = { [ns.VARIANT_LB] = "PADLSHOULDER", [ns.VARIANT_RB] = "PADRSHOULDER" }
local TAB_SIZE = 26

-- wheel is the wheel being edited, set is what "Reset wheel" and "+" fill a wheel with.
local editor = { wheel = 1, dir = 3, variant = ns.VARIANT_MAIN, slots = {}, tabs = {}, set = "AUTO" }

local function CurrentWheel()
	return ns.GetWheel(editor.wheel)
end

local function CurrentPhrase()
	return CurrentWheel().phrases[editor.dir][editor.variant]
end

local function RefreshSlots()
	for _, slot in ipairs(editor.slots) do
		local label, count = ns.GetPhraseLabel(slot.dir, slot.variant, editor.wheel)
		local phrase = ns.GetPhrase(slot.dir, slot.variant, editor.wheel)
		local key = SLOT_KEY[slot.variant]
		local prefix = key and (ns.KeyIcon(key, 16) .. "  ") or ""

		if count == 0 then
			slot.Text:SetText(prefix .. "+")
			slot.Text:SetTextColor(0.5, 0.5, 0.5)
		else
			if count > 1 then
				label = label .. " |cff8fd6ff(" .. count .. ")|r"
			end
			slot.Text:SetText(prefix .. label)
			-- A phrase with its own type is tinted in that chat color (yell is red and so on).
			local color = phrase.channel ~= "DEFAULT" and ChatTypeInfo and ChatTypeInfo[phrase.channel]
			if color then
				slot.Text:SetTextColor(color.r, color.g, color.b)
			else
				slot.Text:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
			end
		end
		slot.Selected:SetShown(slot.dir == editor.dir and slot.variant == editor.variant)
	end

	local highlight = editor.highlight
	local degrees = (editor.dir - 1) * 45
	highlight:ClearAllPoints()
	highlight:SetPoint("CENTER", editor.background, "CENTER", 150 * math.cos(math.rad(degrees)), 150 * math.sin(math.rad(degrees)))
	if highlight.rotates then
		highlight:SetRotation(math.rad(degrees - 270))
	end
	ns.RefreshWheel()
end

-- Loads the selected slot into the fields on the right.
local function LoadSlot()
	local phrase = CurrentPhrase()
	editor.title:SetText(DIRECTION_NAMES[editor.dir] .. " - " .. VARIANT_NAMES[editor.variant])
	editor.hub:SetText(DIRECTION_NAMES[editor.dir])
	editor.labelBox:SetText(phrase.label or "")
	editor.labelBox:SetCursorPosition(0)
	editor.textBox:SetText(phrase.text or "")
	editor.textBox:SetCursorPosition(0)
	editor.typeSelector:Refresh()
	RefreshSlots()
end

local function ClearFocus()
	editor.nameBox:ClearFocus()
	editor.labelBox:ClearFocus()
	editor.textBox:ClearFocus()
end

local function SelectSlot(dir, variant)
	ClearFocus()
	editor.dir, editor.variant = dir, variant
	LoadSlot()
end

-- Loads the wheel being edited: its tab, name and channel, then the selected slot.
local function LoadWheel()
	local count = ns.GetWheelCount()
	editor.wheel = math.min(math.max(editor.wheel, 1), count)

	for index, tab in ipairs(editor.tabs) do
		tab:SetShown(index <= count)
		local isSelected = index == editor.wheel
		tab.Selected:SetShown(isSelected)
		if isSelected then
			tab.Text:SetTextColor(1, 1, 1)
		else
			tab.Text:SetTextColor(GOLD_R, GOLD_G, GOLD_B)
		end
	end
	editor.addTab:SetShown(count < ns.MAX_WHEELS)
	editor.addTab:ClearAllPoints()
	editor.addTab:SetPoint("LEFT", editor.tabs[count], "RIGHT", 2, 0)
	editor.delete:SetEnabled(count > 1)

	local name = CurrentWheel().name
	editor.nameBox:SetText(name)
	editor.nameBox:SetCursorPosition(0)
	editor.nameBox.Placeholder:SetShown(name == "")
	editor.channelSelector:Refresh()
	editor.setSelector:Refresh()
	LoadSlot()
end

local function SelectWheel(index)
	ClearFocus()
	editor.wheel = index
	LoadWheel()
end

local function CreateSlotButton(parent, background, dir, variant, row)
	local slot = CreateFrame("Button", nil, parent)
	slot:SetSize(SLOT_WIDTH, SLOT_HEIGHT)
	local radians = math.rad((dir - 1) * 45)
	local distance = (dir % 2 == 0) and 158 or 150
	slot:SetPoint("CENTER", background, "CENTER",
		distance * math.cos(radians),
		distance * math.sin(radians) + (2 - row) * (SLOT_HEIGHT + 1))
	slot.dir, slot.variant = dir, variant

	slot.Selected = slot:CreateTexture(nil, "BACKGROUND")
	slot.Selected:SetAllPoints()
	slot.Selected:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 0.28)

	local hover = slot:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.14)

	slot.Text = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	slot.Text:SetPoint("CENTER")
	slot.Text:SetWidth(SLOT_WIDTH - 4)
	slot.Text:SetWordWrap(false)
	slot.Text:SetMaxLines(1)

	slot:SetScript("OnClick", function()
		SelectSlot(dir, variant)
	end)
	table.insert(editor.slots, slot)
end

local function CreatePie(panel)
	local holder = CreateFrame("Frame", nil, panel)
	holder:SetSize(PIE_SIZE, PIE_SIZE)

	-- The art keeps the native wheel's own coordinates and is scaled down as a whole to fit the panel.
	local art = CreateFrame("Frame", nil, holder)
	art:SetSize(10, 10)
	art:SetPoint("CENTER")

	local background = art:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("CENTER")
	if ns.HasAtlas("gamepad-radial-menu-wheelbg") then
		background:SetAtlas("gamepad-radial-menu-wheelbg", true)
	else
		background:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		background:SetVertexColor(0, 0, 0, 0.8)
		background:SetSize(480, 480)
	end
	editor.background = background

	local width = background:GetWidth()
	if not width or width < 100 then
		width = 480
	end
	art:SetScale(PIE_SIZE / width)

	local highlight = art:CreateTexture(nil, "BORDER")
	if ns.HasAtlas("gamepad-radial-menu-selected") then
		highlight:SetAtlas("gamepad-radial-menu-selected", true)
		highlight.rotates = true
	else
		highlight:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
		highlight:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 0.25)
		highlight:SetSize(120, 120)
	end
	editor.highlight = highlight

	editor.hub = art:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	editor.hub:SetPoint("CENTER", background, "CENTER")
	editor.hub:SetWidth(96)

	for dir = 1, ns.SEGMENT_COUNT do
		for row, variant in ipairs(SLOT_ORDER) do
			CreateSlotButton(art, background, dir, variant, row)
		end
	end
	return holder
end

local function CreateTab(panel, text, onClick)
	local tab = CreateFrame("Button", nil, panel)
	tab:SetSize(TAB_SIZE, 22)
	AddBox(tab, 0.8)

	tab.Selected = tab:CreateTexture(nil, "BORDER")
	tab.Selected:SetAllPoints()
	tab.Selected:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 0.4)
	tab.Selected:Hide()

	local hover = tab:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.14)

	tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tab.Text:SetPoint("CENTER")
	tab.Text:SetText(text)
	tab:SetScript("OnClick", onClick)
	return tab
end

-- Two rows above the pie: the wheel tabs, then the settings of the wheel being edited.
local TAB_ROW_Y, WHEEL_ROW_Y, PIE_Y = -48, -78, -106

local function CreateWheelControls(panel)
	for index = 1, ns.MAX_WHEELS do
		local tab = CreateTab(panel, index, function()
			SelectWheel(index)
		end)
		if index == 1 then
			tab:SetPoint("TOPLEFT", 7, TAB_ROW_Y)
		else
			tab:SetPoint("LEFT", editor.tabs[index - 1], "RIGHT", 2, 0)
		end
		editor.tabs[index] = tab
	end

	editor.addTab = CreateTab(panel, "+", function()
		local index = ns.AddWheel(editor.set)
		if index then
			SelectWheel(index)
		end
	end)
	SetTooltip(editor.addTab, L["Add a wheel (up to %d). It is filled with the set chosen below."]:format(ns.MAX_WHEELS))

	editor.delete = CreatePanelButton(panel, L["Delete wheel"], 130, function()
		local index = editor.wheel
		ShowConfirm(L["Delete wheel %d with all its phrases?"]:format(index), function()
			if ns.RemoveWheel(index) then
				LoadWheel()
			end
		end)
	end)
	editor.delete:SetPoint("TOPRIGHT", -36, TAB_ROW_Y)

	local nameBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	nameBox:SetSize(140, 22)
	nameBox:SetPoint("TOPLEFT", 13, WHEEL_ROW_Y)
	nameBox:SetAutoFocus(false)
	nameBox:SetMaxLetters(24)
	nameBox.Placeholder = nameBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	nameBox.Placeholder:SetPoint("LEFT", 2, 0)
	nameBox.Placeholder:SetText(L["Wheel name"])
	nameBox:SetScript("OnTextChanged", function(self, userInput)
		self.Placeholder:SetShown(self:GetText() == "")
		if userInput then
			CurrentWheel().name = self:GetText()
			ns.RefreshWheel()
		end
	end)
	nameBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
	nameBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
	nameBox:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Shown above the wheel. Leave it empty for \"Quick Chat\"."], 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	nameBox:HookScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	editor.nameBox = nameBox

	editor.channelSelector = CreateSelector(panel, 170, function()
		return ChannelOptions(ns.WHEEL_CHANNEL_ORDER)
	end, function()
		return CurrentWheel().channel
	end, function(value)
		CurrentWheel().channel = value
		ns.RefreshWheel()
	end, L["Channel: %s"])
	editor.channelSelector:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
	SetTooltip(editor.channelSelector, L["Where the phrases of this wheel go when a phrase has no type of its own. Default follows the general setting."])

	editor.setSelector = CreateSelector(panel, 140, function()
		local options = {}
		for _, set in ipairs(ns.GetPhraseSets()) do
			table.insert(options, { set, ns.GetPhraseSetName(set) })
		end
		return options
	end, function()
		return editor.set
	end, function(value)
		editor.set = value
	end)
	editor.setSelector:SetPoint("LEFT", editor.channelSelector, "RIGHT", 10, 0)
	SetTooltip(editor.setSelector, L["The set \"Reset wheel\" and the + button fill a wheel with."])

	local reset = CreatePanelButton(panel, L["Reset wheel"], 130, function()
		local index, set = editor.wheel, editor.set
		ShowConfirm(L["Replace all phrases of wheel %d with the set \"%s\"?\n\nIts current phrases will be lost. Export them first if you want to keep them."]:format(index, ns.GetPhraseSetName(set)), function()
			ns.ResetWheel(index, set)
			LoadWheel()
		end)
	end)
	reset:SetPoint("LEFT", editor.setSelector, "RIGHT", 8, 0)
end

local function CreateFields(panel, pie)
	local FIELD_WIDTH = 205

	editor.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	editor.title:SetPoint("TOPLEFT", pie, "TOPRIGHT", 18, -4)
	editor.title:SetWidth(FIELD_WIDTH)
	editor.title:SetJustifyH("LEFT")

	local labelCaption = CreateCaption(panel, L["Name on the wheel"], editor.title, -14)
	local labelBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	labelBox:SetSize(FIELD_WIDTH - 6, 22)
	labelBox:SetPoint("TOPLEFT", labelCaption, "BOTTOMLEFT", 6, -4)
	labelBox:SetAutoFocus(false)
	labelBox:SetMaxLetters(24)
	labelBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			CurrentPhrase().label = self:GetText()
			RefreshSlots()
		end
	end)
	labelBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
	labelBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
	editor.labelBox = labelBox

	-- Type: how the phrase is spoken (say, yell, party...). Default follows the wheel's channel.
	local typeCaption = CreateCaption(panel, L["Type"], labelCaption, -44)
	editor.typeSelector = CreateSelector(panel, FIELD_WIDTH, function()
		return ChannelOptions(ns.PHRASE_CHANNEL_ORDER)
	end, function()
		return CurrentPhrase().channel
	end, function(value)
		CurrentPhrase().channel = value
		RefreshSlots()
	end)
	editor.typeSelector:SetPoint("TOPLEFT", typeCaption, "BOTTOMLEFT", 0, -4)

	local textCaption = CreateCaption(panel, L["Messages"], typeCaption, -48)
	local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
	scroll:SetSize(FIELD_WIDTH - 22, 140)
	scroll:SetPoint("TOPLEFT", textCaption, "BOTTOMLEFT", 4, -8)

	local boxBackground = panel:CreateTexture(nil, "BACKGROUND")
	boxBackground:SetPoint("TOPLEFT", scroll, -5, 5)
	boxBackground:SetPoint("BOTTOMRIGHT", scroll, 5, -5)
	boxBackground:SetColorTexture(0, 0, 0, 0.45)

	local textBox = CreateFrame("EditBox", nil, scroll)
	textBox:SetMultiLine(true)
	textBox:SetAutoFocus(false)
	textBox:SetFontObject(ChatFontNormal)
	textBox:SetWidth(FIELD_WIDTH - 22)
	textBox:SetMaxLetters(2000)
	textBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			CurrentPhrase().text = self:GetText()
			RefreshSlots()
		end
	end)
	textBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
	scroll:SetScrollChild(textBox)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function()
		textBox:SetFocus()
	end)
	editor.textBox = textBox

	local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", -4, -12)
	help:SetWidth(FIELD_WIDTH)
	help:SetJustifyH("LEFT")
	help:SetWordWrap(true)
	help:SetText(L["One message per line. Several lines make a random group: one of them is sent each time. %t is your target's name, %q is the quest you are tracking. A line can also be a game command such as /dance: the character performs it instead of saying the text."])

	local clear = CreatePanelButton(panel, L["Clear slot"], 130, function()
		local phrase = CurrentPhrase()
		phrase.label, phrase.text, phrase.channel = "", "", "DEFAULT"
		LoadSlot()
	end)
	clear:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
end

------------------------------------------------------------
-- Export / import: the phrases of one wheel as one line of text in a copy-paste box
------------------------------------------------------------

local transfer

local function CreateTransferDialog()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(480, 300)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableMouse(true)
	frame:Hide()
	AddBox(frame, 0.97)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", 16, -14)

	frame.note = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	frame.note:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
	frame.note:SetWidth(448)
	frame.note:SetJustifyH("LEFT")
	frame.note:SetWordWrap(true)

	local scroll = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, -84)
	scroll:SetPoint("BOTTOMRIGHT", -40, 52)

	local boxBackground = frame:CreateTexture(nil, "BORDER")
	boxBackground:SetPoint("TOPLEFT", scroll, -5, 5)
	boxBackground:SetPoint("BOTTOMRIGHT", scroll, 5, -5)
	boxBackground:SetColorTexture(0, 0, 0, 0.6)

	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box:SetWidth(416)
	box:SetMaxLetters(0)
	-- The box holds the focus while the window is open, so Escape always lands here.
	box:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(box)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	frame.box = box

	local close = CreatePanelButton(frame, CLOSE, 120, function()
		frame:Hide()
	end)
	close:SetPoint("BOTTOMRIGHT", -16, 14)

	frame.import = CreatePanelButton(frame, L["Import"], 120, function()
		if ns.ImportPhrases(box:GetText(), frame.wheel) then
			frame:Hide()
			LoadWheel()
			ns.Print(L["Phrases were imported."])
		else
			frame.note:SetText("|cffff4040" .. L["This text is not a Forever Pie export."] .. "|r")
		end
	end)
	frame.import:SetPoint("RIGHT", close, "LEFT", -8, 0)
	return frame
end

local function ShowTransferDialog(importing)
	transfer = transfer or CreateTransferDialog()
	transfer.wheel = editor.wheel
	transfer.title:SetText(importing and L["Import phrases"] or L["Export phrases"])
	transfer.note:SetText((importing
		and L["Paste an exported text here (Ctrl+V). Importing replaces all phrases of wheel %d."]
		or L["All phrases of wheel %d as one text. Press Ctrl+C to copy it and keep it somewhere safe."]):format(editor.wheel))
	transfer.import:SetShown(importing)
	transfer.box:SetText(importing and "" or ns.ExportPhrases(editor.wheel))
	transfer:Show()
	transfer.box:SetFocus()
	if not importing then
		transfer.box:HighlightText()
	end
end

local function CreatePhrasePanel()
	local panel = CreateFrame("Frame")
	panel:Hide()

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -16)
	title:SetText(L["Phrases"])

	-- Shows the wheel being edited, which also makes it the one that opens in the game.
	local preview = CreatePanelButton(panel, L["Preview wheel"], 130, function()
		if ns.IsWheelShown() then
			ns.HideWheel()
		else
			ns.SetCurrentWheel(editor.wheel)
			ns.ShowWheel(true)
		end
	end)
	preview:SetPoint("TOPRIGHT", -36, -14)

	CreateWheelControls(panel)

	local pie = CreatePie(panel)
	pie:SetPoint("TOPLEFT", 4, PIE_Y)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOP", pie, "BOTTOM", 0, -6)
	hint:SetText(L["Click a slot on the wheel to edit it."])

	local export = CreatePanelButton(panel, L["Export"], 120, function()
		ShowTransferDialog(false)
	end)
	export:SetPoint("TOPRIGHT", hint, "BOTTOM", -4, -8)
	local import = CreatePanelButton(panel, L["Import"], 120, function()
		ShowTransferDialog(true)
	end)
	import:SetPoint("TOPLEFT", hint, "BOTTOM", 4, -8)

	CreateFields(panel, pie)

	-- The editor opens on the wheel that is current in the game.
	local opened = false
	panel:SetScript("OnShow", function()
		if not opened then
			opened = true
			editor.wheel = ns.db.wheel
		end
		LoadWheel()
	end)
	panel:SetScript("OnHide", function()
		if confirm then
			confirm:Hide()
		end
		if transfer then
			transfer:Hide()
		end
	end)
	return panel
end

------------------------------------------------------------
-- Registration
------------------------------------------------------------

function ns.InitOptions()
	mainCategory = Settings.RegisterCanvasLayoutCategory(CreateGeneralPanel(), "Forever Pie")
	Settings.RegisterCanvasLayoutSubcategory(mainCategory, CreatePhrasePanel(), L["Phrases"])
	Settings.RegisterAddOnCategory(mainCategory)
end

function ns.OpenOptions()
	if mainCategory then
		Settings.OpenToCategory(mainCategory:GetID())
	end
end
