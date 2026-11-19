local _, ns = ...

-- English strings are the keys themselves; RU holds the Russian translations.
local RU = {}
local L = setmetatable({}, { __index = function(_, key)
	if ns.lang == "ruRU" then
		return RU[key] or key
	end
	return key
end })
ns.L = L

-- The interface is English or Russian and always follows the game client.
ns.lang = GetLocale() == "ruRU" and "ruRU" or "enUS"

local DEFAULT_PHRASES = {}

-- Default phrase sets exist in more languages than the interface, in the order shown in the editor.
ns.PHRASE_LANGUAGES = {
	{ "enUS", "English" },
	{ "ruRU", "Русский" },
	{ "ukUA", "Українська" },
	{ "frFR", "Français" },
	{ "plPL", "Polski" },
	{ "ptBR", "Português" },
}

local CLIENT_PHRASES = { ruRU = "ruRU", frFR = "frFR", ptBR = "ptBR", ptPT = "ptBR" }

-- The phrase set that matches the game client, English when there is none.
function ns.GetClientPhraseLanguage()
	return CLIENT_PHRASES[GetLocale()] or "enUS"
end

-- language is a key of DEFAULT_PHRASES; nil or "AUTO" follows the game client.
function ns.GetDefaultPhrases(language)
	return DEFAULT_PHRASES[language] or DEFAULT_PHRASES[ns.GetClientPhraseLanguage()]
end

-- Wheel directions use the same numbering as Blizzard's GamepadRadial:
-- 1 = right, then counter-clockwise (2 = up-right, 3 = up ... 8 = down-right).
-- Each direction holds three phrases: [1] main page, [2] LB page, [3] RB page.
-- A phrase is { label = short text on the wheel, text = message sent to chat }.
-- Several lines in one slot make a random group: one of them is picked on every send.
-- %t is the target's name, %q is the tracked quest. All sets share one layout.
DEFAULT_PHRASES.enUS = {
	[3] = {
		{ label = "Greeting", text = "Hi!\nHello!\nSalut!\nHey there!" },
		{ label = "Thanks!", text = "Thanks!" },
		{ label = "Sorry!", text = "Sorry!" },
	},
	[2] = {
		{ label = "Ready!", text = "Ready!" },
		{ label = "Wait", text = "Wait a moment, please" },
		{ label = "On my way", text = "On my way!" },
	},
	[1] = {
		{ label = "Invite pls", text = "Invite me to the group, please!" },
		{ label = "Quest", text = "Invite me / forming a group for %q" },
		{ label = "Follow me", text = "Follow me" },
	},
	[8] = {
		{ label = "Heal me!", text = "Need healing!" },
		{ label = "Mana!", text = "Need mana!" },
		{ label = "Drinking", text = "Drinking, 1 sec" },
	},
	[7] = {
		{ label = "Help!", text = "Help me!!!", channel = "YELL" },
		{ label = "No problem", text = "No problem" },
		{ label = "Thanks for the group", text = "Thanks for the group!" },
	},
	[6] = {
		{ label = "Dryad", text = "I'm game!\nI'm on the lookout.\nNeed me to scout?\nIs there danger?\nFleet as a deer!\nQuiet as a mouse!\nFall like leaves... in fall!\nFree the trees!" },
		{ label = "Hi guild", text = "Hi!\nHello!\nSalut!\nHey there!", channel = "GUILD" },
		{ label = "I'm on a gamepad", text = "I'm playing with a gamepad right now" },
	},
	[5] = {
		{ label = "Buff pls", text = "Could I get a buff, please?" },
		{ label = "AFK 1", text = "AFK 1 min" },
		{ label = "AFK 5", text = "AFK 5 min" },
	},
	[4] = {
		{ label = "Yes", text = "Yes" },
		{ label = "No", text = "No" },
		{ label = "Maybe", text = "Maybe" },
	},
}

DEFAULT_PHRASES.ruRU = {
	[3] = {
		{ label = "Приветствие", text = "Привет!\nСалют!\nЗдравствуйте!\nПриветствую!" },
		{ label = "Спасибо!", text = "Спасибо!" },
		{ label = "Извините!", text = "Извините!" },
	},
	[2] = {
		{ label = "Готов!", text = "Готов!" },
		{ label = "Подождите", text = "Подождите, пожалуйста" },
		{ label = "Уже иду", text = "Уже иду!" },
	},
	[1] = {
		{ label = "Инвайт", text = "Пригласите в группу, пожалуйста!" },
		{ label = "Quest", text = "Пригласите/собираю в группу для %q" },
		{ label = "За мной", text = "Идите за мной" },
	},
	[8] = {
		{ label = "Лечение!", text = "Нужно лечение!" },
		{ label = "Мана!", text = "Нужна мана!" },
		{ label = "Пью", text = "Пью, секунду" },
	},
	[7] = {
		{ label = "Помогите", text = "Help me!!!", channel = "YELL" },
		{ label = "Без проблем", text = "Без проблем" },
		{ label = "Спасибо за группу", text = "Спасибо за группу!" },
	},
	[6] = {
		{ label = "Дриада", text = "Что случилось в наших лесах?\nБесшумно, словно рысь!\nБыстра, как лань!\nГде-то опасность?\nСвободу деревьям!" },
		{ label = "Привет гильдия", text = "Привет!\nСалют!\nЗдравствуйте!\nПриветствую!", channel = "GUILD" },
		{ label = "Я использую джойстик", text = "Я сейчас использую джойстик" },
	},
	[5] = {
		{ label = "Бафф", text = "Можно бафф, пожалуйста?" },
		{ label = "1 афк", text = "1 мин афк" },
		{ label = "5 афк", text = "5 мин афк" },
	},
	[4] = {
		{ label = "Да", text = "Да" },
		{ label = "Нет", text = "Нет" },
		{ label = "Возможно", text = "Возможно" },
	},
}

DEFAULT_PHRASES.ukUA = {
	[3] = {
		{ label = "Привітання", text = "Привіт!\nСалют!\nДоброго дня!\nВітаю!" },
		{ label = "Дякую!", text = "Дякую!" },
		{ label = "Вибачте!", text = "Вибачте!" },
	},
	[2] = {
		{ label = "Готовий!", text = "Готовий!" },
		{ label = "Зачекайте", text = "Зачекайте, будь ласка" },
		{ label = "Вже йду", text = "Вже йду!" },
	},
	[1] = {
		{ label = "Інвайт", text = "Запросіть до групи, будь ласка!" },
		{ label = "Quest", text = "Запросіть/збираю групу для %q" },
		{ label = "За мною", text = "Йдіть за мною" },
	},
	[8] = {
		{ label = "Лікування!", text = "Потрібне лікування!" },
		{ label = "Мана!", text = "Потрібна мана!" },
		{ label = "П'ю", text = "П'ю, секунду" },
	},
	[7] = {
		{ label = "Допоможіть", text = "Help me!!!", channel = "YELL" },
		{ label = "Без проблем", text = "Без проблем" },
		{ label = "Дякую за групу", text = "Дякую за групу!" },
	},
	[6] = {
		{ label = "Дріада", text = "Що сталося в наших лісах?\nБезшумно, наче рись!\nПрудка, мов лань!\nДесь небезпека?\nСвободу деревам!" },
		{ label = "Привіт гільдія", text = "Привіт!\nСалют!\nДоброго дня!\nВітаю!", channel = "GUILD" },
		{ label = "Я використовую джойстик", text = "Я зараз використовую джойстик" },
	},
	[5] = {
		{ label = "Баф", text = "Можна баф, будь ласка?" },
		{ label = "1 афк", text = "1 хв афк" },
		{ label = "5 афк", text = "5 хв афк" },
	},
	[4] = {
		{ label = "Так", text = "Так" },
		{ label = "Ні", text = "Ні" },
		{ label = "Можливо", text = "Можливо" },
	},
}

DEFAULT_PHRASES.frFR = {
	[3] = {
		{ label = "Salutation", text = "Salut !\nBonjour !\nCoucou !\nSalutations !" },
		{ label = "Merci !", text = "Merci !" },
		{ label = "Désolé !", text = "Désolé !" },
	},
	[2] = {
		{ label = "Prêt !", text = "Prêt !" },
		{ label = "Attendez", text = "Attendez, s'il vous plaît" },
		{ label = "J'arrive", text = "J'arrive !" },
	},
	[1] = {
		{ label = "Invitation", text = "Invitez-moi dans le groupe, s'il vous plaît !" },
		{ label = "Quest", text = "Invitez-moi / je monte un groupe pour %q" },
		{ label = "Suivez-moi", text = "Suivez-moi" },
	},
	[8] = {
		{ label = "Soins !", text = "Besoin de soins !" },
		{ label = "Mana !", text = "Besoin de mana !" },
		{ label = "Je bois", text = "Je bois, une seconde" },
	},
	[7] = {
		{ label = "À l'aide", text = "Help me!!!", channel = "YELL" },
		{ label = "Pas de problème", text = "Pas de problème" },
		{ label = "Merci pour le groupe", text = "Merci pour le groupe !" },
	},
	[6] = {
		{ label = "Dryade", text = "Que se passe-t-il dans nos forêts ?\nSilencieuse comme un lynx !\nRapide comme une biche !\nUn danger quelque part ?\nLiberté pour les arbres !" },
		{ label = "Salut la guilde", text = "Salut !\nBonjour !\nCoucou !\nSalutations !", channel = "GUILD" },
		{ label = "Je joue à la manette", text = "Je joue à la manette en ce moment" },
	},
	[5] = {
		{ label = "Buff", text = "Je peux avoir un buff, s'il vous plaît ?" },
		{ label = "AFK 1", text = "AFK 1 min" },
		{ label = "AFK 5", text = "AFK 5 min" },
	},
	[4] = {
		{ label = "Oui", text = "Oui" },
		{ label = "Non", text = "Non" },
		{ label = "Peut-être", text = "Peut-être" },
	},
}

DEFAULT_PHRASES.plPL = {
	[3] = {
		{ label = "Powitanie", text = "Cześć!\nHej!\nDzień dobry!\nWitam!" },
		{ label = "Dziękuję!", text = "Dziękuję!" },
		{ label = "Przepraszam!", text = "Przepraszam!" },
	},
	[2] = {
		{ label = "Gotowy!", text = "Gotowy!" },
		{ label = "Poczekajcie", text = "Poczekajcie, proszę" },
		{ label = "Już idę", text = "Już idę!" },
	},
	[1] = {
		{ label = "Zaproszenie", text = "Zaproście mnie do grupy, proszę!" },
		{ label = "Quest", text = "Zaproście mnie / zbieram grupę do %q" },
		{ label = "Za mną", text = "Chodźcie za mną" },
	},
	[8] = {
		{ label = "Leczenie!", text = "Potrzebuję leczenia!" },
		{ label = "Mana!", text = "Potrzebuję many!" },
		{ label = "Piję", text = "Piję, sekundę" },
	},
	[7] = {
		{ label = "Pomocy", text = "Help me!!!", channel = "YELL" },
		{ label = "Nie ma sprawy", text = "Nie ma sprawy" },
		{ label = "Dzięki za grupę", text = "Dzięki za grupę!" },
	},
	[6] = {
		{ label = "Driada", text = "Co się stało w naszych lasach?\nBezszelestnie jak ryś!\nSzybka jak łania!\nGdzieś czai się niebezpieczeństwo?\nWolność dla drzew!" },
		{ label = "Cześć gildio", text = "Cześć!\nHej!\nDzień dobry!\nWitam!", channel = "GUILD" },
		{ label = "Gram na padzie", text = "Gram teraz na padzie" },
	},
	[5] = {
		{ label = "Buff", text = "Mogę prosić o buffa?" },
		{ label = "AFK 1", text = "AFK 1 min" },
		{ label = "AFK 5", text = "AFK 5 min" },
	},
	[4] = {
		{ label = "Tak", text = "Tak" },
		{ label = "Nie", text = "Nie" },
		{ label = "Być może", text = "Być może" },
	},
}

DEFAULT_PHRASES.ptBR = {
	[3] = {
		{ label = "Saudação", text = "Oi!\nOlá!\nE aí!\nSaudações!" },
		{ label = "Obrigado!", text = "Obrigado!" },
		{ label = "Desculpe!", text = "Desculpe!" },
	},
	[2] = {
		{ label = "Pronto!", text = "Pronto!" },
		{ label = "Espere", text = "Espere, por favor" },
		{ label = "Já vou", text = "Já estou indo!" },
	},
	[1] = {
		{ label = "Convite", text = "Me convidem para o grupo, por favor!" },
		{ label = "Quest", text = "Me convidem / montando grupo para %q" },
		{ label = "Sigam-me", text = "Sigam-me" },
	},
	[8] = {
		{ label = "Cura!", text = "Preciso de cura!" },
		{ label = "Mana!", text = "Preciso de mana!" },
		{ label = "Bebendo", text = "Bebendo, um segundo" },
	},
	[7] = {
		{ label = "Socorro", text = "Help me!!!", channel = "YELL" },
		{ label = "Sem problemas", text = "Sem problemas" },
		{ label = "Obrigado pelo grupo", text = "Obrigado pelo grupo!" },
	},
	[6] = {
		{ label = "Dríade", text = "O que aconteceu em nossas florestas?\nSilenciosa como um lince!\nVeloz como uma corça!\nHá perigo por aí?\nLiberdade para as árvores!" },
		{ label = "Oi guilda", text = "Oi!\nOlá!\nE aí!\nSaudações!", channel = "GUILD" },
		{ label = "Estou no controle", text = "Estou jogando com controle agora" },
	},
	[5] = {
		{ label = "Buff", text = "Pode me dar um buff, por favor?" },
		{ label = "AFK 1", text = "AFK 1 min" },
		{ label = "AFK 5", text = "AFK 5 min" },
	},
	[4] = {
		{ label = "Sim", text = "Sim" },
		{ label = "Não", text = "Não" },
		{ label = "Talvez", text = "Talvez" },
	},
}

RU["Quick Chat"] = "Быстрый чат"
RU["Send"] = "Отправить"
RU["Cancel"] = "Отмена"
RU["Aim with the stick"] = "Наведите стиком"
RU["(empty)"] = "(пусто)"
RU["To: %s"] = "Куда: %s"
RU["Auto (group or Say)"] = "Авто (группа или Сказать)"
RU["Say"] = "Сказать"
RU["Yell"] = "Крик"
RU["Party"] = "Группа"
RU["Raid"] = "Рейд"
RU["Instance"] = "Подземелье"
RU["Guild"] = "Гильдия"
RU["Emote"] = "Эмоция"
RU["Raid warning"] = "Объявление рейду"
RU["Game command"] = "Игровая команда"
RU["%s can't be run by addons."] = "%s нельзя выполнить из аддона."
RU["Unknown command: %s"] = "Неизвестная команда: %s"
RU["Chat is locked right now, the message was not sent."] = "Чат сейчас заблокирован, сообщение не отправлено."
RU["Click"] = "Клик"
RU["Release the stick"] = "Отпустите стик"
RU["quest"] = "задание"
RU["No tracked quest to mention, the message was not sent."] = "Нет отслеживаемого задания, сообщение не отправлено."

RU["Default channel"] = "Канал по умолчанию"
RU["Wheel scale"] = "Масштаб колеса"
RU["Phrases"] = "Фразы"
RU["Default"] = "По умолчанию"
RU["Type"] = "Тип"
RU["Name on the wheel"] = "Название на колесе"
RU["Messages"] = "Сообщения"
RU["Click a slot on the wheel to edit it."] = "Нажмите на слот на колесе, чтобы изменить его."
RU["Random: %d phrases"] = "Случайная из %d"
RU["Main page"] = "Основная страница"
RU["LB page"] = "Страница LB"
RU["RB page"] = "Страница RB"
RU["Clear slot"] = "Очистить слот"
RU["Reset phrases"] = "Сбросить фразы"
RU["Preview wheel"] = "Показать колесо"

RU["Up"] = "Вверх"
RU["Up-Right"] = "Вверх-вправо"
RU["Right"] = "Вправо"
RU["Down-Right"] = "Вниз-вправо"
RU["Down"] = "Вниз"
RU["Down-Left"] = "Вниз-влево"
RU["Left"] = "Влево"
RU["Up-Left"] = "Вверх-влево"

RU["Usage:"] = "Использование:"
RU["open settings"] = "открыть настройки"
RU["toggle the wheel for mouse testing"] = "показать колесо для проверки мышью"
RU["reset phrases to the defaults"] = "сбросить фразы к стандартным"
RU["Phrases were reset."] = "Фразы сброшены."

RU["Where phrases are sent. Auto: while you are in a group they go to the group chat (party, raid or instance), otherwise to Say.\n\nA phrase with its own type in the phrase editor (Yell, for example) always uses that type and ignores this setting."] = "Куда отправляются фразы. Авто: пока вы в группе, фразы идут в чат группы (группа, рейд или подземелье), иначе - в \"Сказать\".\n\nЕсли у фразы в редакторе выбран свой тип (например, \"Крик\"), она всегда отправляется так и эту настройку не учитывает."
RU["One message per line. Several lines make a random group: one of them is sent each time. %t is your target's name, %q is the quest you are tracking. A line can also be a game command such as /dance: the character performs it instead of saying the text."] = "Одно сообщение на строку. Несколько строк - это случайная группа: каждый раз отправляется одна из них. %t - имя цели, %q - отслеживаемое задание. Строка может быть и игровой командой, например /dance: персонаж выполнит её вместо отправки текста."
RU["Auto"] = "Авто"
RU["Replace all phrases with the default set (%s)?\n\nAll your current phrases will be lost. Export them first if you want to keep them."] = "Заменить все фразы стандартным набором (%s)?\n\nВсе ваши текущие фразы будут потеряны. Если хотите их сохранить, сначала сделайте экспорт."
RU["Export"] = "Экспорт"
RU["Import"] = "Импорт"
RU["Export phrases"] = "Экспорт фраз"
RU["Import phrases"] = "Импорт фраз"
RU["All your phrases as one text. Press Ctrl+C to copy it and keep it somewhere safe."] = "Все ваши фразы одним текстом. Нажмите Ctrl+C, чтобы скопировать его, и сохраните в надёжном месте."
RU["Paste an exported text here (Ctrl+V). Importing replaces all your current phrases."] = "Вставьте сюда текст экспорта (Ctrl+V). Импорт заменит все ваши текущие фразы."
RU["This text is not a Forever Pie export."] = "Этот текст не является экспортом Forever Pie."
RU["Phrases were imported."] = "Фразы импортированы."
