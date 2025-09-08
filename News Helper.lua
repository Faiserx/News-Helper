script_name('News Helper')
script_version('3.1')
script_description('Хелпер для СМИ')
script_authors('fa1ser, kvisk')

require "lib.moonloader"
local memory = require 'memory'
local inicfg = require 'inicfg'
local bit = require 'bit'
local ev =  require 'samp.events'
local vk = require 'vkeys'
local imgui = require 'mimgui'
local ffi = require 'ffi'
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local sampModule = getModuleHandle('samp.dll')
local dlstatus = require('moonloader').download_status

local mainPages, fastPages, eventPages = new.int(1), new.int(1), new.int(1) 
local buttonPages = {true, false, false, false} 
local buttonPagesEf = {true, false, false, false, false}

local ToU32 = imgui.ColorConvertFloat4ToU32
local sizeX, sizeY = getScreenResolution()
local rMain, rHelp, rSW, rFastM = new.bool(), new.bool(), new.bool(), new.bool()  
local inputDec = new.char[8192]() 
local inputAd, inputAdText, inputReplace, iptBind  = new.char[256](), new.char[256](), new.char[128](), new.char[128]() 
local iptEv, inputEvSet, iptNotepad = new.char[8192](), new.char[256](), new.char[4096]()
local ComboLanguage = new.int()
local setrank = imgui.new.int(1)
local WReason = imgui.new.char[100]()
local unwarn = imgui.new.char[100]()
local praise = imgui.new.char[100]()
local languageList = {'Английский', 'Французский', 'Испанский', 'Немецкий', 'Итальянский'}
local languageItems = imgui.new['const char*'][#languageList](languageList)

local id_name = '##Arizona News Helper '
local tag = '{008080}[News Helper]: {C0C0C0}'
local tmp = {['downKey'] = {}}
local ul_rus = {[string.char(168)] = string.char(184)}
local un_rus = {[string.char(184)] = string.char(168)}
for i = 192, 223 do local A, a = string.char(i), string.char(i + 32); ul_rus[A] = a; un_rus[a] = A end
local tAd = {false, '', false} 
local winSet = {0, {}}

update_state = false -- Если переменная == true, значит начнётся обновление.
update_found = false -- Если будет true, будет доступна команда /update.

local script_vers = tonumber(thisScript().version)
local script_vers_text = "3.1" -- Название нашей версии. В будущем будем её выводить пользователю.
local update_url = 'https://raw.githubusercontent.com/Faiserx/News-Helper/refs/heads/main/update.ini' -- Путь к ini файлу. Позже нам понадобиться.
local update_path = getWorkingDirectory() .. "/update.ini"
local script_url = 'https://raw.githubusercontent.com/Faiserx/News-Helper/refs/heads/main/News%20Helper.lua' -- Путь скрипту.
local script_path = thisScript().path

function check_update()
    downloadUrlToFile(update_url, update_path, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local iniData = inicfg.load(nil, update_path)
            if iniData and iniData.info and iniData.info.vers then
                if tonumber(iniData.info.vers) > script_vers then
                    sampAddChatMessage(u8:decode(tag .. 'Обнаружена новая версия скрипта: ' .. iniData.info.vers_text), -1)
                    update_found = true
				else
					sampAddChatMessage(u8:decode(tag .. 'Обновление не найдено.'), 0x008080)
                end
            else
                sampAddChatMessage(u8:decode(tag .. 'Ошибка проверки обновления. Попробуйте еще раз!'), 0x008080)
            end
            os.remove(update_path)
        end
    end)
end

function main()
	if not isSampLoaded() or not isSampfuncsLoaded() then return end
	
	loadVar() 

	while not isSampAvailable() do wait(100) end
	
	if not doesDirectoryExist('moonloader\\config\\News Helper') then createDirectory('moonloader\\config\\News Helper') end

	adcfg = loadFile('advertisement.cfg', {})
	helbincfg = loadFile('helpBind.cfg', newsHelpBind)
	autbincfg = loadFile('autoBind.cfg', newsAutoBind)
	keybincfg = loadFile('keyBind.cfg', newsKeyBind)
	setup = updateFile('settings.cfg', settingsSCR)
	esterscfg = updateFile('estersBind.cfg', newsHelpEsters)

	msgDelay = new.int(esterscfg.settings.delay) 
	newsDelay = new.int(setup.newsDelay) 
	iptTmp = {['notepad'] = {}} 

	sampRegisterChatCommand('nh', openMenu)

	RegisterCallback('menu', setup.keys.menu, openMenu)
	RegisterCallback('helpMenu', setup.keys.helpMenu, function () rHelp[0] = not rHelp[0] end)
	RegisterCallback('catchAd', setup.keys.catchAd)
	RegisterCallback('copyAd', setup.keys.copyAd)
	RegisterCallback('fastMenu', setup.keys.fastMenu, function () 
		if rFastM[0] then rFastM[0] = false end
		if isKeyDown(vk.VK_RBUTTON) then
			local st, getPlayerPed = getCharPlayerIsTargeting()
			if st and sampGetPlayerIdByCharHandle(getPlayerPed) then
				local id = select(2,sampGetPlayerIdByCharHandle(getPlayerPed))
				tmp.targetPlayer = {['Ped'] = getPlayerPed, ['id'] = id, ['nick'] = sampGetPlayerNickname(id), ['score'] = sampGetPlayerScore(id)}
				rFastM[0] = true
			end
		end
	end)

	while not sampIsLocalPlayerSpawned() do wait(10000) end
	sampAddChatMessage(u8:decode(tag .. 'Активация: {6495ED}/nh{C0C0C0}. Приятного пользования!'), 0x008080)
	while true do
		wait(0)
		if update_state then -- Если человек напишет /update и обновлени есть, начнётся скаачивание скрипта.
            downloadUrlToFile(script_url, script_path, function(id, status)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    sampAddChatMessage(u8:decode(tag..'Скрипт успешно обновлен, перезагружаюсь...'), 0x008080)
                end
            end)
            break
        end
		if wasKeyPressed(setup.keys.catchAd[2] or setup.keys.catchAd[1]) then
			for i=1, (#tmp.downKey or 0) do
				tmp.downKey[i] = false
			end
			tmp.downKey[#tmp.downKey+1] = true
			lua_thread.create(function (num)
				while isKeyDown(tmp.downKey[num] and (setup.keys.catchAd[2] or setup.keys.catchAd[1])) do
					if not ((sampIsDialogActive() and u8:encode(sampGetDialogCaption()) == '{BFBBBA}Редакция') or not sampIsDialogActive()) then break end
					sampSendChat('/newsredak')
					wait(10 + newsDelay[0] * 10 + sampGetPlayerPing(select(2,sampGetPlayerIdByCharHandle(PLAYER_PED))))
				end
			end, #tmp.downKey)
		end
		if sampIsDialogActive() and u8:encode(sampGetDialogCaption()) == '{BFBBBA}Редактирование' then
			if tAd[1] == nil then 
				sampSetCurrentDialogEditboxTextFix(u8:decode(tAd[2]))
				tAd[1] = false
			end
			if tAd[3] == true then
				sampSetCurrentDialogEditboxTextFix('')
				tAd[3] = false
			end
			if wasKeyPressed(setup.keys.copyAd[2] or setup.keys.copyAd[1]) then
				if u8:encode(sampGetDialogText()):find('Сообщение:%s+{33AA33}.+\n\n') then
					local textdown = u8:encode(sampGetDialogText()):match('Сообщение:%s+{33AA33}(.+)\n\n')
					sampSetCurrentDialogEditboxTextFix(u8:decode(textdown))
				end
			end
			local text = u8:encode(sampGetCurrentDialogEditboxText())
			for i=2, #autbincfg do
				local au = autbincfg[1][1]:regular() ..autbincfg[i][1]
				if text:find(au) then
					local gCur = getDialogCursorPos()
					sampSetCurrentDialogEditboxTextFix(u8:decode(tostring(text:gsub(au, autbincfg[i][2]))))
					setDialogCursorPos(gCur - utf8len(au:gsub('%%', '')) + utf8len(autbincfg[i][2]))
				end
			end
			for _, btn in ipairs(keybincfg) do
				if (#btn[1] == 1 and wasKeyPressed(btn[1][1])) or (#btn[1] == 2 and isKeyDown(btn[1][1]) and wasKeyPressed(btn[1][2])) then
                    local gCur = getDialogCursorPos()
					sampSetCurrentDialogEditboxTextFix(u8:decode(utf8sub(text, 1, gCur)..btn[2]..utf8sub(text, gCur+1)))
					setDialogCursorPos(gCur + utf8len(btn[2]))
				end
			end
		end
	end
end

imgui.OnInitialize(function()
	imgui.GetIO().MouseDrawCursor = true
	imgui.GetStyle().MouseCursorScale = 1
	local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 14.0, nil, glyph_ranges)
    s2 = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 12.0, _, glyph_ranges)
    s4 = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', 14.0, _, glyph_ranges)
	Style()

	wPaddX = imgui.GetStyle().WindowPadding.x
	wPaddY = imgui.GetStyle().WindowPadding.y
	SizScrol = imgui.GetStyle().ScrollbarSize
end)

imgui.OnFrame(function() return rMain[0] end,
	function(player)
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(800, 480))
		imgui.Begin('News Helper ##window_1', rMain, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoResize) -- + imgui.WindowFlags.NoMove + imgui.WindowFlags.AlwaysAutoResize
			imgui.SetCursorPos(imgui.ImVec2(3, 19))
			imgui.BeginChild(id_name .. 'child_window_1', imgui.ImVec2(imgui.GetWindowWidth() - 6, 30), false)
				imgui.TextCenter('News Helper')
			imgui.EndChild()
			imgui.SetCursorPos(imgui.ImVec2(3, 45))
			imgui.BeginChild(id_name .. 'child_window_2', imgui.ImVec2(170, imgui.GetWindowHeight() - 45), true)
				imgui.SetCursorPosX(28)
				imgui.SetCursorPosY(imgui.GetWindowHeight()/2/2)
				imgui.CustomMenu({
					'Главная',
					'Редакция',
					'Эфиры',
					'Настройки'
				}, mainPages, imgui.ImVec2(125, 32), 0.08, true, 9, false)
			imgui.EndChild()
			imgui.SameLine()
			imgui.SetCursorPosX(171)
			imgui.BeginChild(id_name .. 'child_window_3', imgui.ImVec2(imgui.GetWindowWidth() - 154, imgui.GetWindowHeight() - 45), true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
				if mainPages[0] == 1 then imgui.WindowMain()
				elseif mainPages[0] == 2 then imgui.LocalSettings()
				elseif mainPages[0] == 3 then imgui.LocalEsters()
				elseif mainPages[0] == 4 then imgui.ScrSettings() end	
			imgui.EndChild()
		imgui.End()
		imgui.SetMouseCursor(-1)
	end
)

imgui.OnFrame(function() return rHelp[0] end,
	function(player)
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 1.05, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(1, 0.5))
		imgui.SetNextWindowSizeConstraints(imgui.ImVec2(395, 500), imgui.ImVec2(395, 800))
		imgui.Begin('Help Ad ##window_2', rHelp, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
			for i=1, #helbincfg do
				if imgui.CollapsingHeader(helbincfg[i][1]..'##i'..i) then
					local tSize = imgui.GetWindowWidth()
					local wSize = imgui.GetWindowWidth() - 10
					for f=2, #helbincfg[i] do
						local TextSize = imgui.CalcTextSize(helbincfg[i][f][1]).x+20
						if wSize > tSize+TextSize+10 then
							tSize = tSize+TextSize+10
							imgui.SameLine()
						else tSize = TextSize+10 end
						if imgui.Button(helbincfg[i][f][1]..'##if'..i..f, imgui.ImVec2(TextSize, 30)) then
							if helbincfg[i][f][2]:find('*') then
								sampSetCurrentDialogEditboxTextFix(u8:decode(tostring(helbincfg[i][f][2]:gsub('*', ''))))
								setDialogCursorPos(utf8len(helbincfg[i][f][2]:match('(.-)*')))
							else
								sampSetCurrentDialogEditboxTextFix(u8:decode(helbincfg[i][f][2]))
								if helbincfg[i][f][2]:find('""') then setDialogCursorPos(utf8len(helbincfg[i][f][2]:match('(.-)""')) + 1) end
							end 
						end
						imgui.Tooltip(helbincfg[i][f][2])
					end
				end
			end
		imgui.End()
		imgui.SetMouseCursor(-1)
	end
)

imgui.OnFrame(function() return rFastM[0] end,
	function(player)
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 1.1, sizeY / 1.2), imgui.Cond.FirstUseEver, imgui.ImVec2(1, 1))
		imgui.SetNextWindowSize(imgui.ImVec2(500, 320), imgui.Cond.FirstUseEver + imgui.WindowFlags.NoResize)
		imgui.Begin('Меню быстрого доступа ##window_4', rFastM, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar --[[+ imgui.WindowFlags.NoTitleBar]]) -- + imgui.WindowFlags.AlwaysAutoResize imgui.TabBarFlags.NoCloseWithMiddleMouseButton
			imgui.SetCursorPosY(19)
			imgui.BeginChild(id_name .. 'child_window_6', imgui.ImVec2(280, 310), false)
				imgui.SetCursorPosY(15)
				if fastPages[0] == 1 then imgui.FmInterviews()
				elseif fastPages[0] == 2 then imgui.AdvRules()
				elseif fastPages[0] == 3 then imgui.NewsRules()
				elseif fastPages[0] == 4 then imgui.LeaderActions() end
				imgui.NewLine()
			imgui.EndChild()
			imgui.SameLine(0, 0)
			imgui.BeginChild(id_name .. 'child_window_7', imgui.ImVec2(220, 310), true)
				imgui.TextCenter(tmp.rolePlay and '{CC0000}Ждём работает бинд' or ' ')
				imgui.TextCenter('Имя: '..tmp.targetPlayer.nick)
				imgui.TextCenter('Лет в штате: '..tmp.targetPlayer.score)
				imgui.NewLine()
				imgui.Separator()
				imgui.NewLine()
				imgui.SetCursorPosX(46)
				imgui.CustomMenu({'Собеседование', 'Проверка ПРО',  'Проверка ППЭ', 'Лидерские действия'}, fastPages, imgui.ImVec2(120, 30), 0.08, true, 15)
			imgui.EndChild()
		imgui.End()
		imgui.SetMouseCursor(-1)
	end
)

function ev.onShowDialog(id, style, title, button1, button2, text)
	tmp.lastDialog = {['id'] = id, ['style'] = style, ['title'] = u8:encode(title), ['button1'] = button1, ['button2'] = button2, ['text'] = u8:encode(text)}

	if tmp.fmActi and u8:encode(title) == '{BFBBBA}{73B461}Активные предложения' then 
		if style == 2 then tmp.fmActi = nil; lua_thread.create(function () wait(10) sampSendDialogResponse(id, 1, 5, nil) end) end
		return false
	end

	if u8:encode(title) == '{BFBBBA}Редактирование' then
		local ad = u8:encode(text):match('Сообщение:%c{%x+}(.+)%s+{%x+}Отредактируйте рекламу в нужный формат'):gsub('%s*\n', ''):gsub('\\', '/') 
		text = text..'										.'
		for i=1, #adcfg do
			if adcfg[i].ad == ad then
				tAd = {nil, adcfg[i].text, false}
				return {id, style, title, button1, button2, text}
			end
		end
		tAd = {true, ad, true}
		return {id, style, title, button1, button2, text}
	end
end
function ev.onSendDialogResponse(id, button, list, input)
	if button == 1 and list == 65535 and tAd[1] and input ~= '' then
		adcfg[#adcfg + 1] = {['ad'] = tAd[2], ['text'] = u8:encode(input):gsub('%s+', ' '):gsub('\\', '/')}
		saveFile('advertisement.cfg', adcfg)
	end
	tAd = {false, '', false}
end
function ev.onServerMessage(color, text)
	if tmp.fmActi and color == -1104335361 and u8:encode(text) == '[Ошибка] {ffffff}У Вас нет в данный момент активных предложений, попробуйте позже.' then
		tmp.fmActi = nil
		sampAddChatMessage(u8:decode(tag..'Никто не предлагал свои документы!'), -1)
		return false
	end
end
function imgui.MeNotepad(arrName, size)
	imgui.TextCenter(' Блокнот \\ Заметки')
	local txtNotp = esterscfg.events[arrName].notepad or ''
	imgui.StrCopy(iptNotepad, iptTmp.notepad[arrName] or txtNotp)
	if imgui.InputTextMultiline(id_name..'input_multiline_1', iptNotepad, sizeof(iptNotepad) - 1, size) then
		iptTmp.notepad[arrName] = str(iptNotepad)
	end
	if  not imgui.IsItemActive() and txtNotp ~= str(iptNotepad) then
		esterscfg.events[arrName].notepad = iptTmp.notepad[arrName]
		saveFile('estersBind.cfg', esterscfg)
	end
end

function imgui.WindowMain() 
	imgui.BeginChild(id_name..'child_7', imgui.ImVec2(imgui.GetWindowWidth() - 80, 180), false, 0)
		imgui.TextWrapped('Скрипт-помощник для сотрудников СМИ.\nЭтот скрипт предназначен исключительно для оказания поддержки, а не для автоматизации процессов. Он не выполняет функции "бота" и ориентирован на соответствие правилам. В большинстве случаев его использование допускается на серверах, однако перед применением рекомендуется уточнить разрешение у главных администраторов. Разработчик не несёт ответственности за возможную блокировку аккаунта.\nЗа основу взят скрипт от kvisk.')
		if imgui.Button('Проверить обновления', imgui.ImVec2(225,30)) then
			check_update()
		end
		imgui.SameLine()
		if update_found then
			if imgui.Button('Обновить', imgui.ImVec2(225,30)) then
				update_state = true
			end
		end
	imgui.EndChild()
end

function imgui.LocalSettings() 
	imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 112)
	if imgui.HeaderButton(buttonPages[1], ' Объявления ') then
		buttonPages = {true, false, false, false}
	end
	imgui.Tooltip('Редактирование сохранённых объявлений')
	imgui.SameLine()
	if imgui.HeaderButton(buttonPages[2], ' Автозамена ') then
		buttonPages = {false, true, false, false}
	end
	imgui.Tooltip('Настройка автозамены')
	imgui.SameLine()
	if imgui.HeaderButton(buttonPages[3], ' Быстрые клавиши ') then
		buttonPages = {false, false, true, false}
	end
	imgui.Tooltip('Настройка бинд-клавиш')
	imgui.SetCursorPosY(32)
	if buttonPages[1] then imgui.Advertisement()
	elseif buttonPages[2] then imgui.AutoBind()
	elseif buttonPages[3] then imgui.AutoBindButton() end
end
function imgui.Advertisement() 
	imgui.StrCopy(inputReplace, tmp.field and tmp.field or '')
	imgui.SetCursorPosX(6)
	imgui.SetCursorPosY(40)
	imgui.PushItemWidth(imgui.GetWindowWidth() - 120)
	if imgui.InputTextWithHint(id_name..'input_10', 'Поиск..', inputReplace, sizeof(inputReplace) - 1, imgui.InputTextFlags.AutoSelectAll) then
		if tmp.field ~= str(inputReplace) then
			imgui.StrCopy(inputReplace, tostring(str(inputReplace):gsub('%.', ''):gsub('%(', ''):gsub('%)', ''):gsub('%%', ''):gsub('%+', ''):gsub('%-', ''):gsub('%*', '')))
			tmp.field = str(inputReplace)
		end
	end
	imgui.SameLine(0, 4)
	if imgui.Button('Очистить'..id_name..'button_6', imgui.ImVec2(80,0)) then
		tmp.field = nil
	end
	imgui.BeginChild(id_name..'child_window_4', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 60), false)
		local listAdvertisement = function (i, tbl)
			local tbl = tbl or {}
			imgui.SameTable(i, 'ad', function()
				imgui.StrCopy(inputAd, adcfg[i].ad)
				imgui.StrCopy(inputAdText, adcfg[i].text)
			end)
			if tmp.brea then tmp.brea = nil return true end
			imgui.SetCursorPosX(8)
			local addText = '{A52A2A}['..i..']{STANDART} '
			local subAdText = adcfg[i].ad
			local subText = adcfg[i].text
			for k=1, #tbl do
				local strInd = string.nlower(subAdText):find(tbl[k])
				local tStr = strInd and subAdText:sub(strInd, strInd + tbl[k]:len() - 1) or nil
				subAdText = tStr and subAdText:gsub(tStr, '{00cc99EE}'..tStr..'{STANDART}', 1) or subAdText
				local strInd, tStr = nil, nil
				local strInd = string.nlower(subText):find(tbl[k])
				local tStr = strInd and subText:sub(strInd, strInd + tbl[k]:len() - 1) or nil
				subText = tStr and subText:gsub(tStr, '{00cc99EE}'..tStr..'{STANDART}', 1) or subText
			end
			subAdText = addText..subAdText
			while imgui.CalcTextSize(tostring(subAdText:hexsub())).x > imgui.GetWindowWidth() / 2 - 22 do 
				subAdText = subAdText:sub(1, subAdText:len() - 2)
			end
			imgui.RenderText(string.len((addText..adcfg[i].ad):hexsub()) == #subAdText:hexsub() and subAdText or subAdText..'..')
			imgui.Tooltip(adcfg[i].ad)
			imgui.SameLine()
			imgui.SetCursorPosX(imgui.GetWindowWidth() / 2)
			imgui.RenderText(subText)
			imgui.Tooltip(adcfg[i].text)
		end

		imgui.PushFont(s2)

		local adstr = math.floor(imgui.GetScrollY() / 16)
		local admax = math.floor(imgui.GetWindowHeight() / 16) + 2 + adstr

		if string.len(tostring(u8:decode(str(inputReplace)):gsub('%s+', ''))) <= 1 then
			for i=1, #adcfg do
				if i >= adstr and i <= admax then
					if listAdvertisement(i) then break end
				else
					imgui.Text('')
				end
			end
		else 
			local adMstr = 1
			for i = 1, #adcfg do
				local stlin = {(adcfg[i].ad..' '..adcfg[i].text):nlower(), 0, 0, {}}
				for search in string.gmatch(string.nlower(str(inputReplace)), '[^%s]+') do
					stlin[2] = stlin[2] + 1
					if utf8len(search) < 2 then stlin[3] = stlin[3] + 1 end
					if utf8len(search) >= 2 and string.match(stlin[1], '[%s%p]('..search..'[%S]*)') then
						stlin[3] = stlin[3] + 1; stlin[4][#stlin[4] + 1] = search
					end
				end
				if stlin[2] == stlin[3] then
					if adMstr >= adstr and adMstr <= admax then
						if listAdvertisement(i, stlin[4]) then break end
					else
						imgui.Text('')
					end
					adMstr = adMstr + 1
				end
			end
		end
		imgui.PopFont()

	imgui.EndChild()
end
function imgui.AutoBind()
	imgui.SetCursorPos(imgui.ImVec2(10,45))
	imgui.BeginChild(id_name..'child_window_5', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		imgui.SetCursorPosY(5)
		imgui.TextStart('{ffff99BB}Специальный символ')
		imgui.SameLine()
		imgui.StrCopy(inputReplace, autbincfg[1][1])
		imgui.PushItemWidth(30)
		imgui.SetCursorPosY(2)
		if imgui.InputText(id_name..'input_S1', inputReplace, sizeof(inputReplace) - 1, imgui.InputTextFlags.AutoSelectAll) then
			iptTmp.iptSign = str(inputReplace):gsub('%%', '')
		end
		if not imgui.IsItemActive() and iptTmp.iptSign and iptTmp.iptSign ~= '' and iptTmp.iptSign ~= autbincfg[1][1] then
			imgui.StrCopy(inputReplace, iptTmp.iptSign)
			autbincfg[1][1] = iptTmp.iptSign
			saveFile('autoBind.cfg', autbincfg)
		end
		imgui.SameLine()
		imgui.SetCursorPosY(-3)
		imgui.TextStart('{FFFFFF99}(?)')
		imgui.Tooltip('Символ с которого начинается\nкоманда для Авто-Замены')

		imgui.SameLine()
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 375, 0))
		imgui.StrCopy(inputAd, winSet[2][3] or '')
		imgui.PushItemWidth(55)
		if imgui.InputText(id_name..'input_S3', inputAd, sizeof(inputAd) - 1) then
			if str(inputAd) ~= winSet[2][3] then
				winSet[2][3] = str(inputAd)
			end
		end
		imgui.SameLine()
		imgui.StrCopy(inputAdText, winSet[2][4] or '')
		imgui.PushItemWidth(155)
		if imgui.InputText(id_name..'input_S4', inputAdText, sizeof(inputAdText) - 1) then
			if str(inputAdText) ~= winSet[2][4] then
				winSet[2][4] = str(inputAdText)
			end
		end
		imgui.SameLine()
		if imgui.Button('Добавить'..id_name..'button_S2', imgui.ImVec2(70,30)) and winSet[2][3] and winSet[2][4] then
			if winSet[2][3] ~= '' and winSet[2][4] ~= '' then
				autbincfg[#autbincfg + 1] = {winSet[2][3], winSet[2][4]}
				winSet[2][3], winSet[2][4] = nil, nil
				saveFile('autoBind.cfg', autbincfg)
			end
		end
		imgui.Tooltip('Добавить новую авто-замену\n\n*Поля не должны быть пустыми')
		
		imgui.TextCenter('{F9FFFF88}Микрокоманды для автозамены')
		imgui.SetCursorPos(imgui.ImVec2(-30, imgui.GetCursorPosY()))
		imgui.BeginChild(id_name..'child_6', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() - 42), false, imgui.WindowFlags.NoScrollbar)
			local centSize = (imgui.GetWindowWidth() - (math.floor((imgui.GetWindowWidth() + 6) / 270) * 270 - 6)) / 2
			imgui.SetCursorPosX(centSize)
			for i=2, #autbincfg*2-1 do
				local m = (math.fmod(i, 2) == 0 and 1 or 2)
				i = (i+math.fmod(i,2))/2 + (math.fmod(i,2) == 1 and 0 or 1)
				imgui.StrCopy(inputReplace, autbincfg[i][m])
				imgui.PushItemWidth(m == 1 and 55 or 155)
				if imgui.InputText(id_name..'input_S2_'..i..m, inputReplace, sizeof(inputReplace) - 1) then
					if str(inputReplace) ~= '' and str(inputReplace) ~= autbincfg[i][m] then
						autbincfg[i][m] = str(inputReplace)
						saveFile('autoBind.cfg', autbincfg)
					end
				end
				imgui.StrCopy(inputReplace, autbincfg[i][1])
				imgui.SameLine(0)
				if m == 2 then
					if imgui.Button('Х'..id_name..'button_S_'..i, imgui.ImVec2(30,30)) then
						table.remove(autbincfg, i)
						saveFile('autoBind.cfg', autbincfg)
						break
					end
					imgui.Tooltip('Удалить')
					if math.fmod(i-1, math.floor((imgui.GetWindowWidth() + 6) / 270)) ~= 0 then 
						imgui.SameLine()
						imgui.Text(i ~= #autbincfg and '|' or '')
						imgui.SameLine()
					else 
						imgui.SetCursorPosX(centSize)
					end
				end
			end
		imgui.EndChild()

	imgui.EndChild()
end
function imgui.AutoBindButton()
	local centSize = (imgui.GetWindowWidth() - (math.floor((imgui.GetWindowWidth() + 6) / 270) * 270 - 6)) / 2
	imgui.BeginChild(id_name..'child_window_25', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		imgui.SetCursorPos(imgui.ImVec2(150, imgui.GetCursorPosY() + 10))
		hotkey.List['addNewBtn'] = hotkey.List['addNewBtn'] or {['keys'] = {}, ['callback'] = nil}
		KeyEditor('addNewBtn', nil, imgui.ImVec2(80,30))

		imgui.SameLine()
		imgui.StrCopy(iptBind, iptTmp.iptBind or '')
		imgui.PushItemWidth(130)
		imgui.InputText(id_name..'input_Ss3', iptBind, sizeof(iptBind) - 1)
		if not imgui.IsItemActive() and iptTmp.iptBind ~= str(iptBind) then
			iptTmp.iptBind = str(iptBind)
		end

		imgui.SameLine()
		if imgui.Button('Добавить'..id_name..'button_Ss2', imgui.ImVec2(70,30)) then
			if hotkey.List['addNewBtn'].keys[1] and iptTmp.iptBind ~= '' then
				table.insert(keybincfg, {hotkey.List['addNewBtn'].keys, iptTmp.iptBind})
				iptTmp.iptBind = nil
				hotkey.List['addNewBtn'].keys = {}
				saveFile('keyBind.cfg', keybincfg)
			end
		end
		imgui.Tooltip('Добавить новый биндер\n\n*Поля не должны быть пустыми')

		imgui.TextCenter('{F9FFFF88}Настройки кнопок для биндера')
		imgui.BeginChild(id_name..'child_window_26', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() - 42), false)
			local centSize = (imgui.GetWindowWidth() - (math.floor((imgui.GetWindowWidth() + 6) / 270) * 270 - 6)) / 2
			--imgui.SetCursorPos(imgui.ImVec2(0, imgui.GetCursorPosY()))
			imgui.SetCursorPos(imgui.ImVec2(0, imgui.GetCursorPosY()))
			for i, btn in ipairs(keybincfg) do
				
				hotkey.List['bindCfg_'..i] = hotkey.List['bindCfg_'..i] or {['keys'] = btn[1], ['callback'] = nil}
				if KeyEditor('bindCfg_'..i, nil, imgui.ImVec2(80,30)) then
					keybincfg[i][1] = hotkey.List['bindCfg_'..i].keys
					saveFile('keyBind.cfg', keybincfg)
				end

				imgui.SameLine(0)
				imgui.StrCopy(iptBind, btn[2])
				imgui.PushItemWidth(130)
				imgui.InputText(id_name..'input_BindB_'..i, iptBind, sizeof(iptBind) - 1)
				if not imgui.IsItemActive() and btn[2] and btn[2] ~= str(iptBind) then
					keybincfg[i][2] = str(iptBind)
					saveFile('keyBind.cfg', keybincfg)
				end

				imgui.SameLine()
				if imgui.Button('Х'..id_name..'button_Sb_'..i, imgui.ImVec2(30,30)) then
					table.remove(keybincfg, i)
					clearButtons()
					saveFile('keyBind.cfg', keybincfg)
					break
				end
				imgui.Tooltip('Удалить')

				if math.fmod(i, math.floor((imgui.GetWindowWidth() + 6) / 270)) ~= 0 then 
					imgui.SameLine()
					imgui.Text(i ~= #keybincfg and '|' or '')
					imgui.SameLine()
				else 
					imgui.SetCursorPos(imgui.ImVec2(0, imgui.GetCursorPosY()))
				end
			end
		imgui.EndChild()
	imgui.EndChild()

end
function imgui.LocalEsters()
	imgui.SetCursorPosX(18)
	if imgui.HeaderButton(buttonPagesEf[4], ' Настройки ') then
		buttonPagesEf = {false, false, false, true}
	end
	imgui.SameLine()
	imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 132)
	if imgui.HeaderButton(buttonPagesEf[1], '  Мероприятия ') then
		buttonPagesEf = {true, false, false, false}
	end
	imgui.SameLine()
	if imgui.HeaderButton(buttonPagesEf[2], ' Реклама ') then
		buttonPagesEf = {false, true, false, false}
	end
	imgui.SameLine()
	if imgui.HeaderButton(buttonPagesEf[3], ' Интервью ') then
		buttonPagesEf = {false, false, true, false}
	end
	imgui.SetCursorPosY(32)

	if buttonPagesEf[1] then imgui.Events()
	elseif buttonPagesEf[2] then imgui.Text('Скоро..')
	elseif buttonPagesEf[3] then imgui.Text('Скоро..')
	elseif buttonPagesEf[4] then imgui.EventsSetting() end
end
function imgui.EventsSetting()
	imgui.SetCursorPosY(40)
	imgui.BeginChild(id_name..'child_window_13', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		for i, tag in ipairs({{'name','Имя и фамилия'},{'duty','Должность (с маленькой буквы)'},{'tagCNN','Тег в "/d" (без "[]")'},{'city','Город в котом СМИ'},{'server','Имя штата (сервер)'},{'music','Музыкальная заставка в эфире'}}) do
			imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 160)
			imgui.PushItemWidth(180)
			imgui.StrCopy(inputEvSet, esterscfg.settings[tag[1]])
			imgui.InputText(id_name..'input_Es1_'..i, inputEvSet, sizeof(inputEvSet) - 1)
			if not imgui.IsItemActive() and esterscfg.settings[tag[1]] ~= str(inputEvSet) then
				esterscfg.settings[tag[1]] = str(inputEvSet)
				saveFile('estersBind.cfg', esterscfg)
			end
			if imgui.CalcTextSize(inputEvSet).x > 176 then
				imgui.Tooltip(str(inputEvSet))
			end
			imgui.SameLine()
			imgui.Text(tag[2])
		end
		imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 160)
		imgui.SliderInt(' Задержка для отправки сообщений'..id_name..'slider_1', msgDelay, 1, 12, '%d sec')
		if not imgui.IsItemActive() and esterscfg.settings.delay ~= msgDelay[0] then
			if msgDelay[0] < 1 or msgDelay[0] > 12 then
				msgDelay[0] = esterscfg.settings.delay
				return
			end
			esterscfg.settings.delay = msgDelay[0]
			saveFile('estersBind.cfg', esterscfg)
		end
	imgui.EndChild()
end
function imgui.Events()
	imgui.BeginChild(id_name..'child_window_8', imgui.ImVec2(imgui.GetWindowWidth() - 12, imgui.GetWindowHeight() - 40), false)
		imgui.BeginChild(id_name .. 'child_window_9', imgui.ImVec2(88, imgui.GetWindowHeight()), false, imgui.WindowFlags.NoScrollbar)
			imgui.SetCursorPosX(1)
			imgui.SetCursorPosY(10)
			imgui.CustomMenu({
				' Описание',
				' Математика',
				' Столицы',
				' Прятки',
				' Приветы',
				' Химические\n   элементы',
				' Переводчики',
				' Зеркало',
			}, eventPages, imgui.ImVec2(88, 32), 0.08, true, 0, {
				'',
				'Математика - ведущий называет математический\nпример, а слушатели дают ответ. (Пример: 10+10-20)',
				'Столицы - ведущий называет страну в любой точке\nмира, а граждане должны ответить её столицу.\n(Пример: США - Вашингтон)',
				'Прятки - ведущий прячется в одной из точек\nштата, а задача слушателей найти его с\nпомощью указанных подсказок.',
				'Приветы и поздравления - слушатели звонят\nпо номеру радиостанции и передают приветы\nзнакомым, а также поздравляют их со\nзначимыми событиями.',
				'Химические элементы - ведущий называет\nкакой-либо хим. элемент из периодической\nтаблицы Д.И. Менделеева, а граждани дают\nответ. (Пример: Zn - цинк)', 
				'Переводчик - ведущий называет слова на\nанглийском / японском / итальянском языках,\nа задача слушателей написать правильный\nперевод на русский в СМС - сообщении\nна номер радиостанции.',
				'Зеркало - ведущий называет слово, а\nслушатели должны прислать ответ на\nномер радиостанции в виде\nСМС - сообщения с написанием этого\nслова задом наперёд.',
				'Автор - ведущий называет книгу, участник\nдолжен отгадать кто её написал.\n(Пример: «Код да Винчи» - ответ Дэн Браун,\n«Истории о том о сём» - ответ Том Хэнкс.)',
				'Угадай знаменитость - ведущий даёт описание\nкакой-нибудь знаменитой личности штата, а\nзадача слушателей назвать его/её имя и\nфамилию в СМС - сообщении на номер радиостанции.',
				'Знаток автомобилей - ведущий описывает\nмодель автомобиля, его характеристики, а\nслушатели должны написать название авто\nв СМС - сообщении на номер радиостанции.', 
				'Крокодил - Ведущий загадывает слово\nи описывает его, а участник должен\nугадать, что это за слово.', 
				'О спорте - ведущий задаёт вопросы на\nспортивную тематику, а задача\nслушателей написать верный ответ\nв СМС-сообщении на вопрос или\nпозвонить на номер радиостанции.',
				'Меломан - ведущий задаёт вопросы на тему\nмузыки, а задача слушателей написать верный\nответ в СМС - сообщении на вопрос или\nпозвонить на номер радиостанции.',
				'Правда или ложь? - ведущий задаёт вопрос\nо верном или неверном утверждении, а\nслушатели должны написать\nСМС-сообщение / позвонить на номер\nрадиостанции, верно ли утверждение или же нет.', 
				'Stand-Up - Подготовка небольших шуток,\nс трансляцией их в эфир.\nРазвлекать слушателей всеми силами,\nимпровизировать, принимать звонки\nи по-доброму подшучивать над\nдозвонившимися, рассказывая\nразличные истории.'
			})
		imgui.EndChild()
		imgui.SameLine()
		imgui.SetCursorPosX(100)
		imgui.BeginChild(id_name .. 'child_window_10', imgui.ImVec2(imgui.GetWindowWidth() - 100, imgui.GetWindowHeight()), false, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
			if eventPages[0] == 1 then imgui.EventDescription()
				elseif eventPages[0] == 2 then imgui.Mathematics()
				elseif eventPages[0] == 3 then imgui.Capitals()
				elseif eventPages[0] == 4 then imgui.ToHide()
				elseif eventPages[0] == 5 then imgui.Greetings()
				elseif eventPages[0] == 6 then imgui.ChemicElements()
				elseif eventPages[0] == 7 then imgui.Interpreter()
				elseif eventPages[0] == 8 then imgui.Mirror()
				elseif eventPages[0] == 9 then imgui.Text('Скоро..')
				elseif eventPages[0] == 10 then imgui.Text('Скоро..')
				elseif eventPages[0] == 11 then imgui.Text('Скоро..')
				elseif eventPages[0] == 12 then imgui.Text('Скоро..')
				elseif eventPages[0] == 13 then imgui.Text('Скоро..')
				elseif eventPages[0] == 14 then imgui.Text('Скоро..')
				elseif eventPages[0] == 15 then imgui.Text('Скоро..')
				elseif eventPages[0] == 16 then imgui.Text('Скоро..')
				elseif eventPages[0] == 17 then imgui.Text('Скоро..') 
			end
		imgui.EndChild()
	imgui.EndChild()

end
function imgui.EventDescription()
	imgui.NewLine()
	imgui.SetCursorPosX(20)
	imgui.BeginChild(id_name..'child_window_23', imgui.ImVec2(imgui.GetWindowWidth() - 40, imgui.GetWindowHeight() - 38), false)
		imgui.TextWrapped('Эфиры находятся в тестовом варианте, вы можете их использовать. Однака сначала проверяйте текст перед использованием его в эфире! На всех серверах разные правила и теги.')
		imgui.TextStart('{b5e530cb}Вы можете изменять текст эфиров! Теги вы тоже можете изменять!')
		imgui.NewLine()
		imgui.TextWrapped('Если вы столкнетесь с багами или вам будет не удобно использовать данный биндер, обязательно напиши, что именно тут не так!')
		imgui.SetCursorPosY(imgui.GetWindowHeight() - 30)
	imgui.EndChild()
end
function imgui.Mathematics()
	imgui.BeginChild(id_name..'child_window_11', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.mathem, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	--imgui.SameLine()
	imgui.SetCursorPos(imgui.ImVec2(335, 0))
	imgui.BeginChild(id_name..'child_window_12', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.TextCenter('Калькулятор')

		imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 6))
		imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 4 - 18)
		local iptCal1 = new.char[256]('')
		imgui.StrCopy(iptCal1, iptTmp.iptCal1 or '')
		if imgui.InputTextWithHint(id_name..'input_13', '10+2^(10/2)*1.5', iptCal1, sizeof(iptCal1) - 1, imgui.InputTextFlags.CallbackAlways, callbacks.calc) then
			iptTmp.iptCal1 = str(iptCal1):gsub('[^%d%+%-%^%/%(%)%*%s%.]+', '')
			local calc = load('return '..iptTmp.iptCal1);
			local resul = tostring(calc and calc() or 'Ошибка')
			if resul == 'nan' or resul == 'inf' then resul = ' /0 = err' end
			iptTmp.iptCal2 = (iptTmp.iptCal1 ~= '' and resul or '')
		end
		imgui.Tooltip('Введите математический\nпример, доступные символы:\n\n + прибавить\n - вычесть\n * умножить\n / разделить (наклон важен!)\n ^ возвести в степень\n () для первенства выражения')

		imgui.SameLine(nil, 4)
		if imgui.Button('Х'..id_name..'button_12', imgui.ImVec2(23,26)) then
			iptTmp.iptCal1 = nil
			iptTmp.iptCal2 = nil
		end
		imgui.Tooltip('Очистить')

		imgui.SetCursorPos(imgui.ImVec2(10, imgui.GetCursorPosY()+5))
		imgui.Text('Результат')
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX()+75, imgui.GetCursorPosY()-25))
		imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 67)
		local iptCal2 = new.char[256]('')
		imgui.StrCopy(iptCal2, iptTmp.iptCal2 or '')
		imgui.InputText(id_name..'input_14', iptCal2, sizeof(iptCal2) - 1, imgui.InputTextFlags.ReadOnly)

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('mathem', imgui.ImVec2(170, 200))
	imgui.EndChild()
end
function imgui.Capitals()
	imgui.BeginChild(id_name..'child_window_27', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.capitals, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_28', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		local capitalsCities = {
			'Австрия = Вена', 'Аргентина = Буэнос-Айрес', 'Армения = Ереван', 'Белоруссия = Минск', 'Бельгия = Брюссель', 'Болгария = София',
			'Великобритания = Лондон', 'Вьетнам = Ханой', 'Германия = Берлин', 'Греция = Афины', 'Грузия = Тбилиси', 'Дания = Копенгаген',
			'Египет = Каир', 'Индия = Нью-Дели', 'Ирак = Багдад', 'Иран = Тегеран', 'Испания = Мадрид', 'Канада = Оттава', 'Китай = Пекин',
			'Куба = Гавана', 'Латвия = Рига', 'Литва = Вильнюс', 'Мексика = Мехико', 'Молдавия = Кишинев', 'Монголия = Улан-Батор',
			'Нидерланды (Голландия) = Амстердам', 'Норвегия = Осло', 'Перу = Лима', 'Польша = Варшава', 'Португалия = Лиссабон',
			'Россия = Москва', 'США = Вашингтон', 'Сирия = Дамаск', 'Словакия = Братислава', 'Словения = Любляна', 'Тунис = Тунис',
			'Турция = Анкара', 'Украина = Киев', 'Уругвай = Монтевидео', 'Финляндия = Хельсинки', 'Франция = Париж', 'Хорватия = Загреб',
			'Чехия = Прага', 'Чили = Сантьяго', 'Швейцария = Берн', 'Швеция = Стокгольм', 'Эстония = Таллин', 'Япония = Токио'
		}
		imgui.BeginChild(id_name..'child_window_24', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() / 2 - 10), false)
			for i, capital in ipairs(capitalsCities) do
				local txtChat = '/news '..esterscfg.events.capitals.tag..capital:sub(1, capital:find(' ')-1)..' = ?'
				if imgui.Selectable(id_name..'selec_table_HIM_'..i, nil) then
					sampSetChatInputEnabled(true)
					sampSetChatInputText(u8:decode(txtChat))
				end
				imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
				imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - 80)
				imgui.Text(capital)
			end
		imgui.EndChild()

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)


		imgui.MeNotepad('capitals', imgui.ImVec2(150, 150))
	imgui.EndChild()
end
function imgui.ToHide()
	imgui.BeginChild(id_name..'child_window_19', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 170)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(125)
		local iptPhrase = new.char[256]('')
		imgui.StrCopy(iptPhrase, iptTmp.iptPhrase or '')
		if imgui.InputTextWithHint(id_name..'input_10', 'Вкусная клубника', iptPhrase, sizeof(iptPhrase) - 1) then
			iptTmp.iptPhrase = str(iptPhrase)
		end
		imgui.SameLine()
		imgui.Text('Фраза')
		imgui.Tooltip('Фраза, которую человек должен\nсказать как приблизится к вам!')

		imgui.SameLine()

		imgui.SetCursorPosX(imgui.GetWindowWidth() - 170)
		imgui.Text('Время')
		imgui.Tooltip('Сколько будет идти данный эфир?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptTime = new.char[256]('')
		imgui.StrCopy(iptTime, iptTmp.iptTime or '50')
		if imgui.InputText(id_name..'input_12', iptTime, sizeof(iptTime) - 1) then
			iptTmp.iptTime = str(iptTime)
		end

		imgui.RenderButtonEf(esterscfg.events.tohide, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указана {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'time', iptTmp.iptTime or '50', '40', 'У вас не указанно сколько {fead00}времени{C0C0C0} будет этот эфир!', 'Длительность эфира'},
			{'phrase', iptTmp.iptPhrase, 'Вкусная клубника', 'У вас не указана {fead00}фраза{C0C0C0} которую нужно сказать!', 'Фраза которую нужно озвучить'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()
	imgui.SetCursorPosX(330)
	imgui.BeginChild(id_name..'child_window_20', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.MeNotepad('tohide', imgui.ImVec2(175, 300))
	imgui.EndChild()
end
function imgui.Greetings()
	imgui.BeginChild(id_name..'child_window_19', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID передает')
		imgui.Tooltip('ID человека, который передает привет')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Время')
		imgui.Tooltip('Сколько будет идти данный эфир?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptTime = new.char[256]('')
		imgui.StrCopy(iptTime, iptTmp.iptTime or '15')
		if imgui.InputText(id_name..'input_12', iptTime, sizeof(iptTime) - 1) then
			iptTmp.iptTime = str(iptTime)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptToId = new.char[256]('')
		imgui.StrCopy(iptToId, iptTmp.iptToId or '')
		if imgui.InputText(id_name..'input_10', iptToId, sizeof(iptToId) - 1, 16) then
			iptTmp.iptToId = str(iptToId)
			tmp.evNick2 = nil
			if tonumber(str(iptToId)) and sampIsPlayerConnected(str(iptToId)) then
				tmp.evNick2 = sampGetPlayerNickname(str(iptToId)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID получает')
		imgui.Tooltip('ID человека, который получает привет')

		imgui.RenderButtonEf(esterscfg.events.greet, {
			{'time', iptTmp.iptTime or '15', '30', 'У вас не указанно сколько {fead00}времени{C0C0C0} будет этот эфир!', 'Время длительности эфира'},
			{'toID', tmp.evNick2, 'Sharky Flint', 'У вас не указанно {fead00}ID кому{C0C0C0} передают привет!', 'Имя КОМУ передают привет'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID кто{C0C0C0} передает привет!', 'Имя КТО передает привет'}
		}, {
			{'Передать привет', true, function (txt, tCon)
				for i, lTags in ipairs(tCon) do
					if lTags[1] == 'ID' and not lTags[2] then
						lTags[2] = '*'
					end
					if lTags[1] == 'toID' and not lTags[2] then
						lTags[2] = '*'
					end
					tCon[i] = lTags
				end
				local chTxt = regexTag(txt[2], tCon)
				sampSetChatInputEnabled(true)
				sampSetChatInputText(u8:decode(''..chTxt:gsub('%*', '', 1)))
				if chTxt:find('%*') then setChatCursorPos(utf8len(chTxt:match('(.-)%*'))) end
			end}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_20', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.MeNotepad('greet', imgui.ImVec2(150, 300))
	imgui.EndChild()
end
function imgui.ChemicElements()
	imgui.BeginChild(id_name..'child_window_17', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.chemic, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine(330)

	imgui.BeginChild(id_name..'child_window_18', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		local chemicElem = {'H = Водород', 'He = Гелий', 'Li = Литий', 'Be = Берилий', 'B = Бор', 'C = Углерод', 'N = Азот', 'O = Кислород',
			'F = Фтор', 'Ne = Неон', 'Na = Натрий', 'Mg = Магний', 'Al = Алюминий', 'Si = Кремний', 'P = Фосфор', 'S = Сера', 'Cl = Хлор',
			'Ar = Аргон', 'K = Калий', 'Ca = Кальций', 'Sc = Скандий', 'Ti = Титан', 'V = Ванадий', 'Cr = Хром', 'Mn = Марганец', 'Fe = Железо',
			'Co = Кобальт', 'Cu = Медь', 'Zn = Цинк', 'Ga = Галий', 'Ge = Германий', 'As = Мышьяк', 'Se = Селен', 'Br = Бром', 'Kr = Криптон'
		}
		imgui.BeginChild(id_name..'child_window_24', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() / 2 - 10), false)
			for i, element in ipairs(chemicElem) do
				local txtChat = '/news '..esterscfg.events.chemic.tag..element:sub(1, element:find(' ')-1)..' = ?'
				if imgui.Selectable(id_name..'selec_table_HIM_'..i, nil) then
					sampSetChatInputEnabled(true)
					sampSetChatInputText(u8:decode(txtChat))
				end
				imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
				imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - 45)
				imgui.Text(element)
			end
		imgui.EndChild()

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('chemic', imgui.ImVec2(175, 150))
	imgui.EndChild()
end
function imgui.Interpreter()
	imgui.BeginChild(id_name..'child_window_11', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.SetCursorPosX(imgui.GetWindowWidth() / 2 - 75)
		imgui.PushItemWidth(120)
		imgui.Combo('Язык'..id_name..'combo_1', ComboLanguage, languageItems, #languageList)

		imgui.RenderButtonEf(esterscfg.events.interpreter, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'language', languageList[ComboLanguage[0]+1]:match('(.+)....'), 'Английск', 'У вас не указан {fead00}Язык{C0C0C0} данного эфира!', 'Язык на котором будут слова\nОбратите внимание, что нет окончания!'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_12', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		if imgui.BeginTabBar(id_name..'tabbar_1') then
			if imgui.BeginTabItem(' Перевод '..id_name..'tabitem_1') then
				imgui.TextCenter('Переводчик')

				imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 6))
				imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 4 - 18)
				local iptTrnsl = new.char[32]('')
				imgui.StrCopy(iptTrnsl, iptTmp.iptTrnsl or '')
				if imgui.InputTextWithHint(id_name..'input_13', 'Шоколад', iptTrnsl, sizeof(iptTrnsl) - 1, imgui.InputTextFlags.CharsNoBlank) then
					iptTmp.iptTrnsl = str(iptTrnsl)
				end
				imgui.Tooltip('Введите любое слово,\n  мы его переведём!')

				imgui.SameLine(nil, 4)
				if imgui.Button('Х'..id_name..'button_12', imgui.ImVec2(18, 20)) then
					iptTmp.iptTrnsl = nil
					tmp.Trnsl = nil
				end
				imgui.Tooltip('Очистить')

				imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 3))
				if imgui.Button('Перевести'..id_name..'button_19', imgui.ImVec2(imgui.GetWindowWidth() - 20, 20)) and iptTmp.iptTrnsl and iptTmp.iptTrnsl ~= '' then
					lua_thread.create(function (word, lang, tmp)
						local st, func = pcall(loadstring, [[return {translate=function(txt, langTag, tmp)local commonAnswer = true local tName = os.tmpname()if doesFileExist(tName)then os.remove(tName)end downloadUrlToFile('https://translate.googleapis.com/translate_a/single?'..httpBuild({['client'] = 'gtx', ['dt'] = 't', ['sl'] = 'ru', ['tl'] = langTag, ['q'] = txt}), tName, function (_, st)if st==58 then if doesFileExist(tName)then local tFile=io.open(tName, 'r')if tFile then local answer=decodeJson(tFile:read('*a'))commonAnswer=(answer[1][1][1] and true or false)tmp.Trnsl=answer[1][1][1]or'Ошибка доступа!'tFile:close()os.remove(tName)end else tmp.Trnsl='Фатальная ошибка!'commonAnswer=false end end end)return commonAnswer end}]])
						if st then pcall(func().translate, word, lang, tmp) else tmp.Trnsl = 'Ошибка доступа!' end
					end, iptTmp.iptTrnsl, langArr.tags[ComboLanguage[0]+2], tmp)
				end

				if tmp.Trnsl then 
					local txtChat = '/news '..esterscfg.events.interpreter.tag..tmp.Trnsl..' = ?'
					imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 3))
					imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0, 0, 0, 0))
					imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(0, 0, 0, 0))
					if imgui.Selectable(id_name..'selec_table_Wt', nil) then
						sampSetChatInputEnabled(true)
						sampSetChatInputText(u8:decode(txtChat))
					end
					imgui.PopStyleColor(2)
					imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
					imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - imgui.CalcTextSize(tmp.Trnsl or ' ').x / 2 - 10)
					imgui.Text(tmp.Trnsl or ' ')
				end

				imgui.EndTabItem()
			end
			if imgui.BeginTabItem('Заготовки'..id_name..'tabitem_2') then
				imgui.BeginChild(id_name..'child_window_24', imgui.ImVec2(imgui.GetWindowWidth(), imgui.GetWindowHeight() / 2 - 10), false)
					for i, word in ipairs(langArr.ru) do
						local foreignW = langArr[langArr.tags[ComboLanguage[0]+2]][i]
						local txtChat = '/news '..esterscfg.events.interpreter.tag..foreignW..' = ?'
						if imgui.Selectable(id_name..'selec_table_W_'..i, nil) then
							sampSetChatInputEnabled(true)
							sampSetChatInputText(u8:decode(txtChat))
						end
						imgui.Tooltip('Крикабельно, вставит в чат:\n\n'..txtChat)
						imgui.SameLine(nil, imgui.GetWindowWidth() / 2 - 60)
						imgui.Text(word..' = '..foreignW)
					end
				imgui.EndChild()
				imgui.EndTabItem()
			end
			imgui.EndTabBar()
		end

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('interpreter', imgui.ImVec2(150, 200))
	imgui.EndChild()
end
function imgui.Mirror()
	imgui.BeginChild(id_name..'child_window_27', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3) * 2 - 8, imgui.GetWindowHeight()), false)
		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptID = new.char[256]('')
		imgui.StrCopy(iptID, iptTmp.iptID or '')
		if imgui.InputText(id_name..'input_9', iptID, sizeof(iptID) - 1, 16) then
			iptTmp.iptID = str(iptID)
			tmp.evNick = nil
			if tonumber(str(iptID)) and sampIsPlayerConnected(str(iptID)) then
				tmp.evNick = sampGetPlayerNickname(str(iptID)):gsub('_', ' '):gsub('^%[%d%d?%]', '')
			end
		end
		imgui.SameLine()
		imgui.Text('ID игрока')
		imgui.Tooltip('ID для взаимодействия с человеком')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Награда')
		imgui.Tooltip('Напишите сюда награду за эфир')
		imgui.SameLine()
		imgui.PushItemWidth(80)
		local iptPrz = new.char[256]('')
		imgui.StrCopy(iptPrz, iptTmp.iptPrz or '1 млн')
		if imgui.InputText(id_name..'input_11', iptPrz, sizeof(iptPrz) - 1) then
			iptTmp.iptPrz = str(iptPrz)
		end

		imgui.SetCursorPosX(1)
		imgui.PushItemWidth(30)
		local iptScrId = new.char[256]('')
		imgui.StrCopy(iptScrId, iptTmp.iptScrId or '')
		if imgui.InputText(id_name..'input_10', iptScrId, sizeof(iptScrId) - 1, 16) then
			iptTmp.iptScrId = str(iptScrId)
		end
		imgui.SameLine()
		imgui.Text('Кол-во баллов')
		imgui.Tooltip('Сколько у человека баллов?')

		imgui.SameLine()

		imgui.SetCursorPosX(150)
		imgui.Text('Раунды')
		imgui.Tooltip('До скольки баллов будем играть?')
		imgui.SameLine()
		imgui.PushItemWidth(30)
		local iptScr = new.char[256]('')
		imgui.StrCopy(iptScr, iptTmp.iptScr or '5')
		if imgui.InputText(id_name..'input_12', iptScr, sizeof(iptScr) - 1) then
			iptTmp.iptScr = str(iptScr)
		end

		imgui.RenderButtonEf(esterscfg.events.mirror, {
			{'prize', iptTmp.iptPrz or '1 млн', '1 млн', 'У вас не указанна {fead00}награда{C0C0C0} за данный эфир!', 'Награда за эфир'},
			{'scores', iptTmp.iptScr or '5', '3', 'У вас не указанно сколько {fead00}раундов{C0C0C0} будет в эфире!', 'Количество раундов'},
			{'scoreID', iptTmp.iptScrId, '2', 'У вас не указанно сколько {fead00}баллов{C0C0C0} у человека!', 'Количество баллов у человека'},
			{'ID', tmp.evNick, 'Rudius Greyrat', 'У вас не указан {fead00}ID{C0C0C0} человека!', 'Имя человека'}
		})
	imgui.EndChild()

	imgui.SameLine()

	imgui.BeginChild(id_name..'child_window_28', imgui.ImVec2(math.floor(imgui.GetWindowWidth() / 3), imgui.GetWindowHeight()), false)
		imgui.TextCenter('Переворачивание слов')

		imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 6))
		imgui.PushItemWidth(imgui.GetWindowWidth() - 20 - 4 - 18)
		local iptMir1 = new.char[64]('')
		imgui.StrCopy(iptMir1, iptTmp.iptMir1 or '')
		if imgui.InputTextWithHint(id_name..'input_13', 'Привет', iptMir1, sizeof(iptMir1) - 1, imgui.InputTextFlags.CharsNoBlank) then
			iptTmp.iptMir1 = str(iptMir1)
			tmp.iptMir2 = nil
			if iptTmp.iptMir1 ~= '' then
				local inverted = u8:decode(iptTmp.iptMir1:nlower()):reverse()
				tmp.iptMir2 = u8:encode(inverted:match('^(.)')):nupper() .. u8:encode(inverted:match('^.(.*)'))
			end

		end
		imgui.Tooltip('Введите любое слово,\n  мы его перевернём!')

		imgui.SameLine(nil, 4)
		if imgui.Button('Х'..id_name..'button_12', imgui.ImVec2(18, 20)) then
			iptTmp.iptMir1 = nil
			tmp.iptMir2 = nil
		end
		imgui.Tooltip('Очистить')

		local txtChat = '/news '..esterscfg.events.mirror.tag..(tmp.iptMir2 and tmp.iptMir2..' = ?' or 'Тевирп = ?')
		imgui.SetCursorPos(imgui.ImVec2(8, imgui.GetCursorPosY() + 3))
		if imgui.Button(tmp.iptMir2 or 'Тевирп'..id_name..'button_16', imgui.ImVec2(imgui.GetWindowWidth() - 20, 20)) then
			sampSetChatInputEnabled(true)
			sampSetChatInputText(u8:decode(txtChat))
		end
		imgui.Tooltip('Кликабельно, вставит в чат:\n\n'..txtChat)

		imgui.SetCursorPosY(imgui.GetCursorPosY() + 6)
		imgui.Separator()
		imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)

		imgui.MeNotepad('mirror', imgui.ImVec2(150, 250))
	imgui.EndChild()
end
function imgui.ScrSettings()
	if KeyEditor('menu', 'Открыть главное меню', imgui.ImVec2(245,30)) then
		saveKeysBind()
	end
	imgui.SameLine()
	if KeyEditor('helpMenu', 'Вспомогательное меню', imgui.ImVec2(245,30)) then
		saveKeysBind()
	end
	if KeyEditor('catchAd', 'Редактор объявлений', imgui.ImVec2(245,30)) then
		saveKeysBind()
	end
	imgui.SameLine()
	if KeyEditor('copyAd', 'Скопировать объявление', imgui.ImVec2(245,30)) then
		saveKeysBind()
	end
	if KeyEditor('fastMenu', 'Быстрое меню', imgui.ImVec2(245,30)) then
		saveKeysBind()
	end
	imgui.SameLine()
	if imgui.Button('Перезагрузить скрипт', imgui.ImVec2(245,30)) then
		thisScript():reload()
	end
	imgui.PushItemWidth(500)
	imgui.SliderInt(id_name..'slider_2', newsDelay, 1, 50, 'Задержка "/newsredak" ('..newsDelay[0] * 10 ..')')
	if not imgui.IsItemActive() and setup.newsDelay ~= newsDelay[0] then
		if newsDelay[0] < 1 or newsDelay[0] > 50 then
			newsDelay[0] = setup.newsDelay
			return
		end
		setup.newsDelay = newsDelay[0]
		saveFile('settings.cfg', setup)
	end
	imgui.PopItemWidth()
	imgui.Tooltip('Это дополнительная задержка, при\nфлуде командой. Если у вас пишет\n"Не Флуди!", индивидуально\nувеличите задержку')
end
function imgui.AdvRules()
	--imgui.SetCursorPosY(10)
	imgui.BeginChild(id_name..'child_window2',imgui.ImVec2(imgui.GetWindowWidth() - 10, imgui.GetWindowHeight()-40), false, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
	--imgui.SetCursorPosY(5)
		if imgui.Button('Приветствие', imgui.ImVec2(270,32)) then
			sampSendChat(u8:decode('Приветствую, вы готовы сдать ПРО?'))
		end
		imgui.Tooltip('В чат: Приветствую, вы готовы сдать ПРО?')
		if imgui.Button('Вопрос №1', imgui.ImVec2(270,30)) then
			sampSendChat(u8:decode('Назови мне сокращение для автомобилей.'))
		end
		imgui.Tooltip('В чат: Назови мне сокращение для автомобилей.')
		if imgui.Button('Вопрос №2', imgui.ImVec2(270,32)) then
			sampSendChat(u8:decode('Назови мне сокращение для аксессуаров.'))
		end
		imgui.Tooltip('В чат: Назови мне сокращение для аксессуаров.')
		if imgui.Button('Вопрос №3', imgui.ImVec2(270,30)) then
			sampSendChat(u8:decode('Назови мне сокращение для аксессуаров.'))
		end
		imgui.Tooltip('В чат: Назови мне сокращение для аксессуаров.')
		if imgui.Button('Вопрос №4', imgui.ImVec2(270,32)) then
			lua_thread.create(function()
			sampSendChat(u8:decode('Допустим, пришло такое объявление:'))
			wait(1000)
			sampSendChat(u8:decode('"Продам БМВ Е34"'))
			wait(1000)
			sampSendChat(u8:decode('Как ты его отредактируешь?'))
			end)
		end
		imgui.Tooltip('В чат: Допустим, пришло такое объявление: \n "Продам БМВ Е34" \n Как ты его отредактируешь?')
		if imgui.Button('Вопрос №5', imgui.ImVec2(270,30)) then
			lua_thread.create(function()
				sampSendChat(u8:decode('Допустим, пришло такое объявление:'))
				wait(1000)
				sampSendChat(u8:decode('"Куплю чай по 5к штука"'))
				wait(1000)
				sampSendChat(u8:decode('Как ты его отредактируешь?'))
			end)
		end
		imgui.Tooltip('В чат: Допустим, пришло такое объявление: \n "Куплю чай по 5к штука" \n Как ты его отредактируешь?')
		if imgui.Button('Сдал', imgui.ImVec2(131,32)) then
			lua_thread.create(function()
			sampSendChat(u8:decode('Поздравляю, вы сдали ПРО!'))
			wait(100)
			sampSendChat('/time')
			end)
		end
		imgui.Tooltip('В чат: Поздравляю, вы сдали ПРО!')
		imgui.SameLine()
		if imgui.Button('Не сдал', imgui.ImVec2(131,32)) then
			lua_thread.create(function()
			sampSendChat(u8:decode('К сожалению, вы не сдали ПРО.'))
			wait(1000)
			sampSendChat(u8:decode('Не расстраивайтесь, подучите и приходите позже!'))
			end)
		end
		imgui.Tooltip('В чат: К сожалению, вы не сдали ПРО. \n Не расстраивайтесь, подучите и приходите позже!')
	imgui.EndChild()
end
function imgui.FmInterviews()
	local refusals = {
		{'Назад', function ()
			tmp.fmRef = nil
		end},
		{'Законка', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы незаконопослушный гражданин. Приходите когда исправитесь.'))
			wait(1000)
			sampSendChat(u8:decode('/b Чтобы работать в гос. структуре, нужно иметь минимум 35+ законки'))
		end},
		{'Варн', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы находитесь в ЧС штата, поэтому не можете у нас работать.'))
			wait(1000)
			sampSendChat(u8:decode('/b У Вас есть WARN на аккаунте.'))
		end},
		{'НРП ник', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но у Вас в паспорте опечатка. Исправьте и приходите.'))
			wait(1000)
			sampSendChat(u8:decode('/b У Вас нонРП ник. Его можно исправить в /mm - 1 - 12'))
		end},
		{'Другая ОРГ', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы работаете в другой организации.'))
			wait(1000)
			sampSendChat(u8:decode('Чтобы устроиться к нам, увольтесь и приходите вновь.'))
		end},
		{'Нет 3 ур', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините но чтобы работать в гос. организации нужно иметь 3-х летнюю прописку в штате.'))
			wait(1000)
			sampSendChat(u8:decode('/b Вам нужно 3+ уровень персонажа.'))
		end},
		{'В ЧС', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы находитесь в черном списке нашей организации.'))
		end},
		{'Нарко', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но Вы нам не подходите. Вы наркозависимы.'))
		end},
		{'Мед.карта', function ()
			sampSendChat(u8:decode(tmp.targetPlayer.nick:gsub('_', ' ')..', извините, но для того чтобы устроить к нам нужно обновить мед. карту.'))
			wait(1000)
			sampSendChat(u8:decode('Обновить её можно в любой больницы штата.'))
		end}
	}
	local buttons = {
		{'Приветствие', function ()
			sampSendChat(u8:decode('Здравствуйте, вы пришли на собеседование?'))
		end},
		{'Запрос документов', function ()
			sampSendChat(u8:decode('Хорошо, покажите ваши документы. А именно паспорт, лицензии и мед. карту.'))
			wait(1000)
			local myId = select(2,sampGetPlayerIdByCharHandle(PLAYER_PED))
			sampSendChat(u8:decode(string.format('/b /showpass %s | /showlic %s | /showmc %s', myId, myId, myId)))
		end},
		{'Проверка документов', function ()
			if sampIsDialogActive() then 
				if tmp.lastDialog.title == '{BFBBBA}Мед. карта' then
					sampSendChat(u8:decode('/me взял у человека напротив мед. карту, затем внимательно изучил её'))
					wait(1000)
					if tmp.lastDialog.text:match('{FFFFFF}Имя: '..tmp.targetPlayer.nick) then
						local narko = tonumber(tmp.lastDialog.text:match('{CEAD2A}Наркозависимость: ([%d%.]+){FFFFFF}'))
						if narko <= 3 then -- 3 Заменить на переменную настройки
							sampSendChat(u8:decode('/do Мед. карту человека впорядке.'))
							wait(1000)
							sampSendChat(u8:decode('/me вернул мед. карту человеку напротив'))
						else
							for f=1, #refusals do
								if refusals[f][1] == 'Нарко' then refusals[f][2]() break end
							end
						end
					else
						sampAddChatMessage(u8:decode(tag..'Мед. книжка другова человека!'), -1)
					end		
				elseif tmp.lastDialog.title == '{BFBBBA}Паспорт' then
					sampSendChat(u8:decode('/me взял у человека напротив паспорт, затем внимательно изучил его'))
					wait(1000)
					if tmp.lastDialog.text:match('{FFFFFF}{FFFFFF}Имя: {FFD700}'..tmp.targetPlayer.nick) then
						if tmp.targetPlayer.score >= 3 then
							if tmp.lastDialog.text:match('{FF6200}Лечился в Психиатрической больнице: %d+ .- %(Необходимо обновить мед%. карту%)') then
								for f=1, #refusals do
									if refusals[f][1] == 'Мед.карта' then refusals[f][2]() break end
								end
							else
								if tonumber(tmp.lastDialog.text:match('{FFFFFF}Законопослушность: {FFD700}(%d+)/100')) < 35 then
									for f=1, #refusals do
										if refusals[f][1] == 'Законка' then refusals[f][2]() break end
									end
								else
									sampSendChat(u8:decode('/do В паспорте нет опечаток.'))
									wait(1000)
									sampSendChat(u8:decode('/me вернул человеку напротив паспорт'))
								end
							end
						else
							for f=1, #refusals do
								if refusals[f][1] == 'Нет 3 ур' then refusals[f][2]() break end
							end
						end
					else
						sampAddChatMessage(u8:decode(tag..'Паспорт принадлежит другому человеку!'), -1)
					end
				elseif tmp.lastDialog.title == '{BFBBBA}Лицензии' then
					sampSendChat(u8:decode('/me взял у человека напротив лицензии, затем внимательно изучил их'))
					wait(1000)
					if tmp.lastDialog.text:match('{FFFFFF}Лицензия на авто: 		{FF6347}Нет {cccccc}%(.-%)') then
						sampSendChat(u8:decode('/do Необходимой лицензии у человека нет.'))
						wait(1000)
						sampSendChat(u8:decode('Вам необходимо получить лицензию на вождение транспортом. Это можно сделать в Центре Лицензирования г. Сан-Фиерро.'))
					else
						sampSendChat(u8:decode('/do Необходимая лицензия имеется.'))
						wait(1000)
						sampSendChat(u8:decode('/me вернул человеку напротив лицензии'))
					end
				elseif tmp.lastDialog.title == '{BFBBBA}{73B461}Активные предложения' and tmp.lastDialog.style == 5 then
					local numLine = -1
					for line in tmp.lastDialog.text:gmatch('[^\n]+') do
						if line:match('{ffffff} Предлагает посмотреть .-%.%.\t'..tmp.targetPlayer.nick) then
							tmp.fmActi = true; sampSendDialogResponse(tmp.lastDialog.id, 1, numLine, nil); break
						end
						numLine = numLine + 1
					end
					if not tmp.fmActi then
						sampAddChatMessage(u8:decode(tag..'Данный человек не предлогал свои документы!'), -1)
					end
				end
			else
				tmp.fmActi, tmp.fmActiT = true, os.clock()
				sampSendChat(u8:decode('/offer'))
				while tmp.fmActi and (os.clock() - tmp.fmActiT < 3) do
					if tmp.lastDialog and tmp.lastDialog.title == '{BFBBBA}{73B461}Активные предложения' and tmp.lastDialog.style == 5 then
						local numLine = -1
						for line in tmp.lastDialog.text:gmatch('[^\n]+') do
							if line:match('{ffffff} Предлагает посмотреть .-%.%.\t'..tmp.targetPlayer.nick) then
								tmp.fmActi = true; sampSendDialogResponse(tmp.lastDialog.id, 1, numLine, nil); break
							end
							numLine = numLine + 1
						end
						if not tmp.fmActi then
							sampSendDialogResponse(tmp.lastDialog.id, 0, nil, nil)
							sampAddChatMessage(u8:decode(tag..'Данный человек не предлогал свои документы!'), -1)
						end
						break
					end
					wait(100)
				end
			end
		end, 'Автоматическая проверка документов'},
		{'Вопрос №1', function ()
			sampSendChat(u8:decode('Хорошо... Что находится у меня над головой?'))
		end, 'В чат: Хорошо... Что находится у меня над головой?'},
		{'Вопрос №2', function ()
			sampSendChat(u8:decode('Прекрасно, расскажите что-нибудь о себе?'))
		end, 'В чат: Прекрасно, расскажите что-нибудь о себе?'},
		{'Вопрос №3', function ()
			sampSendChat(u8:decode('Почему вы выбрали именно наш радиоцентр?'))
		end, 'В чат: Почему вы выбрали именно наш радиоцентр?'},
		{'Вы подходите', function ()
			sampSendChat(u8:decode('Поздравляю! Вы нам подходите! Раздевалка находится на 2 этаже.'))
			wait(1000)
			sampSendChat(u8:decode('/invite '..tmp.targetPlayer.id))
		end, 'В чат: Поздравляю! Вы нам подходите!\nРаздевалка находится на 2 этаже.'},
		{'Отказ', function ()
			tmp.fmRef = true
		end}
	}
	local menu = not tmp.fmRef and buttons or refusals
	for i=1, #menu do
		if imgui.Button(menu[i][1]..id_name..'button_FM_'..i, imgui.ImVec2(270, 27)) then
			if tmp.rolePlay then return end tmp.rolePlay = true
			lua_thread.create(function ()
				if tmp.fmRef then tmp.fmRef= nil end
				menu[i][2]()
				tmp.rolePlay = false
			end)
		end
		if menu[i][3] then imgui.Tooltip(menu[i][3]) end
	end
end
function imgui.NewsRules()
	imgui.SetCursorPosY(15)
	imgui.BeginChild(id_name..'child_window3',imgui.ImVec2(imgui.GetWindowWidth() - 10, imgui.GetWindowHeight() - 40),false)
	if imgui.Button('Приветствие', imgui.ImVec2(270,32)) then
		sampSendChat(u8:decode('Приветствую, вы готовы сдать ППЭ?'))
	end
	imgui.Tooltip('В чат: Приветствую, вы готовы сдать ППЭ?')

	if imgui.Button('Вопрос №1', imgui.ImVec2(270,30)) then
		sampSendChat(u8:decode('Подскажи, что нужно сделать перед тем, как начать эфир?'))
	end
	imgui.Tooltip('В чат: Подскажи, что нужно сделать перед тем, как начать эфир?')

	if imgui.Button('Вопрос №2', imgui.ImVec2(270,32)) then
		sampSendChat(u8:decode('Назови мне тэг нашей радиостанции в рации департамента'))
	end
	imgui.Tooltip('В чат: Назови мне тэг нашей радиостанции в рации департамента')

	if imgui.Button('Вопрос №3', imgui.ImVec2(270,30)) then
		sampSendChat(u8:decode('Можно ли материться в эфирах?'))
	end
	imgui.Tooltip('В чат: Можно ли материться в эфирах?')

	if imgui.Button('Вопрос №4', imgui.ImVec2(270,32)) then
		sampSendChat(u8:decode'Можно ли оскорблять кого-либо в эфирах?')
	end
	imgui.Tooltip('В чат: Можно ли оскорблять кого-либо в эфирах?')

	if imgui.Button('Вопрос №5', imgui.ImVec2(270,30)) then
		sampSendChat(u8:decode'Можно ли проводить эфир без забития?')
	end
	imgui.Tooltip('Можно ли проводить эфир без забития?')

	if imgui.Button('Сдал', imgui.ImVec2(131,33)) then
		lua_thread.create(function()
		sampSendChat(u8:decode('Поздравляю, вы сдали ППЭ!'))
		wait(100)
		sampSendChat('/time')
		end)
	end
	imgui.Tooltip('В чат: Поздравляю, вы сдали ППЭ!')
	imgui.SameLine()
	if imgui.Button('Не сдал', imgui.ImVec2(131,33)) then
		lua_thread.create(function()
		sampSendChat(u8:decode('К сожалению, вы не сдали ППЭ.'))
		wait(1000)
		sampSendChat(u8:decode('Не расстраивайтесь, подучите и приходите позже!'))
		end)
	end
	imgui.Tooltip('В чат: К сожалению, вы не сдали ПРО. \n Не расстраивайтесь, подучите и приходите позже!')
	imgui.EndChild()
end
function imgui.LeaderActions()
	imgui.SetCursorPosY(15)
	imgui.SliderInt(id_name..'Rank', setrank, 0, 9, false)
	imgui.Tooltip('Выберите ранг')
	if imgui.Button('Изменить ранг', imgui.ImVec2(185,28)) then
		sampSendChat('/giverank ' ..tmp.targetPlayer.nick.. ' '..setrank[0])
	end
	imgui.Separator()

	imgui.InputTextWithHint('##Input1', 'Причина выговора', WReason, 100)
	reas = u8:decode(ffi.string(WReason))
	if imgui.Button('Выдать выговор', imgui.ImVec2(185,28)) then
		sampSendChat('/fwarn '..tmp.targetPlayer.nick..' '..reas)
	end

	imgui.InputTextWithHint('##Input', 'Причина снятия выговора', unwarn, 100)
	ureas = u8:decode(ffi.string(unwarn))
	if imgui.Button('Снять выговор', imgui.ImVec2(185,28)) then
		sampSendChat('/unfwarn '..tmp.targetPlayer.nick..' '..ureas)
	end

	imgui.Separator()

	imgui.InputTextWithHint('##Input2', 'Причина выдачи похвалы', praise, 100)
	prais = u8:decode(ffi.string(praise))
	if imgui.Button('Выдать похвалу', imgui.ImVec2(185,28)) then
		sampSendChat('/praise '..tmp.targetPlayer.nick.. ' '..prais)
	end

	imgui.Separator()

	if imgui.Button('Выдать /fractionrp', imgui.ImVec2(185,25)) then
		sampSendChat('/fractionrp '..tmp.targetPlayer.nick)
	end
end
function imgui.CustomMenu(labels, selected, size, speed, centering, flags, tooltip) 
    local bool = false
    local radius = size.y * 0.50
	flags = flags or 0
	tooltip = tooltip or nil
    local ImDrawlist = imgui.GetWindowDrawList()
    if LastActiveTime == nil then LastActiveTime = {} end
    if LastActive == nil then LastActive = {} end
    local function ImSaturate(f)
        return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
    end
    for i, v in ipairs(labels) do
        local c = imgui.GetCursorPos()
        local p = imgui.GetCursorScreenPos()
        if imgui.InvisibleButton(v..id_name..'invisible_CM_'..i, size) then
            selected[0] = i
            LastActiveTime[v] = os.clock()
            LastActive[v] = true
            bool = true
        end
		if tooltip and tooltip[i] and tooltip[i] ~= '' then 
			imgui.Tooltip(tooltip[i])
		end
        imgui.SetCursorPos(c)
        local t = selected[0] == i and 1.0 or 0.0
        if LastActive[v] then
            local time = os.clock() - LastActiveTime[v]
            if time <= 0.3 then
                local t_anim = ImSaturate(time / speed)
                t = selected[0] == i and t_anim or 1.0 - t_anim
            else
                LastActive[v] = false
            end
        end
        local col_bg = imgui.GetColorU32Vec4(selected[0] == i and imgui.GetStyle().Colors[imgui.Col.ButtonActive] or imgui.ImVec4(0,0,0,0))
        local col_hovered = imgui.GetStyle().Colors[imgui.Col.ButtonHovered]
        local col_hovered = imgui.GetColorU32Vec4(imgui.ImVec4(col_hovered.x, col_hovered.y, col_hovered.z, (imgui.IsItemHovered() and 0.2 or 0)))
		ImDrawlist:AddRectFilled(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + t * size.x, p.y + size.y), col_bg, 7.0, flags)
        ImDrawlist:AddRectFilled(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + size.x, p.y + size.y), col_hovered, 7.0, flags)
        imgui.SetCursorPos(imgui.ImVec2(c.x+(centering and (size.x-imgui.CalcTextSize(''..v:hexsub()).x)/2-3 or 15), c.y+(size.y-imgui.CalcTextSize(''..v:hexsub()).y)/2))
        imgui.RenderText(v)
        imgui.SetCursorPos(imgui.ImVec2(c.x, c.y+size.y+5))
    end
    return bool
end
function imgui.HeaderButton(bool, str_id)
    local AI_HEADERBUT = {}
	local DL = imgui.GetWindowDrawList()
	local result = false
	local label = string.gsub(str_id, "##.*$", "")
	local duration = { 0.5, 0.3 }
	local cols = {
        idle = imgui.GetStyle().Colors[imgui.Col.TextDisabled],
        hovr = imgui.GetStyle().Colors[imgui.Col.Text],
        slct = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
    }

 	if not AI_HEADERBUT[str_id] then
        AI_HEADERBUT[str_id] = {
            color = bool and cols.slct or cols.idle,
            clock = os.clock() + duration[1],
            h = {
                state = bool,
                alpha = bool and 1.00 or 0.00,
                clock = os.clock() + duration[2],
            }
        }
    end
    local pool = AI_HEADERBUT[str_id]

	imgui.BeginGroup()
		local pos = imgui.GetCursorPos()
		local p = imgui.GetCursorScreenPos()
		
		imgui.TextColored(pool.color, label)
		local s = imgui.GetItemRectSize()
		local hovered = imgui.isPlaceHovered(p, imgui.ImVec2(p.x + s.x, p.y + s.y))
		local clicked = imgui.IsItemClicked()
		
		if pool.h.state ~= hovered and not bool then
			pool.h.state = hovered
			pool.h.clock = os.clock()
		end
		
		if clicked then
	    	pool.clock = os.clock()
	    	result = true
	    end

    	if os.clock() - pool.clock <= duration[1] then
			pool.color = imgui.bringVec4To(
				imgui.ImVec4(pool.color),
				bool and cols.slct or (hovered and cols.hovr or cols.idle),
				pool.clock,
				duration[1]
			)
		else
			pool.color = bool and cols.slct or (hovered and cols.hovr or cols.idle)
		end

		if pool.h.clock ~= nil then
			if os.clock() - pool.h.clock <= duration[2] then
				pool.h.alpha = imgui.bringFloatTo(
					pool.h.alpha,
					pool.h.state and 1.00 or 0.00,
					pool.h.clock,
					duration[2]
				)
			else
				pool.h.alpha = pool.h.state and 1.00 or 0.00
				if not pool.h.state then
					pool.h.clock = nil
				end
			end

			local max = s.x / 2
			local Y = p.y + s.y + 3
			local mid = p.x + max

			DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid + (max * pool.h.alpha), Y), ToU32(imgui.set_alpha(pool.color, pool.h.alpha)), 3)
			DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid - (max * pool.h.alpha), Y), ToU32(imgui.set_alpha(pool.color, pool.h.alpha)), 3)
		end

	imgui.EndGroup()
	return result
end
function imgui.SameTable(id, tag, func)
	if tmp.selId == id then tmp.selIdAc = true else tmp.selIdAc = false end
	if imgui.Selectable(id_name..'selec_table_'..tag..id, tmp.selIdAc, imgui.SelectableFlags.AllowDoubleClick) then
		tmp.selId = nil
		if imgui.IsMouseDoubleClicked(0) then
			setVirtualKeyDown(0x01, false)
		end
	end
	imgui.SameLine(0)

	if imgui.BeginPopupContextItem(id_name..'context_item_'..tag..id, 1) or imgui.BeginPopupContextItem(id_name..'context_item_'..tag..id, 0) then
		tmp.selId = id
		if tmp.close then imgui.CloseCurrentPopup() tmp.close = nil end
		if imgui.Button('Редактировать', imgui.ImVec2(100, 0)) then
			func()
			imgui.OpenPopup(id_name..'EditChatLine_1')
		end
		if imgui.Button('Удалить', imgui.ImVec2(100, 0)) then
			table.remove(adcfg, id)
			saveFile('advertisement.cfg', adcfg)
			tmp.brea = true
			imgui.CloseCurrentPopup()
		end
		if imgui.Button('Закрыть', imgui.ImVec2(100, 0)) then
			imgui.CloseCurrentPopup()
		end
		if imgui.BeginPopupModal(id_name..'EditChatLine_1', nil, imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) then
			imgui.TextCenter('Редактирование сохранненого объявления #'..id)
			imgui.Separator()

			imgui.NewLine()
			imgui.TextCenter('{STANDART}{ffa64d99}Объявление которое пришло в редакцию на проверку')
			imgui.PushItemWidth(555)
			imgui.InputText(id_name .. 'input_1', inputAd, sizeof(inputAd) - 1)

			imgui.NewLine()
			imgui.TextCenter('{STANDART}{66ffb399}Сохраненное объявление после вашего редактирования')
			imgui.PushItemWidth(555)
			imgui.InputText(id_name .. 'input_2', inputAdText, sizeof(inputAdText) - 1)

			imgui.NewLine()
			imgui.SetCursorPosX(82.5)
			if imgui.Button('Применить', imgui.ImVec2(175, 0)) then
				adcfg[id].ad = str(inputAd)
				adcfg[id].text = str(inputAdText)
				saveFile('advertisement.cfg', adcfg)
				imgui.StrCopy(inputAd, '')
				imgui.StrCopy(inputAdText, '')
				imgui.CloseCurrentPopup()
				tmp.close = true
			end
			imgui.SameLine(nil, 50)
			if imgui.Button('Закрыть', imgui.ImVec2(175, 0)) then imgui.CloseCurrentPopup() tmp.close = true end
			imgui.EndPopup()
		end
		imgui.EndPopup()
	end
	if tmp.selId and not imgui.IsPopupOpen(id_name..'context_item_'..tag..(tmp.selId and tmp.selId or 0)) then
		tmp.selId = nil
	end
end
function imgui.RenderText(text)
	local style = imgui.GetStyle()
    local colors = style.Colors
    local col = imgui.Col
	local width = imgui.GetWindowWidth()

	local score = {}
	for tab in string.gmatch(text, '[^\t]+') do score[#score + 1] = tab end

	for i=1, #score do
		if i ~= 1 then 
			if #score == 2 then
				imgui.SameLine(0)
				imgui.SetCursorPosX((width / #score * (i - 1)) + (width / (#score * 2)) + 10)
			else 
				imgui.SameLine(0)
				local text_width = imgui.CalcTextSize(tostring(string.gsub(score[i], '{%x%x%x%x%x%x}', '')))
				imgui.SetCursorPosX((width / #score * (i - 1)) + (width / (#score * 2)) - (text_width.x / 2) - 10)
			end
		end

		local text = score[i]:gsub('{(%x%x%x%x%x%x)}', '{%1FF}')
		local color = colors[col.Text]
		local start = 1
		local a, b = text:find('{........}', start)	

		while a do
			local t = text:sub(start, a - 1)
			if #t > 0 then
				imgui.TextColored(color, t)
				imgui.SameLine(nil, 0)
			end

			local clr = text:sub(a + 1, b - 1)
			if clr:upper() == 'STANDART' then color = colors[col.Text]
			else
				clr = tonumber(clr, 16)
				if clr then
					local r = bit.band(bit.rshift(clr, 24), 0xFF)
					local g = bit.band(bit.rshift(clr, 16), 0xFF)
					local b = bit.band(bit.rshift(clr, 8), 0xFF)
					local a = bit.band(clr, 0xFF)
					color = imgui.ImVec4(r / 255, g / 255, b / 255, a / 255)
				end
			end

			start = b + 1
			a, b = text:find('{........}', start)
		end
		imgui.NewLine()
		if #text >= start then
			imgui.SameLine(nil, 0)
			imgui.TextColored(color, text:sub(start))
		end

	end
end
function imgui.RenderButtonEf(array, tagConcept, func)
	local tagConcept = tagConcept or {}
	local tagEvents = {{'tag', esterscfg.events[array.name].tag, '', '', 'Тег которвый вы можете изменить\nс правой стороны. (Можно просто очистить)'}}
	tagConcept[#tagConcept+1] = tagEvents[1]
	local cycleEsters = function (arr, t)
		local t = t or false
		for i, but in ipairs(arr) do
			imgui.SetCursorPosX((t and imgui.GetWindowWidth() / 1.334 - 60 + 4 or imgui.GetWindowWidth() / 4 - 69))
			if imgui.Button(but[1]..id_name..'button_EF_'.. (t and '' or 'rp_') ..i, (t and imgui.ImVec2(120, 27) or imgui.ImVec2(135, 27))) then
				if tmp.sNewsEv then sampAddChatMessage(u8:decode(tag .. (t and 'RP действия уже отыгрываются, подождите пока закончится.' or 'Вы уже в эфире! Подождите, пока закончится предыдущее вещание!')), -1)
				else
					local loFuBtn = {}
					for _, nameBtn in ipairs(func or {}) do
						if but[1] == nameBtn[1] then
							loFuBtn.check = nameBtn[2]
							loFuBtn.func = nameBtn[3]
						end
					end
					for _, concept in ipairs(pushArrS(tagConcept)) do
						if (not concept[2] or concept[2] == '') and findTag(but, concept[1]) and not loFuBtn.check then
							tmp.sNewsEvErr = true
							sampAddChatMessage(u8:decode(tag..concept[4]), -1)
						end
					end
					if not tmp.sNewsEvErr then
						lua_thread.create(function ()
							tmp.sNewsEv = true
							if loFuBtn.func then loFuBtn.func(but, tagConcept)
							else
								for k=2, #but do
									sampSendChat(u8:decode((t and but[k] or regexTag(but[k], tagConcept))))
									if k == #but then break end
									wait(1000 * esterscfg.settings.delay)
									if not tmp.sNewsEv then break end
								end
							end
							tmp.sNewsEv = nil
						end)
					end
					tmp.sNewsEvErr = nil
				end
			end

			if imgui.IsItemClicked(1) then
				setVirtualKeyDown(0x01, false)
				imgui.OpenPopup(id_name..'popup_modal_FF_'..but[1])
			end
			imgui.EditingTableEf(but, tagConcept, arr.name, i)

			imgui.Tooltip(select(2, pcall(function () 
				local toolText = 'ПКМ - Редактировать\n'
				for k=2, #but > 8 and 8 or #but do
					local text = regexTag(but[k], tagConcept)
					local calcText = text:sub(1, 62)
					toolText = toolText .. ' \n' .. (string.len(calcText) == #text and text or calcText..'..')
				end
				return toolText
			end)))
		end
	end

	imgui.SetCursorPosY(imgui.GetCursorPos().y + 10)
	imgui.Columns(2, id_name..'columns_2', false)
		cycleEsters(array)
	imgui.NextColumn()
		imgui.SetCursorPosX(imgui.GetWindowWidth() / 1.334 - 60 + 4)
		if imgui.Button(esterscfg.events.write[1]..id_name..'button_EFd_1', imgui.ImVec2(120, 27)) then
			sampSetChatInputEnabled(true)
			sampSetChatInputText(u8:decode(regexTag(esterscfg.events.write[2], tagEvents)))
		end
		if imgui.IsItemClicked(1) then
			setVirtualKeyDown(0x01, false)
			imgui.OpenPopup(id_name..'popup_modal_FF_Написать в /news')
		end
		imgui.Tooltip('ПКМ - Редактировать\n\n' .. regexTag(esterscfg.events.write[2], tagEvents))
		imgui.EditingTableEf(esterscfg.events.write, tagEvents, array.name)

		imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.81, 0.2, 0.2, 0.5))
		imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.82, 0.1, 0.1, 0.5))
		imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.82, 0.15, 0.15, 0.5))
			imgui.SetCursorPosX(imgui.GetWindowWidth() / 1.334 - 60 + 4)
			if imgui.Button('Остановить!'..id_name..'button_EFd_2', imgui.ImVec2(120, 27)) then
				if tmp.sNewsEv then
					tmp.sNewsEv = nil
					sampAddChatMessage(u8:decode(tag..'Эфир\\Действие экстренно прервано.'), -1)
				else
					sampAddChatMessage(u8:decode(tag..'У вас нет активных эфиров или RP действий, для остановки.'), -1)
				end
			end
			imgui.Tooltip('Остановить работу скрипта и\n      отправку сообщений!')
		imgui.PopStyleColor(3)

		imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() / 1.334 - 60 + 4, imgui.GetCursorPos().y + 31))
		if imgui.Button('/time'..id_name..'button_EFd_3', imgui.ImVec2(120, 27)) then
			sampSendChat('/time')
		end
		imgui.Tooltip('Команда /time')

		cycleEsters(esterscfg.events.actions, true)
	imgui.Columns(1, id_name..'columns_3', false)
end
function imgui.EditingTableEf(arrBtn, arrTag, arrName, i)
	local i = i or 0
	if imgui.BeginPopupModal(id_name..'popup_modal_FF_'..arrBtn[1], nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then --imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize 
		imgui.TextCenter('{66ffb399}Редактирование текста для эфира, кнопка {ffa64d99}"'..arrBtn[1]:gsub('\n', ' '):gsub('[%s]+', ' '):gsub('^%s', '')..'"')
		imgui.Separator()
		if esterscfg.events[arrName].tag or i == 0 then
			imgui.BeginChild(id_name..'child_window_t_1', imgui.ImVec2((imgui.GetWindowWidth() * 0.75), 80), false)
				imgui.Text('  Данные теги будут автоматически заменятся на закрепленный за ними текст!')
				if i ~= 0 then
					imgui.SameLine()
					imgui.TextEnd('{a8a8a899}*наведи')
					imgui.Tooltip('Наведи на один из тегов!')
				end
				
				imgui.SetCursorPosY(imgui.GetCursorPosY() + 7)
				local butTags = pushArrS(arrTag)
				local divider = (math.fmod(#butTags, 2) == 0 and math.floor(#butTags / 2) or math.floor(#butTags / 2) + 1)
				imgui.Columns(divider, id_name..'columns_TA_'..i, true)
				for k=1, #butTags do
					imgui.SetColumnWidth(-1, imgui.GetWindowWidth() / divider)
					local textTag = '{'..butTags[k][1]..'}'
					if imgui.Selectable(id_name..'selectable_'..k, nil) then
						setClipboardText(textTag)
					end
					imgui.Tooltip((butTags[k][5] or '') .. '\nТекст: "'..regexTag(textTag, arrTag)..'"\n\nНажми чтобы скопировать тег!')
					imgui.SameLine(-1)
					imgui.SetCursorPosX(imgui.GetCursorPos().x - 6 + ((imgui.GetWindowWidth() / divider) / 2 - imgui.CalcTextSize(textTag).x / 2))
					imgui.Text(textTag)
					imgui.NextColumn()
					if k ~= #butTags and math.fmod(k, divider) == 0 then
						imgui.Separator()
					end
				end
			imgui.EndChild()
			
			imgui.SameLine()
			imgui.BeginChild(id_name..'child_window_t_2', imgui.ImVec2((imgui.GetWindowWidth() / 4 - 23), 80), false)
				imgui.SetCursorPos(imgui.ImVec2((i ~= 0 and 12 or 3), 0))
				imgui.Text('{tag} в данном эфире:')

				local sizeText = imgui.CalcTextSize(esterscfg.events[arrName].tag).x + 9
				local iptHeight = (sizeText > 130 and 130 or (sizeText < 65 and 65 or sizeText))
				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2) - (iptHeight / 2))
				imgui.PushItemWidth(iptHeight)
				local iptTags = new.char[256]()
				imgui.StrCopy(iptTags, esterscfg.events[arrName].tag)
				imgui.InputText(id_name..'input_11', iptTags, sizeof(iptTags) - 1)
				if not imgui.IsItemActive() and esterscfg.events[arrName].tag ~= str(iptTags) then
					esterscfg.events[arrName].tag = str(iptTags)
					saveFile('estersBind.cfg', esterscfg)
				end

				imgui.Tooltip((sizeText > iptHeight and str(iptTags)..'\n\n' or '') ..'    Измените на нужный Вам!\nИзменения применяются сразу')

				imgui.SetCursorPos(imgui.ImVec2(30, 55))
				if imgui.Button((tmp.varEvIptMulti and 'Вернуть' or 'Проверить')..id_name..'btn_'..i, imgui.ImVec2(75, 25)) then
					tmp.varEvIptMulti = not tmp.varEvIptMulti
				end
				imgui.Tooltip('Покажет отформатированный\nвариант текста, с заменой тегов.\nИзменять текст в таком виде нельзя')
			imgui.EndChild()
		else
			imgui.SetCursorPosY(imgui.GetCursorPos().y + 2)
			imgui.TextCenter('Это обычный биндер, тут уже {ffa64d99}теги{STANDART} работать {ffa64d99}не будут{STANDART}!')
			imgui.SetCursorPosY(imgui.GetCursorPos().y + 4)
		end

		imgui.BeginChild(id_name..'child_window_t_3', imgui.ImVec2((imgui.GetWindowWidth() - 15), imgui.GetWindowHeight() - imgui.GetCursorPos().y - 39), false, imgui.WindowFlags.HorizontalScrollbar)
			arrBtn = tmp.EvaArrBtn or arrBtn
			if i ~= 0 then
				local stPos = {['x'] = imgui.GetCursorScreenPos().x, ['y'] = imgui.GetCursorScreenPos().y + 5}
				local Drawlist = imgui.GetWindowDrawList()
				local mW = 0  
				local posTags = {}
				local textL = ''
				for k=2, #arrBtn do 
					if tmp.varEvIptMulti then
						local tTxt = regexTag(arrBtn[k], arrTag)
						local sTxt = imgui.CalcTextSize(tTxt).x
						mW = (mW < sTxt and sTxt or mW)
						textL = textL..tTxt..'\n'
						for _, t in ipairs(pushArrS(arrTag)) do
							local txt = (t[2] ~= '' and t[2] or t[3])
							local num = tTxt:find(txt:regular())
							while num do
								table.insert(posTags, {['x'] = imgui.CalcTextSize(tTxt:sub(1, num)).x - 2.1, ['y'] = (k-2)*14, ['w'] = imgui.CalcTextSize(txt).x - 0.5, ['t'] = txt}) 
								local stNum = tTxt:sub(1, num - 1)
								num = tTxt:sub(num + #txt):find(txt:regular())
								if num then num = num + #stNum + #txt end
							end
						end
					else
						textL = textL..arrBtn[k]..'\n'
						local sTxt = imgui.CalcTextSize(arrBtn[k]).x
						mW = (mW < sTxt and sTxt or mW)
						for _, t in ipairs(pushArrS(arrTag)) do
							local num = arrBtn[k]:find('{'..t[1]..'}')
							while num do
								table.insert(posTags, {['x'] = imgui.CalcTextSize(arrBtn[k]:sub(1, num)).x - 1.1, ['y'] = (k-2)*14, ['w'] = imgui.CalcTextSize('{'..t[1]..'}').x - 1.2, ['t'] = '{'..t[1]..'}'}) 
								local stNum = arrBtn[k]:sub(1, num)
								num = arrBtn[k]:sub(num + 1 + #t[1]):find('{'..t[1]..'}')
								if num then num = num + #stNum + #t[1] end
							end
						end
					end
				end

				for _, pos in ipairs(posTags) do
					imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y + 3))
					imgui.Text(pos.t)
					imgui.Tooltip(''..regexTag(pos.t, arrTag))
				end

				imgui.StrCopy(iptEv, textL)
				imgui.SetCursorPos(imgui.ImVec2(0, 0))
				if imgui.InputTextMultiline(id_name..'inputMulti_1', iptEv, sizeof(iptEv) - 1, imgui.ImVec2(
					(mW+30 > imgui.GetWindowWidth() and mW+30 or imgui.GetWindowWidth()) - (15*(#arrBtn+2) > imgui.GetWindowHeight() and 17 or 0),
					(15*(#arrBtn+2) > imgui.GetWindowHeight() and 15*(#arrBtn+2) or imgui.GetWindowHeight())),
					(tmp.varEvIptMulti and imgui.InputTextFlags.ReadOnly or 0) + imgui.InputTextFlags.NoHorizontalScroll + (esterscfg.events[arrName].tag and imgui.InputTextFlags.CallbackAlways or 0),
					callbacks.bindtag) then

					local arrL = {arrBtn[1]}
					for search in string.gmatch(str(iptEv), '[^%c]+') do
						arrL[#arrL+1] = search
					end
					tmp.EvaArrBtn = arrL
				end

				for _, pos in ipairs(posTags) do
					Drawlist:AddRectFilled(imgui.ImVec2(stPos.x + pos.x, stPos.y + pos.y), imgui.ImVec2(stPos.x + pos.x + pos.w, stPos.y + pos.y + 13), 0x490eb52a, 4, 15)
				end

			else
				imgui.StrCopy(iptEv, (tmp.varEvIptMulti and regexTag(arrBtn[2], arrTag) or arrBtn[2]))
				imgui.PushItemWidth(imgui.GetWindowWidth())
				if imgui.InputText(id_name..'input_15', iptEv, sizeof(iptEv) - 1, (tmp.varEvIptMulti and imgui.InputTextFlags.ReadOnly or 0)) then
					tmp.EvaArrBtn = {arrBtn[1], str(iptEv)}
				end
			end
		imgui.EndChild()

		imgui.NewLine()
		imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() / 2 - 235, imgui.GetWindowHeight() - 30))
		if imgui.Button('Применить'..id_name..'btn_'..i, imgui.ImVec2(175, 0)) then
			if tmp.EvaArrBtn then
				if i ~= 0 then esterscfg.events[arrName][i] = tmp.EvaArrBtn
				else esterscfg.events.write[2] = tmp.EvaArrBtn[2] end
				tmp.EvaArrBtn = nil
			end
			tmp.varEvIptMulti = nil
			saveFile('estersBind.cfg', esterscfg)
			imgui.CloseCurrentPopup()
		end
		imgui.SameLine(nil, 120)
		if imgui.Button('Закрыть'..id_name..'btn_'..i, imgui.ImVec2(175, 0)) then
			tmp.EvaArrBtn = nil
			tmp.varEvIptMulti = nil
			imgui.CloseCurrentPopup()
		end
		
		imgui.SetCursorPos((i ~= 0 and imgui.ImVec2(700, 450) or imgui.ImVec2(626, 165))) 
		imgui.EndPopup()
	end
end
function imgui.Tooltip(text)
	if imgui.IsItemHovered() then
		imgui.BeginTooltip()
		imgui.PushFont(s4)
		imgui.Text(text)
		imgui.PopFont()
		imgui.EndTooltip()
	end
end
function imgui.TextStart(text)
	imgui.RenderText(tostring(text))
end
function imgui.TextCenter(text)
	text = tostring(text)
	imgui.SetCursorPosX(imgui.GetWindowWidth() / 2  - imgui.CalcTextSize(tostring(text:gsub('{%x%x%x%x%x%x%x?%x?}', ''):gsub('{STANDART}', ''))).x / 2 - 2)
	imgui.RenderText(text)
end
function imgui.TextEnd(text)
	text = tostring(text)
	imgui.SetCursorPosX(imgui.GetWindowWidth() - imgui.CalcTextSize(tostring(text:gsub('{%x%x%x%x%x%x%x?%x?}', ''):gsub('{STANDART}', ''))).x - 8)
	imgui.RenderText(text)
end
function imgui.isPlaceHovered(a, b)
	local m = imgui.GetMousePos()
	if m.x >= a.x and m.y >= a.y then
		if m.x <= b.x and m.y <= b.y then
			return true
		end
	end
	return false
end
function imgui.bringVec4To(from, to, start_time, duration)
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec4(
            from.x + (count * (to.x - from.x) / 100),
            from.y + (count * (to.y - from.y) / 100),
            from.z + (count * (to.z - from.z) / 100),
            from.w + (count * (to.w - from.w) / 100)
        ), true
    end
    return (timer > duration) and to or from, false
end
function imgui.bringFloatTo(from, to, start_time, duration)
    local timer = os.clock() - start_time
    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)
        return from + (count * (to - from) / 100), true
    end
    return (timer > duration) and to or from, false
end
function imgui.set_alpha(color, alpha)
	alpha = alpha and imgui.limit(alpha, 0.0, 1.0) or 1.0
	return imgui.ImVec4(color.x, color.y, color.z, alpha)
end
function imgui.limit(v, min, max)
	min = min or 0.0
	max = max or 1.0
	return v < min and min or (v > max and max or v)
end
function updateFile(filename, default)
	local cfg = loadFile(filename, default)
	if default.reset ~= cfg.reset then 
		cfg = table.recuiteral(default, cfg)
		cfg.reset = default.reset
		saveFile(filename, cfg)
	end
	return cfg
end
function saveFile(filename, tbl)
	local direct = getWorkingDirectory() .. '\\config\\News Helper\\' .. filename
	if not pcall(table.save, tbl, direct) then
		print(u8:decode('{CC0F00}ERROR:{999999}Ошибка сохранения файла: {FFAA00}'..filename))
		print(u8:decode('{CAAF00}!!! {999999}Это внутреннея ошибка скрипта, сообщите разработчику {CAAF00}!!!'))
	end
end
function loadFile(filename, option)
	local direct = getWorkingDirectory() .. '\\config\\News Helper\\' .. filename
	local tTable = option
	if pcall(table.read, direct) then local st = table.read(direct) tTable = st or option else
		print(u8:decode('{CC0F00}ERROR:{999999}Ошибка подгрузки файла: {FFAA00}'..filename))
		print(u8:decode('{CAAF00}!!! {999999}Были загружены стандартные значения, для сохранения..'))
		print(u8:decode('{999999}..своих старых настроек рекомендуется сделать бэкап файла {CAAF00}!!!'))
	end
	return tTable
end
function table.save(tbl, fn)
	local f, err = io.open(fn, "w")
	if not f then
		return nil, err
	end
	tmp.tag = ''
	f:write(table.tostring(tbl, true))
	f:close()
	tmp.tag = nil
	return true
end
function table.read(fn)
	local f, err = io.open(fn, "r")
	if not f then
		return nil, err
	end
	local tbl = assert(loadstring("return " .. f:read("*a")))
	f:close()
	return tbl()
end
function table.key_to_str(k)
	if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
		return k
	end
	return "[" .. table.val_to_str(k) .. "]"
end
function table.val_to_str(v)
	if "string" == type(v) then
		v = string.gsub(v, "\\", "\\\\")
		v = string.gsub(v, "\n", "\\n")
		return "'" .. string.gsub(v,"'", "\\'") .. "'"
	end
	if tmp.tag then tmp.tag = tmp.tag .. '\t' end
		local tt = "table" == type(v) and table.tostring(v) or tostring(v)
	if tmp.tag then tmp.tag = '' end
	return tt
end
function table.tostring(tbl) 
	local result, done = {}, {}
	for k, v in ipairs(tbl) do
		table.insert(result, tmp.tag..'\t'..table.val_to_str(v))
		done[k] = true
	end
	for k, v in pairs(tbl) do
		if not done[k] then
			table.insert(result, tmp.tag..'\t'..table.key_to_str(k) .. " = " .. table.val_to_str(v))
		end
	end
	return tmp.tag:gsub('%s', '', 1).."{\n" .. table.concat(result, ",\n") .. "\n"..tmp.tag.."}"
end
function table.recuiteral(out, inA)
	if type(out) ~= 'table' or type(inA) ~= 'table' then return {} end
	local k, v = next(out)
	while k do
		if not inA[k] and type(k) == 'string' then
			inA[k] = v
		elseif type(v) == 'table' and type(inA[k]) == 'table' then
			inA[k] = table.recuiteral(v, inA[k]) 
		end
		k, v = next(out, k)
	end
	return inA
end
function utf8len(s)
	local s = tostring(s)
	local pos = 1
	local bytes = s:len()
	local len = 0
	while pos <= bytes do
		len = len + 1
		pos = pos + utf8charbytes(s, pos)
	end
	return len
end
function utf8charbytes(s, i)
    local i = i or 1
    local c = string.byte(s, i)

    if c > 0 and c <= 127 then
        return 1
    elseif c >= 194 and c <= 223 then
        local c2 = string.byte(s, i + 1)
        return 2
    elseif c >= 224 and c <= 239 then
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        return 3
    elseif c >= 240 and c <= 244 then
        local c2 = s:byte(i + 1)
        local c3 = s:byte(i + 2)
        local c4 = s:byte(i + 3)
        return 4
    end
end
function utf8sub(s, i, j)
    local j = j or -1
    if i == nil then return "" end

    local pos = 1
    local bytes = string.len(s)
    local len = 0

    local l = (i >= 0 and j >= 0) or utf8len(s)
    local startChar = (i >= 0) and i or l + i + 1
    local endChar = (j >= 0) and j or l + j + 1

    if startChar > endChar then
        return ""
    end

    local startByte, endByte = 1, bytes

    while pos <= bytes do
        len = len + 1
        if len == startChar then
            startByte = pos
        end

        pos = pos + utf8charbytes(s, pos)
        if len == endChar then
            endByte = pos - 1
            break
        end
    end

    return string.sub(s, startByte, endByte)
end
function utf8replace(s, mapping)
    local pos = 1
    local bytes = string.len(s)
    local charbytes
    local newstr = ""

    while pos <= bytes do
        charbytes = utf8charbytes(s, pos)
        local c = string.sub(s, pos, pos + charbytes - 1)
        newstr = newstr .. (mapping[c] or c)
        pos = pos + charbytes
    end

    return newstr
end
function string.nlower(s)
    local s, res = string.lower(u8:decode(s)), {}
    for i = 1, #s do
        local ch = s:sub(i, i)
        res[i] = ul_rus[ch] or ch
    end
    return u8:encode(table.concat(res))
end
function string.nupper(s)
    local s, res = string.upper(u8:decode(s)), {}
    for i=1, #s do
        local ch = s:sub(i, i)
        res[i] = un_rus[ch] or ch
    end
    return u8:encode(table.concat(res))
end
function string.hexsub(str)
	return str:gsub('{%x%x%x%x%x%x%}', ''):gsub('{%x%x%x%x%x%x%x%x}', ''):gsub('{STANDART}', '')
end
function string.regular(rgx)
	local str = ''
	for i=1, #rgx do
		local sign = rgx:sub(i, i)
		if sign:match('%p') then
			str = str..string.char(37, sign:byte())
		else 
			str = str..string.char(sign:byte())
		end
	end
	return str
end
function urlEncode(str)
	local str = string.gsub(str, "\\", "\\")
	local str = string.gsub(str, "([^%w])", function (str) return string.format("%%%02X", string.byte(str)) end)
	return str
end
function getDownKeys()
    local t = {}
    for index, KEYID in ipairs(hotkey.LargeKeys) do
        if isKeyDown(KEYID) then
            table.insert(t, KEYID)
        end
    end
    return t
end
function GetKeysText(bind)
    local t = {}
    if hotkey.List[bind] then
        for k, v in ipairs(hotkey.List[bind].keys) do
            table.insert(t, vk.id_to_name(v):gsub('Numpad ', 'Num'):gsub('Arrow ', '') or 'UNK')
        end
    end
    return table.concat(t, ' + ')
end
function RegisterCallback(name, keys, callback)
    if hotkey.List[name] == nil then
        hotkey.List[name] = {
            keys = keys,
            callback = callback
        }
        return true else return false
    end
end
function KeyEditor(bindname, text, size)
    if hotkey.List[bindname] then
        local keystext = #hotkey.List[bindname].keys == 0 and hotkey.Text.no_key or GetKeysText(bindname)
        if hotkey.EditKey ~= nil then
            if hotkey.EditKey == bindname then
                keystext = hotkey.Text.wait_for_key
            end
        end 
        if imgui.Button((text ~= nil and text..': ' or '')..keystext..'##hotkey_EDITOR:'..bindname, size) then
            hotkey.Edit.backup = hotkey.List[bindname].keys
            hotkey.List[bindname].keys = {}
            hotkey.EditKey = bindname
        end
        if hotkey.Ret.name ~= nil then
            if hotkey.Ret.name == bindname then
                hotkey.Ret.name = nil
                return hotkey.Ret.data
			end
        end
    else
        imgui.Button('Bind "'..tostring(bindname)..'" not found##hotkey_EDITOR:BINDNAMENOTFOUND', size)
    end
	imgui.Tooltip('Можно использовать любую клавишу или\nкоомбинацию клавиш. (Shift - выключен)\n\nAlt/Ctrl/Space/Enter + Любая клавиша.\nBackspace - Удалить сохранёный бинд.\nESC - Отменить изминение')
end
function saveKeysBind()
	for k, _ in pairs(setup.keys) do
		if hotkey.List[k] then
			setup.keys[k] = hotkey.List[k].keys
		end
	end
	saveFile('settings.cfg', setup)
end
function clearButtons()
	for k, _ in pairs(hotkey.List) do
		local var = k:match('bindCfg_([%d]+)')
		if var then
			hotkey.List['bindCfg_'..var] = nil
		end
	end
end
function sampSetCurrentDialogEditboxTextFix(txt) 
	local txt = tostring(txt)
	
	local sampGetDialogInfoPtr = memory.getuint32(sampModule + 0x26E898)
	local pEditBox = memory.getuint32(sampGetDialogInfoPtr + 0x24)
	local IsActive = memory.getint8(sampGetDialogInfoPtr + 0x28)
	if IsActive then
        setEditboxText = ffi.cast('void(__thiscall *)(uintptr_t this, char* text, int i)', sampModule + 0x84E70)
        setEditboxText(pEditBox, ffi.cast('char*', txt), 0)
    end
end
function setDialogCursorPos(pos)
    local m_pEditbox = memory.getuint32(sampGetDialogInfoPtr() + 0x24, true)
    memory.setuint8(m_pEditbox + 0x119, pos, true)
    memory.setuint8(m_pEditbox + 0x11E, pos, true)
end
function setChatCursorPos(pos)
    local pEditBox = memory.getuint32(sampGetInputInfoPtr() + 0x08, true)
    memory.setuint8(pEditBox + 0x119, pos, true)
    memory.setuint8(pEditBox + 0x11E, pos, true)
end
function getDialogCursorPos()
    local m_pEditbox = memory.getuint32(sampGetDialogInfoPtr() + 0x24, true)
    return memory.getuint8(m_pEditbox + 0x119, true)
end
function getChatCursorPos()
    local pEditBox = memory.getuint32(sampGetInputInfoPtr() + 0x08, true)
    return memory.getuint8(pEditBox + 0x119, true)
end
function pushArrS(arr)
	local arr = decodeJson(encodeJson(arr)) or {}
	for i, name in ipairs(nHelpEsterSet[1]) do
		table.insert(arr, {name, esterscfg.settings[name], nHelpEsterSet[3][i], 'В настройках отсутствует {fead00}'..nHelpEsterSet[2][i]..'{C0C0C0} что-бы использовать в эфире!', nHelpEsterSet[4][i]})
	end
	return arr
end
function regexTag(str, tagsArr)
	if not str then return 'err' end
	for _, t in ipairs(pushArrS(tagsArr)) do
		str = str:gsub('{'..t[1]..'}', t[2] ~= '' and t[2] or t[3])
	end
	return str
end
function findTag(arr, find)
	for _, str in ipairs(arr) do
		if str:find('{'..find..'}') then
			return true
		end
	end
	return false
end
function openMenu()
	if not isPauseMenuActive() then
		rMain[0] = not rMain[0]
		rSW[0] = false
	end
end
function resetIO()
    for i = 0, 511 do
        imgui.GetIO().KeysDown[i] = false
    end
    for i = 0, 4 do
        imgui.GetIO().MouseDown[i] = false
    end
    imgui.GetIO().KeyCtrl = false
    imgui.GetIO().KeyShift = false
    imgui.GetIO().KeyAlt = false
    imgui.GetIO().KeySuper = false
end
addEventHandler('onWindowMessage', function(msg, key)
	if not hotkey then return end
	if isSampAvailable() then
		if (msg == 0x0100 or msg == 260) and not sampIsChatInputActive() then 
			if hotkey.EditKey == nil then
				if (hotkey.no_flood and key ~= hotkey.lastkey) or (not hotkey.no_flood) then
					hotkey.lastkey = key
					for name, data in pairs(hotkey.List) do
						keys = data.keys
						if (#keys == 1 and key == keys[1]) or (#keys == 2 and isKeyDown(keys[1]) and key == keys[2]) then
							if data.callback then data.callback(name) end
						end
					end
				end
				if hotkey.EditKey ~= nil then
					if #hotkey.List[hotkey.EditKey] < 2 then
						table.insert(hotkey.List[hotkey.EditKey], key)
					end
				end
			else
				if key == vk.VK_ESCAPE then
					hotkey.List[hotkey.EditKey].keys = hotkey.Edit.backup
					hotkey.EditKey = nil
					consumeWindowMessage(true, false)
					return
				elseif key == vk.VK_BACK then
					hotkey.List[hotkey.EditKey].keys = {}
					hotkey.EditKey = nil
					saveKeysBind()
					clearButtons()
				end
			end
		elseif (msg == 0x0101 or msg == 261) and not sampIsChatInputActive() then
			if hotkey.EditKey ~= nil then
				if key == vk.VK_BACK then
					hotkey.List[hotkey.EditKey].keys = {}
					hotkey.EditKey = nil
				else
					local PressKey = getDownKeys()
					local LargeKey = PressKey[#PressKey]
					if LargeKey == 16 then return end 
					hotkey.List[hotkey.EditKey].keys = {#PressKey > 0 and PressKey[#PressKey] or key, #PressKey > 0 and key or nil}
					if hotkey.List[hotkey.EditKey].keys[1] == hotkey.List[hotkey.EditKey].keys[2] then
						hotkey.List[hotkey.EditKey].keys[2] = nil
					end
					hotkey.Ret.name = hotkey.EditKey
					hotkey.Ret.data = hotkey.List[hotkey.EditKey].keys
					hotkey.EditKey = nil
				end
			end
		end

		if msg == 0x100  then
			if (key == vk.VK_ESCAPE and (rMain[0] or rHelp[0] or rSW[0])) and not isPauseMenuActive() then
				consumeWindowMessage(true, false)
				if msg == 0x100 then
					if rSW[0] then rSW[0] = false; rMain[0] = true
					else rMain[0] = false; rHelp[0] = false; resetIO() end
				end
			end
		end
	end

end)
function loadVar()
	settingsSCR = {
		['reset'] = 'tet',
		['newsDelay'] = 13,
		['thUpdDesc'] = nil,
		['keys'] = {
			['menu'] = {},
			['helpMenu'] = {vk.VK_DELETE},
			['catchAd'] = {vk.VK_F3},
			['copyAd'] = {vk.VK_DOWN},
			['fastMenu'] = {}
		}
	}
	newsHelpBind = {
		{'Покупка домов',
			{'Куплю дом в ЛС', 'Куплю дом в г. Лос-Сантос. Бюджет: '},
			{'Куплю дом в СФ', 'Куплю дом в г. Сан-Фиерро. Бюджет: '},
			{'Куплю дом в ЛВ', 'Куплю дом в г. Лас-Вентурас. Бюджет: '},
			{'Куплю дом в гетто', 'Куплю дом в опасном районе. Бюджет: '},
			{'Куплю дом в деревне', 'Куплю дом в д. *. Бюджет: '},
			{'Куплю дом в ЛС(Г)', 'Куплю дом в г. Лос-Сантос с гаражом на * мест. Бюджет: '},
			{'Куплю дом в СФ(Г)', 'Куплю дом в г. Сан-Фиерро с гаражом на * мест. Бюджет: '},
			{'Куплю дом в ЛВ(Г)', 'Куплю дом в г. Лас-Вентурас с гаражом на * мест. Бюджет: '},
			{'Куплю дом в деревне(Г)', 'Куплю дом в д. * с гаражом на * мест. Бюджет: '},
			{'Куплю дом в гетто(Г)', 'Куплю дом в опасном районе с гаражом на * мест. Бюджет: '},
			{'Куплю дом в ЛС(П)', 'Куплю дом в г. Лос-Сантос с подвалом. Бюджет: '},
			{'Куплю дом в СФ(П)', 'Куплю дом в г. Сан-Фиерро с подвалом. Бюджет: '},
			{'Куплю дом в ЛВ(П)', 'Куплю дом в г. Лас-Вентурас с подвалом. Бюджет: '},
			{'Куплю дом в деревне(П)', 'Куплю дом в д. * с подвалом. Бюджет: '},
			{'Куплю дом в гетто(П)', 'Куплю дом в опасном районе с подвалом. Бюджет: '},
			{'Куплю дом в ЛС(Г+П)', 'Куплю дом в г. Лос-Сантос с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в СФ(Г+П)', 'Куплю дом в г. Сан-Фиерро с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в ЛВ(Г+П)', 'Куплю дом в г. Лас-Вентурас с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в деревне(Г+П)', 'Куплю дом в д. * с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в гетто(Г+П)', 'Куплю дом в опасном районе с гаражом и подвалом. Бюджет: '},
			{'Куплю дом в любой ТШ', 'Куплю дом в любой точке штата. Бюджет: '},
		},{'Продажа домов',
			{'Продам дом в ЛС', 'Продам дом в г. Лос-Сантос. Цена: '},
			{'Продам дом в СФ', 'Продам дом в г. Сан-Фиерро. Цена: '},
			{'Продам дом в ЛВ', 'Продам дом в г. Лас-Вентурас. Цена: '},
			{'Продам дом в Гетто', 'Продам дом в опасном районе. Цена: '},
			{'Продам дом в ЛС', 'Продам дом в д. *. Цена: '},
			{'Продам дом в ЛС(Г)', 'Продам дом в г. Лос-Сантос с гаражом на * мест. Цена: '},
			{'Продам дом в СФ(Г)', 'Продам дом в г. Сан-Фиерро с гаражом на * мест. Цена: '},
			{'Продам дом в ЛВ(Г)', 'Продам дом в г. Лас-Вентурас с гаражом на * мест. Цена: '},
			{'Продам дом в деревне(Г)', 'Продам дом в д. * с гаражом на * мест. Цена: '},
			{'Продам дом в Гетто (Г)', 'Продам дом в опасном районе с гаражом на * мест. Цена: '},
			{'Продам дом в ЛС(П)', 'Продам дом в г. Лос-Сантос с подвалом. Цена: '},
			{'Продам дом в СФ(П)', 'Продам дом в г. Сан-Фиерро с подвалом. Цена: '},
			{'Продам дом в ЛВ(П)', 'Продам дом в г. Лас-Вентурас с подвалом. Цена: '},
			{'Продам дом в деревне(П)', 'Продам дом в д. * с подвалом. Цена: '},
			{'Продам дом в Гетто (П)', 'Продам дом в опасном районе с подвалом. Цена: '},
			{'Продам дом в ЛС(Г+П)', 'Продам дом в г. Лос-Сантос с гаражом и подвалом. Цена: '},
			{'Продам дом в СФ(Г+П)', 'Продам дом в г. Сан-Фиерро с гаражом и подвалом. Цена: '},
			{'Продам дом в ЛВ(Г+П)', 'Продам дом в г. Лас-Вентурас с гаражом и подвалом. Цена: '},
			{'Продам дом в деревне(Г+П)', 'Продам дом в д. * с гаражом и подвалом. Цена: '},
			{'Продам дом в Гетто (Г+П)', 'Продам дом в опасном районе с гаражом и подвалом. Цена: '},
			{'Продам дом №', 'Продам дом на авеню *. Цена: '}
		},{'Реклама Ломбардов',
			{'329 Ломбард', 'Работает ломбард №329! Самые лучшие цены в штате, ждем именно тебя!'},
			{'330 Ломбард', 'Работает ломбард №330 в Центре Опасного Района, ждем именно тебя!'},
		},{'Реклама Радиоцентров',
			{'Реклама СМИ СФ','Работает СМИ Г.Сан-Фиерро! Ждем ваши объявления!'},
			{'Реклама СМИ ЛС','Работает СМИ Г.Лос-Сантос! Ждем ваши объявления!'},
			{'Реклама СМИ ЛВ','Работает СМИ Г.Лас-Вентурас! Ждем ваши объявления!'},
		},{'Покупка/продажа транспорта',
			{'Продам а/м','Продам а/м "*". Цена: '},
			{'Куплю а/м','Куплю а/м "*". Бюджет: '},
			{'Куплю а/м любой модели','Куплю а/м любой модели. Бюджет: '},
			{'Продам м/ц','Продам м/ц "*". Цена: '},
			{'Куплю м/ц','Куплю м/ц "*". Бюджет: '},
			{'Куплю м/ц любой модели','Куплю м/ц любой модели. Бюджет: '},
			{'Продам л/д', 'Продам л/д "*". Цена: '},
			{'Куплю л/д', 'Куплю л/д "*". Бюджет: '},
			{'Куплю л/д любой модели', 'Куплю л/д любой марки. Бюджет: '},
			{'Продам с/т', 'Продам с/т "*". Цена: '},
			{'Куплю с/т', 'Куплю с/т. Бюджет: '},
			{'Куплю с/т любой модели', 'Куплю с/т любой модели. Бюджет: '},
			{'Продам в/т', 'Продам в/т "*". Цена: '},
			{'Куплю в/т', 'Куплю в/т "*". Бюджет: '},
			{'Куплю в/т любой модели', 'Куплю в/т любой модели. Бюджет: '},
			{'Продам г/м', 'Продам г/м  "*". Цена: '},
			{'Куплю г/м', 'Куплю г/м  "*". Бюджет: '},
			{'Куплю г/м любой модели', 'Куплю г/м любой модели. Бюджет: '}
		},{'Продажа/покупка б/зов',
			{'Продам б/з в ЛС','Продам б/з * в г. Лос-Сантос. Цена: '},
			{'Куплю б/з в ЛС','Куплю б/з * в г. Лос-Сантос. Бюджет: '},
			{'Куплю б/з','Куплю б/з в любой точке штата. Бюджет: '},
			{'Продам б/з в СФ','Продам б/з * в г. Сан-Фиерро. Цена: '},
			{'Куплю б/з в СФ','Куплю б/з в г. Сан-Фиерро. Бюджет: '},
			{'Продам б/з','Продам б/з * №* . Цена:'},
			{'Продам б/з в ЛВ','Продам б/з * в г Лас-Вентурас. Цена: '},
			{'Куплю б/з в ЛВ','Куплю б/з в г. Лас-Вентурас. Бюджет: '},
			{'Продам б/з в ФК','Продам б/з в *. Цена: '},
			{'Куплю б/з где угодно','Куплю б/з в любой точке штата. Бюджет: '},
		},{'Покупка/продажа аксессуаров/скинов',
			{'Куплю а/с','Куплю а/с "*". Бюджет: '},
			{'Продам а/с','Продам а/с "*". Цена: '},
			{'Куплю а/с с заточкой','Куплю а/с "*" с гравировкой "+*". Бюджет: '},
			{'Продам а/с с заточкой','Продам а/с "*" с гравировкой "+*". Цена: '},
			{'Куплю скин','Куплю о/п с любого типа. Бюджет: '},
			{'Куплю скин по айди','Куплю о/п с биркой "*". Бюджет: '},
			{'Продам скин по имени','Куплю о/п "*". Бюджет: '},
			{'Продам скин по айди','Продам о/п с биркой "*". Цена: '}
		},{'Реклама б/зов',
			{'Работает бар','Работает бар №*, у нас самая вкусная еда и напитки! Приезжайте'},
			{'Работает закусочная','Работает закусочная №*, у нас самые дешевые цены во всем штате'},
			{'Работает отель','Работает отель №*, у нас самое дешевое заселение! Приезжайте'},
			{'Работает 24/7','Работает магазин 24/7 №*, у нас самые дешевые цены! Успей закупиться'},
			{'Работает АЗС','Работает АЗС №*, у нас самое качественное топливо. Ждем вас'},
			{'Работает аммунация','Работает аммунация №*, у нас самые качественные боеприпасы. '},
			{'Работает СТО по ремонту','Работает СТО по ремонту двигателей в д. *. У нас все дешево'},
			{'Работает СТО по тюнингу','Работает СТО в г. *, быстрый и качественный тюнинг вашего автомобиля'},
			{'Работает ремонт одежды','Порвалась одежды? Тогда тебе в Ремонт Одежды №* в д.'},
			{'Работает школа танцев','Хочешь чтобы все девочки были твои? Тебе в школу танцев г. '},
			{'Работает магазин одежды','Не хочешь выглядеть как бомж? Тогда тебе в магазин одежды №'},
			{'Работает нефтевышка', 'Самая лучшая нефть только у нас! Приезжай на нефтевышку № '}
		},{'Собеседования гетто/мафии',
			{'Warlock MC','Проходит собеседование в бар "Бородатая фея". Ждем в баре'},
			{'Russian Mafia','Проходит собеседование в ЦВСП "Русская Мафия". Встреча у особняка'},
			{'LCN','Проходит набор в СК "Чарлиз". Встреча у особняка'},
			{'Yakuza','Проходит собеседование в японский ресторан "Yakuza". Встреча в ресторане'},
			{'Tierra Robada Bikers', 'Проходит собеседование в бар "Tierra Robada Bikers". Ждем в баре'},
			{'Night Wolfs','Проходит собеседование в БК "Night Wolfs". Желающих ждём на районе'},
			{'Groove','Проходит набор в БК "Groove".  Желающих ждём на районе'},
			{'The Ballas','Проходит набор в БК "Ballas". Желающих ждём на районе'},
			{'The Vagos','Проходит набор в БК "Vagos". Желающих ждём на районе'},
			{'The Aztecas','Проходит набор в БК "Aztec". Желающих ждём на районе'},
			{'The Rifa','Проходит набор в БК "Rifa". Желающих ждём на районе'}
		},{'Собеседования госс',
			{'СМИ','Проходит собеседование в СМИ г. *. Ждем Вас!'},
			{'ПД','Проходит собеседование в полицию г. *. Ждем в холле!'},
			{'МЗ','Проходит собеседование в больницу г. *. Ждем Вас! '},
			{'ДТЛ','Проходит собеседование в ДТЛ! Ждем именно тебя!'},
			{'ТСР','Проходит собеседование в Тюрьму Строгого Режима! Ждем Вас!'},
			{'МО','Проходит собеседование в армию г. *! Ждем вас в военкомате! '},
			{'СТК', 'Проходит собеседование в Страховую Компанию! Ждем именно тебя!'},
			{'Пра-во','Проходит собеседование в Правительство! Ждем Вас в холле!'}
		},{'Семьи',
			{'Со всеми Улучшений', 'Семья "*" со всеми нашивками ищет родственников'},
			{'Без Улучшений', 'Семья * ищет родственников.'},
			{'Ищу семью', 'Ищу семью. О себе при встрече. Просьба связаться'}
		},{'Семейные талоны',
			{'Куплю семейные талоны','Куплю р/с "Семейный талон". Бюджет/шт:'},
			{'Продам семейные талоны','Продам р/с "Семейные талоны". Цена: */шт'},
			{'Куплю семейные талоны (кол-во)','Куплю р/с "Семейные талоны" в количестве * штук. Бюджет: '},
			{'Продам семейные талоны (кол-во)','Продам р/с "Семейные талоны" в количестве * штук. Цена: */шт'}
		},{'Покупка/продажа гражданских талонов',
			{'Куплю гражданские талоны','Куплю р/с "Гражданские талоны". Бюджет: '},
			{'Продам гражданские талоны','Продам р/с "Гражданские талоны". Цена: */шт'},
			{'Куплю гражданские талоны (кол-во)','Куплю р/с "Гражданские талоны" в количестве * штук. Бюджет: '},
			{'Продам гражданские талоны (кол-во)','Продам р/с "Гражданские талоны" в количестве * штук. Цена: */шт'}
		},{'Покупка/продажа ресурсов/подарков',
			{'Куплю р/с','Куплю р/с "". Бюджет: */шт'},
			{'Продам р/с','Продам р/с "". Цена: */шт'},
			{'Куплю подарки','Куплю р/с "Подарок". Бюджет: */шт'},
			{'Продам подарки','Продам р/с "Подарок". Цена: */шт'}
		},{'Покупка/Продажа "д/т, телефонов, модификаций"',
			{'Куплю тюнинг','Куплю д/т "*". Бюджет:'},
			{'Продам тюнинг','Продам д/т "*". Цена:'},
			{'Куплю телефон','Куплю т/ф "*". Бюджет:'},
			{'Продам телефон ','Продам т/ф "*". Цена: '},
			{'Куплю м/д ','Куплю м/ф "" для а/м "". Бюджет:'},
			{'Продам м/д ','Продам м/ф "" для а/м "". Цена:'}
		},{'Аренда',
			{'Сдам машину', 'Сдам а/м "*". Цена: '},
			{'Сдам охранника с доп зп', 'Сдам визитку охранника с нашивкой "доп зп*". Бюджет: '},
			{'Сдам фуру', 'Сдам г/м "*". Цена: '},
			{'Сдам самолет', 'Сдам с/т "*". Цена: '},
			{'Сдам аксессуар', 'Сдам а/с "*". Цена: '},
			{'Сдам лодку', 'Сдам л/д "*". Цена: '},
			{'Арендую машину', 'Арендую а/м "*". Бюджет: '},
			{'Арендую охранника с доп зп', 'Арендую визитку охранника с нашивкой "доп зп*". Бюджет: '},
			{'Арендую фуру', 'Арендую г/м "*". Бюджет: '},
			{'Арендую самолет', 'Арендую с/т "*". Бюджет: '},
			{'Арендую аксессуар', 'Арендую а/с "*". Бюджет: '},
			{'Арендую лодку марки', 'Арендую л/д "*". Бюджет: '}
		},{'Разное(AZ, EXP)',
			{'Куплю AZ', 'Куплю р/с "Талон на AZ-Coin". Бюджет: '},
			{'Продам AZ', 'Продам р/с "Талон на AZ-Coin". Цена: '},
			{'Куплю EXP', 'Куплю талон "Передаваемые EXP". Бюджет: '},
			{'Продам EXP', 'Продам талон "Передаваемые EXP". Цена: '},
		}
	}
	nHelpEsterSet = {
		{'name','duty','tagCNN','city','server','music'},
		{'имя и фамилия', 'должность', 'тег в депортамент', 'город', 'имя штата', 'Музыкальная заставка'},
		{'Faiser Andreich', 'Директор', 'СМИ СФ', 'Сан-Фиерро', 'Скоттдейл', '°°°°Музыкальная заставка радиостанции г.Сан-Фиерро°°°°'},
		{'Ваше имя', 'Ваша должность', 'Тег в депортамент', 'Город вашей СМИ', 'Название вашего сервера', 'Музыкальная заставка'}
	}
	newsHelpEsters = {
		['reset'] = 'bit4',
		['settings'] = {
			['name'] = '',
			['duty'] = '',
			['tagCNN'] = 'СМИ СФ',
			['city'] = 'Сан-Фиерро',
			['server'] = 'Скоттдейл',
			['music'] = '•°•°•°•°Музыкальная заставка радиостанции г.Сан-Фиерро•°•°•°•°',
			['delay'] = 4
		},
		['events'] = {
			['write'] = {'Написать в /news', '/news {tag}'},
			['actions'] = {
				{'RP начало',
					'/me протянул руку к ноутбуку, после чего нажал на кнопку включения, а затем сел на кресло.',
          			'/do Ноутбук успешно включился.',
          			'/me зашел в программу {server}" News", нажал на {city}, выбрал "Математика" и нажал на кнопку "Начать".',
          			'/me пододвинул к себе стойку с микрофоном, а затем включил его.'
				}, {'RP конец',
					'/me отодвинул от себя стойку с микрофоном, нажал на кнопку его выключения.',
        			'/me в программе "{server} News" нажал на "Завершить", после чего выключил ноутбук.',
    				'/do Спустя какое-то время ноутбук выключился.',
    				'/me закрыл крышку, а затем встал с кресла и направился к выходу из комнаты.'
				}, ['name'] = 'actions'
			},
			['mathem'] = {
				{'Начать эфир',
					'/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {duty} СМИ г. {city}',
					'/news {tag}{name}!',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Математика".',
					'/news {tag}Просьба отложить все дела и поучаствовать!',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я задаю математический пример, а слушатели должны написать ответ.',
					'/news {tag}Первый гражданин, который ответит правильно — получает балл. Играем до {scores} баллов.',
					'/news {tag}Приз на сегодня составляет {prize} долларов штата {server}.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ»,',
					'/news {tag}Главное, выбирайте радиостанцию г. {city} и отправляйте свой ответ.',
					'/news {tag}Ну что ж, давайте начинать!'
				}, {'Следующий пример',
					'/news {tag}Следующий пример...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время попрощаться с вами.',
					'/news {tag}Сегодня мы изучали математику вместе со мной.',
					'/news {tag}Думаю интересное вышло мероприятие…',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}] to [СМИ] Освободил развлекательную волну, ценю, что не перебивали, до связи!'
				}, ['name'] = 'mathem', ['tag'] = '[Математика]: '
			},
			['chemic'] = {
				{'Начать эфир',
					'/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} СМИ г. {city}',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Химические элементы".',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я называю какой-то химический элемент из таблицы Менделеева,...',
					'/news {tag}...а вы должны написать название этого элемента.',
					'/news {tag}Например, "О" — "Кислород".',
					'/news {tag}Гражданин, который правильно и быстрее всех напишет...',
					'/news {tag}...{scores} таких элемента, побеждает в мероприятии.',
					'/news {tag}Он или она забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, выбирайте контакт «Написать в СМИ»...',
					'/news {tag}...выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}Сейчас я посмотрю интересные элементы и мы начнем!'
				}, {'Следующий элемент',
					'/news {tag}Следующий элемент...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время попрощаться с вами.',
					'/news {tag}Сегодня мы узнали некоторые химические элементы.',
					'/news {tag}Думаю интересное вышло мероприятие…',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}] to [СМИ] Освободил развлекательную волну, ценю, что не перебивали, до связи!'
				}, ['name'] = 'chemic', ['tag'] = '[Хим.Элементы]: '
			},
			['greet'] = {
				{'Начать эфир',
					'/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} СМИ г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Приветы и поздравления".',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Слушателям необходимо отправлять сообщения с приветами и...',
					'/news {tag}...поздравлениями в наше СМИ.',
					'/news {tag}А ведущий будет зачитывать их на весь штат {server}.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны и выбирайте контакт «Написать в СМИ»...',
					'/news {tag}...выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}Мероприятие будет длится около {time} минут, и я постараюсь...',
					'/news {tag}...передать приветы всем желающим.',
					'/news {tag}И так, давайте начнем. Жду ваши сообщения!'
				}, {'Передать привет',
					'/news {tag}{ID} передаёт привет {toID}!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня вы передали привет своим знакомым и близким...',
					'/news {tag}...с помощью нашего эфира.',
					'/news {tag}Думаю интересное вышло мероприятие...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}] to [СМИ] Освободил развлекательную волну, ценю, что не перебивали, до связи!'
				}, ['name'] = 'greet', ['tag'] = '[Приветы]: '
			},
			['tohide'] = {
				{'Начать эфир',
					'/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему «Прятки».',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я нахожусь на определенном месте на территории штата {server}...',
					'/news {tag}... и описываю свою местоположение.',
					'/news {tag}Ваша задача — найти меня.',
					'/news {tag}Звучит чертовски просто, но это не так...',
					'/news {tag}Гражданин, который сможет найти меня, должен сказать фразу-ключ.',
					'/news {tag}Без этого «ключа» Вы не сможете получить денежный приз.',
					'/news {tag}Фраза такая: «{phrase}»',
					'/news {tag}Первый, кто произнесет фразу, забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Если в течении {time} минут никто не сможет меня найти, то я...',
					'/news {tag}...называю свое местоположение в GPS.',
					'/news {tag}И тогда вы точно меня найдете...',
					'/news {tag}Игра объявляется начатой!',
				}, {'Назвать победителя',
					'/news {tag}Стоп игра, господа, у нас есть победитель «Пряток»!',
					'/news {tag}Первым был {ID}! Поздравляю вас, ваш выйграшь {prize}.'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня вы попытались найти меня на территории штата {server}.',
					'/news {tag}И одному гражданину это получилось, с этим мы его можем поздравить!',
					'/news {tag}Думаю интересное вышло мероприятие...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}] to [СМИ] Освободил развлекательную волну, ценю, что не перебивали, до связи!'
				}, ['name'] = 'tohide', ['tag'] = '[Прятки]: '
			},
			['capitals'] = {
				{'Начать эфир',
					'/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} СМИ г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Столицы".',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я говорю название страны в любой точке мира, ...',
					'/news {tag}... а вы должны написать сообщение с ответом на мой вопрос.',
					'/news {tag}Первый гражданин, кто ответил правильно, получает один балл.',
					'/news {tag}Всего можно заработать {scores} балла!',
					'/news {tag}Первый, кто достигнет эту отметку, забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр…',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ»...',
					'/news {tag}... выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}И так... мы начинаем!!!'
				}, {'Следующий пример',
					'/news {tag}Следующий вопрос...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это {ID}',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}Вы набрали нужное кол-во баллов.',
					'/news {tag}{ID}, я вас поздравляю! Ваш выигрыш {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня мы с вами узнали некоторые страны и их столицы.',
					'/news {tag}Думаю вам было интересно...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и берегите своих близких!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}] to [СМИ] Освободил развлекательную волну 114.6 FM, до связи!'
				}, ['name'] = 'capitals', ['tag'] = '[Столицы]: '
			},
			['mirror'] = {
				{'Начать эфир',
					'/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Сейчас пройдет прямой эфир на тему «Зеркало».',
					'/news {tag}Просьба отложить все дела и поучаствовать...',
					'/news {tag}Объясняю правила мероприятия...',
					'/news {tag}Я называю какое-то слово в инверсированном порядке.',
					'/news {tag}То есть привычное нам слово наоборот, ...',
					'/news {tag}... например, «Яблоко» - «Околбя».',
					'/news {tag}Понять что это за слово не так просто, но уверен, что вы справитесь.',
					'/news {tag}Гражданин, который правильно и быстрее всех напишет ...',
					'/news {tag}... {scores} таких слова, побеждает в мероприятии.',
					'/news {tag}И забирает денежный приз.',
					'/news {tag}Приз на сегодня составляет {prize} долларов.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ» ...',
					'/news {tag}... выбирайте радиостанцию г. {city} и отправляете ответ.',
					'/news {tag}Сейчас я поищу интересные слова и мы начнем!'
				}, {'Следующий пример',
					'/news {tag}Следующий пример...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время прощаться с вами.',
					'/news {tag}Сегодня вы учились вместе со мной разгадывать слова с инверсией.',
					'/news {tag}Так сказать, учились новому языку вместе с любимым ведущим!',
					'/news {tag}Думаю интересное вышло мероприятие...',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}] to [СМИ] Освободил развлекательную волну, ценю, что не перебивали, до связи!'
				}, ['name'] = 'mirror', ['tag'] = '[Зеркало]: ',
				['notepad'] = 'Анишам = Машина\nАгинк = Книга\nЛотс = Стол\nАкчур = Ручка\nЬтаворк = Кровать\nАклобтуф = Футболка\nСуболг = Глобус\nАнитрак = Картина\nЛутс = Стул\nЕинетсар = Растение\nАде = Еда\nАдогоп = Погода\nРетюьпмок = Компьютер\nАклерат = Тарелка\nАнетс = Стена\nТок = Кот\nЬдевдем = Медведь\nАбыр = Рыба\nЕьлесев = Веселье\nНизагам = Магазин\n'
			},
			['interpreter'] = {
				{'Начать эфир',
					'/d [{tagCNN}] to [СМИ] Занимаю развлекательную волну. Просьба не перебивать!',
					'/news {music}',
					'/news {tag}Приветствую вас, дорогие слушатели штата {server}.',
					'/news {tag}У микрофона {duty} СМИ г. {city}',
					'/news {tag}{name}!',
					'/news {tag}Сейчас пройдет прямой эфир на тему "Переводчики".',
					'/news {tag}Просьба отложить все дела и поучаствовать!',
					'/news {tag}Я говорю слово на {language}ом языке, а вы должны написать ответ.',
					'/news {tag}Проверим ваши знания данного языка, это не самая простая задача...',
					'/news {tag}Первый гражданин, который ответит правильно — получает балл. Играем до {scores} баллов.',
					'/news {tag}Приз на сегодня составляет {prize} долларов штата {server}.',
					'/news {tag}Деньги небольшие, но пригодятся каждому.',
					'/news {tag}Напоминаю, что писать сообщения нужно в радиоцентр...',
					'/news {tag}Доставайте свои телефоны, открывайте контакты и «Написать в СМИ»,',
					'/news {tag}Главное, выбирайте радиостанцию г. {city} и отправляйте свой ответ.',
					'/news {tag}Ну что ж, давайте начинать!'
				}, {'Следующее слово',
					'/news {tag}Следующий слово такое ...'
				}, {'Стоп!',
					'/news {tag}Стоп! Стоп! Стоп!'
				}, {'Тех. неполадки!',
					'/news {tag}Тех. неполадки! Не переключайтесь, скоро продолжим...'
				}, {'Первым был',
					'/news {tag}Первым был {ID}! И у него уже {scoreID} правильных ответов!'
				}, {'Назвать победителя',
					'/news {tag}И у нас есть победитель!',
					'/news {tag}И это...',
					'/news {tag}{ID}! Так как именно Вы набрали {scores} правильных ответов!',
					'/news {tag}{ID}, я вас поздравляю! Ваш выиграшь {prize}$!',
					'/news {tag}{ID}, я прошу Вас приехать к нам...',
					'/news {tag}В радиоцентр г. {city} за получением своей награды.'
				}, {'Закончить эфир',
					'/news {tag}Ну что ж, дорогие слушатели!',
					'/news {tag}Пришло время попрощаться с вами.',
					'/news {tag}Сегодня вы изучали {language}ий язык, вместе со мной.',
					'/news {tag}Думаю интересное вышло мероприятие…',
					'/news {tag}С вами был {name}, {duty} радиостанции г. {city}.',
					'/news {tag}Будьте грамотными и всего хорошего Вам и вашим близким!',
					'/news {tag}До встречи в эфире!!!',
					'/news {music}',
					'/d [{tagCNN}] to [СМИ] Освободил развлекательную волну, ценю, что не перебивали, до связи!'
				}, ['name'] = 'interpreter', ['tag'] = '[Переводчики]: '
			}
		}
	}
	langArr = {
		['tags'] = {'ru', 'en', 'fr', 'es', 'de', 'it'--[[, 'zh', 'kk']]},
		['ru'] = {
			'Машина', 'Книга', 'Стол', 'Ручка', 'Кровать', 'Футболка', 'Глобус', 'Картина', 'Стул', 'Растение',
			'Еда', 'Погода', 'Компьютер', 'Тарелка', 'Стена', 'Кот', 'Медведь', 'Рыба', 'Веселье', 'Магазин'
		},
		['en'] = {
			'Car', 'Book', 'Table', 'Pen', 'Bed', 'T-shirt', 'Globe', 'Picture', 'Chair', 'Plant', 'Meal',
			'Weather', 'Computer', 'Plate', 'Wall', 'Cat', 'Bear', 'Fish', 'Fun', 'Shop'
		},
		['fr'] = {
			'Machine', 'Livre', 'Bureau', 'Poignee', 'Lit', 'T-shirt', 'Globe', 'Peinture', 'Chaise', 'Plante',
			'Repas', 'Temps', 'Ordinateur', 'Assiette', 'Mur', 'Chat', 'Ours', 'Poisson', 'Gaiete', 'Boutique'
		},
		['es'] = {
			'Maquina', 'Libro', 'Mesa', 'Manija', 'Cama', 'Camiseta', 'Globo', 'Pintura', 'Silla', 'Planta',
			'Comida', 'Tiempo', 'Ordenador', 'Plato', 'Pared', 'Gato', 'Oso', 'Pez', 'Alegria', 'Tienda'
		},
		['de'] = {
			'Auto', 'Das Buch', 'Der Tisch', 'Stift', 'Bett', 'T-Shirt', 'Der Globus', 'Das Bild', 'Der Stuhl', 'Die Pflanze',
			'Essen', 'Das Wetter', 'Computer', 'Teller', 'Die Wand', 'Der Kater', 'Der Bar', 'Fisch', 'Spab', 'Geschaft'
		},
		['it'] = {
			'Macchina', 'Libro', 'Tavolo', 'Maniglia', 'Letto', 'Maglia', 'Globo', 'Dipinto', 'Sedia', 'Pianta',
			'Pasto', 'Tempo', 'Computer', 'Scodellino', 'Parete', 'Gatto', 'Orso', 'Pesce', 'Allegria', 'Negozio'
		}--[[,
		['zh'] = {
			'??', '?', '?', '???', '?', 'T??', '??', '??', '??', '??', '??', '????',
			'??', '??', '??', '??', '??', '?', '??', '??'
		},
		['kk'] = {
			'Машина', 'Кітап', '?стел', '?алам', 'Т?сек', 'Футболка', 'Глобус', 'Сурет', 'Орынды?', '?сімдік',
			'Тама?', 'Ауа райы', 'Компьютер', 'Таба?', '?абыр?а', 'Мысы?', 'Аю', 'Балы?', 'К??ілді', 'Д?кен'
		}]]
	}
	newsAutoBind = {{'..'},
		{'тт', 'Twin Turbo'},
		{'анб', 'антибиотики'},
		{'кр', 'коронавирус'},
		{'цв', 'цвета'},
		{'см', 'Санта-Мария '},
		{'фея', '"Бородатая фея" '},
		{'наш', 'со всеми нашивками '},
		{'ищр', 'ищет родных'},
		{'грув', 'БК "Грув". '},
		{'баллас', 'БК "Баллас". '},
		{'вагос', 'БК "Вагос". '},
		{'ацтек', 'БК "Ацтек". '},
		{'рифа', 'БК "Рифа". '},
		{'дпк', 'д. Паломино-Крик. '},
		{'дтр', 'д. Тиерро-Робада. '},
		{'дфк', 'д. Форт-Карсон. '},
		{'дрк', 'д. Ред-Каунтри. '},
		{'дпх', 'д. Паломино-Хиллс. '},
		{'дап', 'д. Ангел-Пайн. '},
		{'гвв', 'г. Вайн-Вуд. '},
		{'вв', 'Вайн-Вуд. '},
		{'вг', 'военном городке.'},
		{'00', '.OOO.OOO$'},
		{'01', '.OOO$/шт'},
		{'02', '.OOO$/час'},
		{'про', 'РСФ || ПРО -> '},
		{'опш', 'о/п пошива '},
		{'осб', 'о/п с биркой '},
		{'лс', 'Лос-Сантос'},
		{'сф', 'Сан-Фиерро'},
		{'лв', 'Лас-Вентурас'},
		{'лм', 'любой марки'},
		{'опл:', 'Оплата: '},
		{'оплд', 'Оплата: Договорная'},
		{'лш', 'лет в штате.'},
		{'ор', 'в опасном районе. '}
	}
	newsKeyBind = {
		{{vk.VK_CONTROL, vk.VK_1}, 'Бюджет: Свободный'},
		{{vk.VK_CONTROL, vk.VK_2}, 'Цена: Договорная'},
		{{vk.VK_CONTROL, vk.VK_NUMPAD7}, 'г. Лос-Сантос. '},
		{{vk.VK_CONTROL, vk.VK_NUMPAD8}, 'г. Сан-Фиерро. '},
		{{vk.VK_CONTROL, vk.VK_NUMPAD9}, 'г. Лас-Вентурас. '},
		{{vk.VK_MENU, vk.VK_1}, 'Бюджет: '},
		{{vk.VK_MENU, vk.VK_2}, 'Цена: '},
		{{vk.VK_CONTROL, vk.VK_5}, 'дом с гаражем'},
		{{vk.VK_MENU, vk.VK_Q}, 'а/м '},
		{{vk.VK_MENU, vk.VK_W}, 'м/ц '},
		{{vk.VK_MENU, vk.VK_E}, 'в/т '},
		{{vk.VK_MENU, vk.VK_R}, 'а/с '},
		{{vk.VK_MENU, vk.VK_T}, 'б/з '},
		{{vk.VK_MENU, vk.VK_Y}, 'с/т '},
		{{vk.VK_MENU, vk.VK_U}, 'в/с '},
		{{vk.VK_MENU, vk.VK_I}, 'т/с '},
		{{vk.VK_MENU, vk.VK_6}, '$'}
	}
	callbacks = {
		calc = ffi.cast('int (*)(ImGuiInputTextCallbackData* data)', function(data)
			local txtIpt = ffi.string(data.Buf)
			local txtMatch = '[^%d%+%-%^%/%(%)%*%s%.]+'
			if txtIpt:match(txtMatch) then
				local share = false
				if txtIpt:match('[\\|]+') then
					share = txtIpt:find('[\\|]+')
					data:InsertChars(share, '/')
				end
				local intCh = txtIpt:find(txtMatch)
				data:DeleteChars(intCh - 1, string.match(txtIpt:sub(intCh, intCh), '[^%w%p]') and 2 or 1)
				data.CursorPos = intCh - (share and 0 or 1)
			end
			return 0
		end),
		bindtag = ffi.cast('int (*)(ImGuiInputTextCallbackData* data)', function(data)
			local txtIpt = ffi.string(data.Buf)
			local txtMatch = '[%c][%c]'
			if txtIpt:match(txtMatch) then
				local intCh = txtIpt:find(txtMatch)
				if intCh > tmp.callBT or intCh == tmp.callBT then -- enter >; backspace <
					data:InsertChars(intCh + 1, '/news \n')
					data:DeleteChars(intCh, 1)
					data.CursorPos = intCh + 6
				else
					data:DeleteChars(intCh, 1)
				end
			end
			if tmp.callBT ~= data.CursorPos then
				tmp.callBT = data.CursorPos
			end
			return 0
		end)
	}
	hotkey = {
		no_flood = false,
		lastkey = 9999,
		MODULEINFO = {
			version = 2,
			author = 'chapo'
		},
		Text = {
			wait_for_key = 'Нажмите...',
			no_key = 'Нет'
		},
		List = {},
		EditKey = nil,
		Edit = {
			backup = {},
			new = {}
		},
		Ret = {name = nil, data = {}},
		LargeKeys = {vk.VK_SHIFT, vk.VK_SPACE, vk.VK_CONTROL, vk.VK_MENU, vk.VK_RETURN}
	}
end
function Style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
  
    style.WindowPadding = imgui.ImVec2(15, 15)
    style.WindowRounding = 10.0
    style.ChildRounding = 6.0
    style.FramePadding = imgui.ImVec2(8, 7)
    style.FrameRounding = 5.0
    style.ItemSpacing = imgui.ImVec2(8, 8)
    style.ItemInnerSpacing = imgui.ImVec2(10, 6)
    style.IndentSpacing = 25.0
    style.ScrollbarSize = 13.0
    style.ScrollbarRounding = 12.0
    style.GrabMinSize = 10.0
    style.GrabRounding = 6.0
    style.PopupRounding = 8
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    style.Colors[imgui.Col.Text]                   = imgui.ImVec4(0.90, 0.90, 0.93, 1.00)
    style.Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.18, 0.20, 0.22, 1.00)
    style.Colors[imgui.Col.Border]                 = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.10, 0.10, 0.12, 1.00)
    style.Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.15, 0.15, 0.17, 1.00)
    style.Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.14, 1.00)
    style.Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.30, 0.30, 0.35, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.CheckMark]              = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.70, 0.70, 0.90, 1.00)
    style.Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.80, 0.80, 0.90, 1.00)
    style.Colors[imgui.Col.Button]                 = imgui.ImVec4(0.18, 0.18, 0.20, 1.00)
    style.Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.28, 0.56, 0.96, 1.00)
    style.Colors[imgui.Col.Header]                 = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.Separator]              = imgui.ImVec4(0.40, 0.40, 0.45, 1.00)
    style.Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.50, 0.50, 0.55, 1.00)
    style.Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.60, 0.60, 0.65, 1.00)
    style.Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(0.20, 0.20, 0.23, 1.00)
    style.Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(0.25, 0.25, 0.28, 1.00)
    style.Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    --style.Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0, 0.60, 0.64, 1.00)
    style.Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.61, 0.61, 0.64, 1.00)
    style.Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(0.70, 0.70, 0.75, 1.00)
    style.Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(0.30, 0.30, 0.34, 1.00)
    style.Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.10, 0.10, 0.12, 0.80)
    style.Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.18, 0.20, 0.22, 1.00)
    style.Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.60, 0.60, 0.90, 1.00)
    style.Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.28, 0.56, 0.96, 1.00)
end
