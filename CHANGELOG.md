# Changelog

## 1.1 - 2026-11-22

### Added

- **Up to 5 wheels.** A column of dots on the left of the wheel shows which one is open; **LT** and **RT** switch between them, wrapping around. Every wheel has its own 24 slots, so one can hold phrases in your language, another the English set, a third your guild chat.
- **The wheel is remembered.** Unlike the LB / RB page, the wheel you switched to last is the one that opens next time, also after a relog.
- **Two wheels out of the box**: phrases in the game language and a new wheel of emotes (`/wave`, `/dance`, `/cheer` and 21 more). Wheels are added (up to 5) and deleted on the "Phrases" page.
- **Per-wheel settings**: a name shown above the wheel, and a channel for the phrases that have no type of their own. Set it to Guild and the whole wheel talks to the guild.
- **Reset per wheel**: "Reset wheel" fills only the wheel you are editing with the chosen set - any of the six languages, the emotes, or an empty wheel.
- In the mouse test mode (`/fpie toggle`) a click on a dot switches the wheel.

### Changed

- Export and import work with the wheel being edited. Exports made in 1.0 can still be imported.
- `/fpie reset` restores the two starting wheels.
- Phrases from 1.0 are kept: they become wheel 1, and the emotes wheel is added as wheel 2.

### Fixed

- **"ForeverPie has been blocked from an action only available to the Blizzard UI"** after changing settings, most often after resetting phrases or using the language menu. The settings pages no longer use the game's shared dropdown menus, confirmation popup and settings controls; all of their controls are now the addon's own.

### Русский

Добавлено:

- **До 5 колёс.** Слева от колеса - вертикальный ряд кружков, он показывает, какое колесо открыто; **LT** и **RT** переключают колёса по кругу. У каждого колеса свои 24 слота: на одном могут быть фразы на вашем языке, на другом английский набор, на третьем чат с гильдией.
- **Колесо запоминается.** В отличие от страницы LB / RB, в следующий раз откроется то колесо, которое было выбрано последним, в том числе после перезахода.
- **Два колеса сразу после установки**: фразы на языке игры и новое колесо эмоций (`/wave`, `/dance`, `/cheer` и ещё 21). Колёса добавляются (до 5) и удаляются на странице "Фразы".
- **Настройки колеса**: название, которое показывается над колесом, и канал для фраз без собственного типа. Выберите "Гильдия" - и всё колесо пишет в гильдию.
- **Сброс отдельного колеса**: "Сбросить колесо" заполняет выбранным набором только редактируемое колесо - любой из шести языков, эмоции или пустое колесо.
- В режиме проверки мышью (`/fpie toggle`) клик по кружку переключает колесо.

Изменено:

- Экспорт и импорт работают с редактируемым колесом. Экспорт из версии 1.0 по-прежнему импортируется.
- `/fpie reset` возвращает два стартовых колеса.
- Фразы из версии 1.0 сохраняются: они становятся колесом 1, а колесо эмоций добавляется вторым.

Исправлено:

- **"ForeverPie has been blocked from an action only available to the Blizzard UI"** после изменения настроек, чаще всего после сброса фраз и выбора языка в меню. Страницы настроек больше не используют общие с игрой выпадающие меню, окно подтверждения и элементы настроек: все элементы управления теперь собственные.

## 1.0

First release: one wheel of 24 slots (8 directions x 3 pages), opened with RB + R3, random phrase groups, emotes and commands, phrase type per slot, visual editor, default phrase sets in six languages, export and import.
