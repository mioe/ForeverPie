local addonName, ns = ...
local L = ns.L

ns.VARIANT_MAIN, ns.VARIANT_LB, ns.VARIANT_RB = 1, 2, 3
ns.SEGMENT_COUNT = 8

local DEFAULTS = {
	channel = "AUTO",
	scale = 1,
}
ns.DEFAULTS = DEFAULTS

-- The controls are fixed: hold RB and press R3 to open, aim with the right stick.
ns.OPEN_KEY = "PADRSTICK"
ns.OPEN_MODIFIER = "PADRSHOULDER"
ns.AIM_STICK = "Camera"

-- Bumped when saved settings from an older layout have to be dropped.
local DB_VERSION = 2

local CHANNEL_NAME_KEYS = {
	DEFAULT = "Default",
	AUTO = "Auto (group or Say)",
	SAY = "Say",
	YELL = "Yell",
	PARTY = "Party",
	RAID = "Raid",
	INSTANCE_CHAT = "Instance",
	GUILD = "Guild",
	EMOTE = "Emote",
	RAID_WARNING = "Raid warning",
	COMMAND = "Game command",
}
ns.CHANNEL_NAMES = setmetatable({}, { __index = function(_, channel)
	local key = CHANNEL_NAME_KEYS[channel]
	return key and L[key] or nil
end })
ns.CHANNEL_ORDER = { "AUTO", "SAY", "YELL", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD" }
-- Per-phrase type: DEFAULT follows the "Default channel" setting.
ns.PHRASE_CHANNEL_ORDER = { "DEFAULT", "SAY", "YELL", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "EMOTE" }
local VALID_PHRASE_CHANNEL = {}
for _, channel in ipairs(ns.PHRASE_CHANNEL_ORDER) do
	VALID_PHRASE_CHANNEL[channel] = true
end

local PREFIX_TO_CHANNEL = {
	s = "SAY", say = "SAY",
	y = "YELL", yell = "YELL",
	p = "PARTY", party = "PARTY",
	raid = "RAID", ra = "RAID",
	i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT",
	g = "GUILD", guild = "GUILD",
	e = "EMOTE", em = "EMOTE", me = "EMOTE",
	rw = "RAID_WARNING",
}

local function Print(msg)
	print("|cffffd100Forever Pie:|r " .. msg)
end
ns.Print = Print

------------------------------------------------------------
-- Saved variables
------------------------------------------------------------

local function CopyPhrases(source)
	local phrases = {}
	for dir = 1, ns.SEGMENT_COUNT do
		phrases[dir] = {}
		for variant = 1, 3 do
			local src = source and source[dir] and source[dir][variant]
			phrases[dir][variant] = {
				label = src and type(src.label) == "string" and src.label or "",
				text = src and type(src.text) == "string" and src.text or "",
				channel = src and VALID_PHRASE_CHANNEL[src.channel] and src.channel or "DEFAULT",
			}
		end
	end
	return phrases
end

local function InitDB()
	if type(ForeverPieDB) ~= "table" then
		ForeverPieDB = {}
	end
	local db = ForeverPieDB
	if db.version ~= DB_VERSION then
		-- v2: the wheel opens with a chord (RB + R3) instead of holding Select, so the
		-- hold / tap / send-on-release options are gone.
		db.holdDelay = nil
		db.tapPassthrough = nil
		db.sendOnRelease = nil
		db.version = DB_VERSION
	end
	db.cameraSpeeds = nil
	-- The language always follows the client and the controls are fixed now.
	db.language = nil
	db.openKey = nil
	db.openModifier = nil
	db.aimStick = nil
	for key, value in pairs(DEFAULTS) do
		if type(db[key]) ~= type(value) then
			db[key] = value
		end
	end
	-- Phrases are normalized on every load so a hand-edited or partial table can't break the wheel.
	db.phrases = CopyPhrases(type(db.phrases) == "table" and db.phrases or ns.GetDefaultPhrases())
	ns.db = db
end

-- language picks the default set (see ns.PHRASE_LANGUAGES); nil follows the game client.
function ns.ResetPhrases(language)
	ns.db.phrases = CopyPhrases(ns.GetDefaultPhrases(language))
	if ns.RefreshWheel then
		ns.RefreshWheel()
	end
end

-- Export format: "FPIE1" and then channel, label and text of all 24 slots, joined with ";".
-- Everything that could break the single line is escaped, "|" too: edit boxes read it as markup.
local EXPORT_HEADER = "FPIE1"
local ESCAPES = { ["\\"] = "\\\\", [";"] = "\\s", ["\n"] = "\\n", ["|"] = "\\p" }
local UNESCAPES = { ["\\"] = "\\", s = ";", n = "\n", p = "|" }

function ns.ExportPhrases()
	local fields = { EXPORT_HEADER }
	for dir = 1, ns.SEGMENT_COUNT do
		for variant = 1, 3 do
			local phrase = ns.db.phrases[dir][variant]
			for _, value in ipairs({ phrase.channel, phrase.label, phrase.text }) do
				table.insert(fields, (value:gsub("\r", ""):gsub("[\\;\n|]", ESCAPES)))
			end
		end
	end
	return table.concat(fields, ";")
end

-- Replaces every phrase with the exported ones. Returns false when the text is not an export.
function ns.ImportPhrases(text)
	local fields = {}
	for field in (strtrim(text or "") .. ";"):gmatch("(.-);") do
		table.insert(fields, (field:gsub("\\(.)", UNESCAPES)))
	end
	if fields[1] ~= EXPORT_HEADER or #fields ~= 1 + ns.SEGMENT_COUNT * 3 * 3 then
		return false
	end
	local source, index = {}, 2
	for dir = 1, ns.SEGMENT_COUNT do
		source[dir] = {}
		for variant = 1, 3 do
			source[dir][variant] = { channel = fields[index], label = fields[index + 1], text = fields[index + 2] }
			index = index + 3
		end
	end
	ns.db.phrases = CopyPhrases(source)
	if ns.RefreshWheel then
		ns.RefreshWheel()
	end
	return true
end

function ns.GetPhrase(dir, variant)
	local group = ns.db.phrases[dir]
	return group and group[variant]
end

-- A slot's text holds one message per line; more than one line makes it a random group.
function ns.GetPhraseLines(dir, variant)
	local phrase = ns.GetPhrase(dir, variant)
	local lines = {}
	if phrase then
		for line in (phrase.text or ""):gmatch("[^\r\n]+") do
			line = strtrim(line)
			if line ~= "" then
				table.insert(lines, line)
			end
		end
	end
	return lines
end

-- Text shown on the wheel: the name, or the first message when no name is set.
-- Second return is the number of messages in the slot.
function ns.GetPhraseLabel(dir, variant)
	local lines = ns.GetPhraseLines(dir, variant)
	if #lines == 0 then
		return "", 0
	end
	local label = strtrim(ns.GetPhrase(dir, variant).label or "")
	if label == "" then
		label = lines[1]:match("^/%a+%s+(.+)$") or lines[1]
	end
	return label, #lines
end

------------------------------------------------------------
-- Chat
------------------------------------------------------------

local function GetAutoChannel()
	local instanceMembers = GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE)
	local homeMembers = GetNumGroupMembers(LE_PARTY_CATEGORY_HOME)
	if instanceMembers > 0 then
		return instanceMembers <= 5 and "INSTANCE_CHAT" or "RAID"
	elseif homeMembers > 0 then
		return homeMembers <= 5 and "PARTY" or "RAID"
	end
	return "SAY"
end

local function GetTargetName()
	for _, unit in ipairs({ "target", "softenemy", "softfriend" }) do
		local name = UnitName(unit)
		-- Unit names can be secret values in combat; those can't be put into a chat message.
		if name and not (issecretvalue and issecretvalue(name)) then
			return name
		end
	end
	return nil
end

-- The quest "in focus": the one the game is pointing at (super-tracked), else the first tracked one.
-- Returns a clickable chat link and a plain "[Title]".
local function GetFocusedQuest()
	local questID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	if (not questID or questID == 0) and C_QuestLog.GetQuestIDForQuestWatchIndex then
		questID = C_QuestLog.GetQuestIDForQuestWatchIndex(1)
	end
	local title = questID and questID ~= 0 and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
	if not title then
		return nil
	end
	local plain = "[" .. title .. "]"
	return GetQuestLink and GetQuestLink(questID) or plain, plain
end

-- %t is the target's name, %q is the focused quest.
local function FillPlaceholders(line, plainQuest)
	local targetName = GetTargetName() or TARGET or "target"
	line = line:gsub("%%t", function() return targetName end)
	if line:find("%%q") then
		local link, plain = GetFocusedQuest()
		local quest = (plainQuest and plain or link) or L["quest"]
		line = line:gsub("%%q", function() return quest end)
	end
	return line
end

-- Cuts to the chat limit without splitting a UTF-8 character.
local function TruncateUTF8(text, maxBytes)
	if #text <= maxBytes then
		return text
	end
	local cut = maxBytes
	while cut > 0 do
		local byte = text:byte(cut + 1)
		if not byte or byte < 128 or byte > 191 then
			break
		end
		cut = cut - 1
	end
	return text:sub(1, cut)
end

------------------------------------------------------------
-- Game commands: emotes (/dance, /cheer) and addon slash commands
------------------------------------------------------------

local emoteCommands

-- Maps every emote command the client knows (localized ones included) to its token,
-- the same way the chat edit box does it (EMOTEn_CMDm globals -> EMOTEn_TOKEN).
local function GetEmoteToken(command)
	if not emoteCommands then
		emoteCommands = {}
		for i = 1, (MAXEMOTEINDEX or 1000) do
			local token = _G["EMOTE" .. i .. "_TOKEN"]
			if token then
				local j = 1
				local cmd = _G["EMOTE" .. i .. "_CMD" .. j]
				while cmd do
					emoteCommands[cmd] = token
					emoteCommands[cmd:upper()] = token
					j = j + 1
					cmd = _G["EMOTE" .. i .. "_CMD" .. j]
				end
			end
		end
	end
	return emoteCommands[command] or emoteCommands[command:upper()]
end

-- Finds a handler registered through SlashCmdList (addons and non-secure Blizzard commands).
local function GetSlashHandler(command)
	local upper = command:upper()
	for name, handler in pairs(SlashCmdList) do
		local i = 1
		local cmd = _G["SLASH_" .. name .. i]
		while cmd do
			if cmd == command or cmd:upper() == upper then
				return handler
			end
			i = i + 1
			cmd = _G["SLASH_" .. name .. i]
		end
	end
	return nil
end

-- Returns the command and its argument when a line is a game command rather than chat text.
-- Channel prefixes (/s, /y, /p...) are not commands: they only pick where the text goes.
local function ParseCommand(line)
	local command, argument = line:match("^(/%S+)%s*(.*)$")
	if not command or PREFIX_TO_CHANNEL[command:sub(2):lower()] then
		return nil
	end
	return command, argument
end

local function RunCommand(command, argument)
	local token = GetEmoteToken(command)
	if token then
		-- With no argument the emote goes to the current target, like typing it in chat.
		local ok = C_ChatInfo.PerformEmote(token, argument ~= "" and argument or nil)
		return ok ~= false
	end

	if IsSecureCmd and IsSecureCmd(command) then
		-- /cast, /target, /use and similar can only run from a macro, never from addon code.
		Print(L["%s can't be run by addons."]:format(command))
		return false
	end

	local handler = GetSlashHandler(command)
	if handler then
		local editBox = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
		local ok, err = pcall(handler, argument, editBox)
		if not ok then
			geterrorhandler()(err)
		end
		return ok
	end

	Print(L["Unknown command: %s"]:format(command))
	return false
end

-- Turns one stored line into the final message and chat type.
-- Game commands come back with the "COMMAND" type and are run instead of sent.
local function ResolveLine(line, phraseChannel)
	if ParseCommand(line) then
		return FillPlaceholders(line, true), "COMMAND"
	end

	local channel = phraseChannel
	if channel == "DEFAULT" then
		channel = ns.db.channel
	end
	local prefix, rest = line:match("^/(%a+)%s+(.+)$")
	if prefix and PREFIX_TO_CHANNEL[prefix:lower()] then
		channel = PREFIX_TO_CHANNEL[prefix:lower()]
		line = rest
	end
	if channel == "AUTO" then
		channel = GetAutoChannel()
	end

	local filled = FillPlaceholders(line)
	if #filled > 255 then
		-- A cut-off link would make the client reject the message; the plain title is shorter.
		filled = FillPlaceholders(line, true)
	end

	return TruncateUTF8(filled, 255), channel
end

-- For the wheel preview: message, chat type and message count of a slot (nil when empty).
-- For a random group the message is the first line; SendPhrase does the actual pick.
function ns.ResolvePhrase(dir, variant)
	local lines = ns.GetPhraseLines(dir, variant)
	if #lines == 0 then
		return nil
	end
	local text, channel = ResolveLine(lines[1], ns.GetPhrase(dir, variant).channel)
	return text, channel, #lines
end

local lastPick = {}

-- Must run from a hardware event (button press or release): Say, Yell and Emote
-- are rejected by the client otherwise when outside of instances.
function ns.SendPhrase(dir, variant)
	local lines = ns.GetPhraseLines(dir, variant)
	if #lines == 0 then
		return false
	end

	-- Random group: never repeat the previous pick twice in a row.
	local slot = dir * 4 + variant
	local pick = 1
	if #lines > 1 then
		pick = math.random(#lines)
		if pick == lastPick[slot] then
			pick = pick % #lines + 1
		end
	end
	lastPick[slot] = pick

	if lines[pick]:find("%%q") and not GetFocusedQuest() then
		Print(L["No tracked quest to mention, the message was not sent."])
		return false
	end

	local text, channel = ResolveLine(lines[pick], ns.GetPhrase(dir, variant).channel)
	if channel == "COMMAND" then
		return RunCommand(ParseCommand(text))
	end

	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		Print(L["Chat is locked right now, the message was not sent."])
		return false
	end
	C_ChatInfo.SendChatMessage(text, channel)
	return true
end

------------------------------------------------------------
-- Open chord
------------------------------------------------------------

function ns.IsPadButtonDown(key)
	local state = C_GamePad.GetDeviceMappedState()
	local index = C_GamePad.ButtonBindingToIndex(key)
	if not state or not state.buttons or not index then
		return nil
	end
	return state.buttons[index + 1]
end

-- The wheel opens on the open button while the modifier is held (RB + R3).
-- Nothing is rebound: this frame sees every gamepad press and passes it on to the game,
-- except for the chord itself. The open button alone keeps its native action (ping on R3)
-- and never runs through addon code, which is what used to trip "blocked action" errors.
local catcher = CreateFrame("Frame", "ForeverPieInput", UIParent)
catcher:SetFrameStrata("HIGH")

local seenDown = {}
local swallowing = {}

-- Whether a frame swallows the current gamepad press instead of passing it on to the game.
-- Frames pass everything by default; the game blocks changing this during combat.
function ns.SetSwallow(frame, swallow)
	if InCombatLockdown() then
		return false
	end
	frame:SetPropagateKeyboardInput(not swallow)
	swallowing[frame] = swallow or nil
	return true
end

local function IsModifierHeld()
	local modifier = ns.OPEN_MODIFIER
	local down = ns.IsPadButtonDown(modifier)
	if down == nil then
		down = seenDown[modifier]
	end
	return down == true
end

catcher:SetScript("OnGamePadButtonDown", function(_, button)
	seenDown[button] = true
	local opened = false
	-- When the wheel passes a press through (combat), the press that closed it lands here
	-- in the same frame and must not reopen it.
	if ns.db and button == ns.OPEN_KEY and not ns.IsWheelShown() and ns.wheelHiddenAt ~= GetTime() and IsModifierHeld() then
		opened = ns.ShowWheel(false)
	end
	-- Out of combat the chord press is swallowed, so the game doesn't also act on it.
	-- In combat addons can't block input: the wheel still opens, but the native action runs too.
	if ns.SetSwallow(catcher, opened) and opened then
		C_Timer.After(0, function()
			ns.SetSwallow(catcher, false)
		end)
	end
end)

catcher:SetScript("OnGamePadButtonUp", function(_, button)
	seenDown[button] = nil
end)

-- Presses must pass through before the frame starts listening, or it would eat the whole gamepad.
local function EnableCatcher()
	if ns.SetSwallow(catcher, false) then
		catcher:EnableGamePadButton(true)
	end
	ns.PrepareWheel()
end

------------------------------------------------------------
-- Events and slash command
------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			InitDB()
			ns.InitOptions()
		end
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		-- Names the exact call the game refused, so "Interface action failed because of an AddOn"
		-- can be traced when it is this addon's doing.
		if arg1 == addonName then
			Print(("%s: %s"):format(event, tostring(arg2)))
		end
	elseif not ns.db then
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Fires just before combat lockdown: never enter combat while swallowing presses.
		for frame in pairs(swallowing) do
			ns.SetSwallow(frame, false)
		end
	else
		-- PLAYER_LOGIN, or PLAYER_REGEN_ENABLED after a reload in the middle of a fight.
		EnableCatcher()
	end
end)

SLASH_FOREVERPIE1 = "/fpie"
SLASH_FOREVERPIE2 = "/foreverpie"
SlashCmdList.FOREVERPIE = function(msg)
	local command = strtrim(msg or ""):lower()
	if command == "" or command == "config" or command == "options" then
		ns.OpenOptions()
	elseif command == "toggle" or command == "test" then
		if ns.IsWheelShown() then
			ns.HideWheel()
		else
			ns.ShowWheel(true)
		end
	elseif command == "reset" then
		ns.ResetPhrases()
		Print(L["Phrases were reset."])
	else
		Print(L["Usage:"])
		print("  /fpie - " .. L["open settings"])
		print("  /fpie toggle - " .. L["toggle the wheel for mouse testing"])
		print("  /fpie reset - " .. L["reset phrases to the defaults"])
	end
end
