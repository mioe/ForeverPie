local _, ns = ...
local L = ns.L

-- Editor order: clockwise from the top, the way the wheel is read.
local DIRECTION_ORDER = { 3, 2, 1, 8, 7, 6, 5, 4 }
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

local mainCategory

------------------------------------------------------------
-- General settings (native vertical layout)
------------------------------------------------------------

local function AddSetting(category, key, name)
	local default = ns.DEFAULTS[key]
	return Settings.RegisterAddOnSetting(category, "ForeverPie_" .. key, key, ns.db, type(default), name, default)
end

local function RegisterGeneral(category)
	local function ChannelOptions()
		local container = Settings.CreateControlTextContainer()
		for _, channel in ipairs(ns.CHANNEL_ORDER) do
			container:Add(channel, ns.CHANNEL_NAMES[channel])
		end
		return container:GetData()
	end
	Settings.CreateDropdown(category, AddSetting(category, "channel", L["Default channel"]), ChannelOptions,
		L["Where phrases are sent. Auto: while you are in a group they go to the group chat (party, raid or instance), otherwise to Say.\n\nA phrase with its own type in the phrase editor (Yell, for example) always uses that type and ignores this setting."])

	local scale = AddSetting(category, "scale", L["Wheel scale"])
	local scaleOptions = Settings.CreateSliderOptions(0.7, 1.4, 0.05)
	scaleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return ("%d%%"):format(value * 100 + 0.5)
	end)
	Settings.CreateSlider(category, scale, scaleOptions)
end

------------------------------------------------------------
-- Phrase editor: a clickable copy of the wheel (canvas subcategory)
------------------------------------------------------------

local PIE_SIZE = 380
local SLOT_WIDTH, SLOT_HEIGHT = 104, 21
-- Top to bottom inside a segment, same as on the real wheel.
local SLOT_ORDER = { ns.VARIANT_LB, ns.VARIANT_MAIN, ns.VARIANT_RB }
local SLOT_KEY = { [ns.VARIANT_LB] = "PADLSHOULDER", [ns.VARIANT_RB] = "PADRSHOULDER" }

local editor = { dir = 3, variant = ns.VARIANT_MAIN, slots = {}, resetLanguage = "AUTO" }

local function CurrentPhrase()
	return ns.db.phrases[editor.dir][editor.variant]
end

local function RefreshSlots()
	for _, slot in ipairs(editor.slots) do
		local label, count = ns.GetPhraseLabel(slot.dir, slot.variant)
		local phrase = ns.db.phrases[slot.dir][slot.variant]
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
				slot.Text:SetTextColor(1, 0.82, 0)
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
	editor.typeDropdown:GenerateMenu()
	RefreshSlots()
end

local function SelectSlot(dir, variant)
	editor.labelBox:ClearFocus()
	editor.textBox:ClearFocus()
	editor.dir, editor.variant = dir, variant
	LoadSlot()
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
	slot.Selected:SetColorTexture(1, 0.82, 0, 0.28)

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
		highlight:SetVertexColor(1, 0.82, 0, 0.25)
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

local function CreateCaption(panel, text, anchor, offsetY)
	local caption = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	caption:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
	caption:SetText(text)
	return caption
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

	-- Type: how the phrase is spoken (say, yell, party...). Default follows the general setting.
	local typeCaption = CreateCaption(panel, L["Type"], labelCaption, -44)
	local typeDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	typeDropdown:SetWidth(FIELD_WIDTH)
	typeDropdown:SetPoint("TOPLEFT", typeCaption, "BOTTOMLEFT", 0, -4)
	typeDropdown:SetupMenu(function(_, root)
		local function IsSelected(channel)
			return CurrentPhrase().channel == channel
		end
		local function SetSelected(channel)
			CurrentPhrase().channel = channel
			RefreshSlots()
		end
		for _, channel in ipairs(ns.PHRASE_CHANNEL_ORDER) do
			root:CreateRadio(ns.CHANNEL_NAMES[channel], IsSelected, SetSelected, channel)
		end
	end)
	editor.typeDropdown = typeDropdown

	local textCaption = CreateCaption(panel, L["Messages"], typeCaption, -50)
	local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
	scroll:SetSize(FIELD_WIDTH - 22, 150)
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

	local clear = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	clear:SetSize(130, 22)
	clear:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
	clear:SetText(L["Clear slot"])
	clear:SetScript("OnClick", function()
		local phrase = CurrentPhrase()
		phrase.label, phrase.text, phrase.channel = "", "", "DEFAULT"
		LoadSlot()
	end)
end

------------------------------------------------------------
-- Export / import: the phrases as one line of text in a copy-paste box
------------------------------------------------------------

local transfer

local function CreateTransferDialog()
	local frame = CreateFrame("Frame", "ForeverPieTransfer", UIParent)
	frame:SetSize(480, 300)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableMouse(true)
	frame:Hide()
	-- Escape closes it like any other game window.
	table.insert(UISpecialFrames, "ForeverPieTransfer")

	local border = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(0.6, 0.5, 0.25, 1)
	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0.05, 0.05, 0.05, 0.97)

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
	box:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(box)
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function()
		box:SetFocus()
	end)
	frame.box = box

	local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	close:SetSize(120, 22)
	close:SetPoint("BOTTOMRIGHT", -16, 14)
	close:SetText(CLOSE)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame.import = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.import:SetSize(120, 22)
	frame.import:SetPoint("RIGHT", close, "LEFT", -8, 0)
	frame.import:SetText(L["Import"])
	frame.import:SetScript("OnClick", function()
		if ns.ImportPhrases(box:GetText()) then
			frame:Hide()
			LoadSlot()
			ns.Print(L["Phrases were imported."])
		else
			frame.note:SetText("|cffff4040" .. L["This text is not a Forever Pie export."] .. "|r")
		end
	end)
	return frame
end

local function ShowTransferDialog(importing)
	transfer = transfer or CreateTransferDialog()
	transfer.title:SetText(importing and L["Import phrases"] or L["Export phrases"])
	transfer.note:SetText(importing
		and L["Paste an exported text here (Ctrl+V). Importing replaces all your current phrases."]
		or L["All your phrases as one text. Press Ctrl+C to copy it and keep it somewhere safe."])
	transfer.import:SetShown(importing)
	transfer.box:SetText(importing and "" or ns.ExportPhrases())
	transfer:Show()
	transfer.box:SetFocus()
	if not importing then
		transfer.box:HighlightText()
	end
end

-- Name of a default phrase set; "AUTO" shows which set the game language resolves to.
local function PhraseLanguageName(language)
	local resolved = language == "AUTO" and ns.GetClientPhraseLanguage() or language
	for _, entry in ipairs(ns.PHRASE_LANGUAGES) do
		if entry[1] == resolved then
			return language == "AUTO" and ("%s (%s)"):format(L["Auto"], entry[2]) or entry[2]
		end
	end
end

local function CreatePanelButton(panel, text, width, onClick)
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function CreatePhrasePanel()
	local panel = CreateFrame("Frame")
	panel:Hide()

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -22)
	title:SetText(L["Phrases"])

	local reset = CreatePanelButton(panel, L["Reset phrases"], 130, function()
		StaticPopup_Show("FOREVERPIE_RESET_PHRASES", PhraseLanguageName(editor.resetLanguage), nil, editor.resetLanguage)
	end)
	reset:SetPoint("TOPRIGHT", -36, -18)

	-- Which default set "Reset phrases" restores.
	local language = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
	language:SetWidth(150)
	language:SetPoint("RIGHT", reset, "LEFT", -8, 0)
	language:SetupMenu(function(_, root)
		local function IsSelected(value)
			return editor.resetLanguage == value
		end
		local function SetSelected(value)
			editor.resetLanguage = value
		end
		root:CreateRadio(PhraseLanguageName("AUTO"), IsSelected, SetSelected, "AUTO")
		for _, entry in ipairs(ns.PHRASE_LANGUAGES) do
			root:CreateRadio(entry[2], IsSelected, SetSelected, entry[1])
		end
	end)

	local preview = CreatePanelButton(panel, L["Preview wheel"], 130, function()
		if ns.IsWheelShown() then
			ns.HideWheel()
		else
			ns.ShowWheel(true)
		end
	end)
	preview:SetPoint("RIGHT", language, "LEFT", -8, 0)

	local pie = CreatePie(panel)
	pie:SetPoint("TOPLEFT", 4, -62)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOP", pie, "BOTTOM", 0, -8)
	hint:SetText(L["Click a slot on the wheel to edit it."])

	local export = CreatePanelButton(panel, L["Export"], 120, function()
		ShowTransferDialog(false)
	end)
	export:SetPoint("TOPRIGHT", hint, "BOTTOM", -4, -10)
	local import = CreatePanelButton(panel, L["Import"], 120, function()
		ShowTransferDialog(true)
	end)
	import:SetPoint("TOPLEFT", hint, "BOTTOM", 4, -10)

	CreateFields(panel, pie)

	panel:SetScript("OnShow", LoadSlot)
	return panel
end

------------------------------------------------------------
-- Registration
------------------------------------------------------------

function ns.InitOptions()
	StaticPopupDialogs["FOREVERPIE_RESET_PHRASES"] = {
		text = L["Replace all phrases with the default set (%s)?\n\nAll your current phrases will be lost. Export them first if you want to keep them."],
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, language)
			ns.ResetPhrases(language)
			if editor.title then
				LoadSlot()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}

	mainCategory = Settings.RegisterVerticalLayoutCategory("Forever Pie")
	RegisterGeneral(mainCategory)
	Settings.RegisterCanvasLayoutSubcategory(mainCategory, CreatePhrasePanel(), L["Phrases"])
	Settings.RegisterAddOnCategory(mainCategory)
end

function ns.OpenOptions()
	if mainCategory then
		Settings.OpenToCategory(mainCategory:GetID())
	end
end
