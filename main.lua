-- Contrôleur Principal v2 - ComputerCraft

-- Charger les bibliothèques nécessaires
print("[Controller] Tentative de chargement de Basalt...")
local basalt_status, basalt_or_error = pcall(require, "basalt")

if not basalt_status then
    print("ERREUR CRITIQUE: Impossible de require('basalt'). Erreur: " .. tostring(basalt_or_error))
    error("Echec du require('basalt')")
end
local basalt = basalt_or_error
print("[Controller] Basalt charge. Type de 'basalt': " .. type(basalt))

if type(basalt) == "table" then
    print("[Controller] Contenu de la table 'basalt' exposee par require('basalt'):")
    local count = 0
    for k, v in pairs(basalt) do
        print("  - Cle: '" .. tostring(k) .. "', Type: " .. type(v))
        count = count + 1
    end
    if count == 0 then
        print("  La table 'basalt' est vide.")
    end
else
    print("[Controller] ATTENTION: 'basalt' n'est pas une table apres require! Type recu: " .. type(basalt))
    print("[Controller] Cela indique un probleme majeur avec l'installation de Basalt ou le fichier basalt/init.lua.")
    error("Basalt n'a pas retourne une table.")
end


-- Gestion de l'API Parallel
local parallel_api
local parallel_available = false
local status_parallel, res_parallel = pcall(function() parallel_api = require("parallel") end)

if status_parallel and type(parallel_api) == "table" and parallel_api.waitForAny then
    parallel_available = true
    print("[Controller] API Parallel chargee avec succes.")
else
    print("[Controller] ATTENTION: API Parallel non disponible ou n'a pas pu etre chargee.")
    if not status_parallel then print("[Controller] Erreur pcall pour require('parallel'): " .. tostring(res_parallel)) end
end

-- [[ Configuration ]]
local MODEM_CHANNEL = 65001
local DEBUG_MODE = true

-- [[ Variables Globales ]]
local enderModem
local apDevice
local mainFrame, navBarFrame
local keypad = { frame = nil, display = nil, buffer = "", isVisible = false, target = nil }
local pages = {}
local pageOrder = {"dashboard", "autocraft", "turtleMap", "turtleAnalysis", "reactor"}
local pageTitles = {
    dashboard = "Tableau de Bord", autocraft = "Autocraft AE2", turtleMap = "Carte & Turtles",
    turtleAnalysis = "Analyse Turtles", reactor = "Controle Reacteur"
}
local currentPageName = pageOrder[1]

-- [[ Fonctions Utilitaires ]]
local function log(message) if DEBUG_MODE then print("[Controller] " .. tostring(message)) end end

local function transmitModemMessage(messageTable)
    if enderModem and enderModem.isOpen() and enderModem.transmit then
        local success, err = enderModem.transmit(MODEM_CHANNEL, MODEM_CHANNEL, messageTable)
        if not success then log("Erreur transmission modem: " .. tostring(err)) end
        return success
    end
    return false
end

-- [[ Initialisation des Périphériques ]]
local function initPeripherals()
    log("Initialisation des peripheriques...")
    local modemSide = peripheral.find("ender_modem")
    if modemSide then enderModem = modemSide; enderModem.open(MODEM_CHANNEL); log("Modem Ender ouvert canal " .. MODEM_CHANNEL)
    else log("ATTENTION: Modem Ender non trouve.") end

    local foundAPDevice
    local apTypesToTry = {"me_controller", "ae2_interface", "ae_controller"}
    for _, pType in ipairs(apTypesToTry) do foundAPDevice = peripheral.find(pType); if foundAPDevice then break end end
    if not foundAPDevice then
        for _, name in ipairs(peripheral.getNames()) do
            if string.match(peripheral.getType(name) or "", "ae2") or string.match(peripheral.getType(name) or "", "me_controller") then
                foundAPDevice = peripheral.wrap(name); log("Peripherique AP trouve: " .. name); break
            end
        end
    end
    if foundAPDevice then apDevice = foundAPDevice; log("Advanced Peripherals (AE2) connecte. Type: " .. (peripheral.getType(apDevice.getName()) or "inconnu"))
    else log("ATTENTION: Aucun peripherique Advanced Peripherals (AE2) trouve.") end
end

-- [[ Gestion des Pages et Navigation ]]
local function showPage(pageNameToShow, isRemoteCall)
    isRemoteCall = isRemoteCall or false
    if not pages[pageNameToShow] then log("Erreur: Page '" .. pageNameToShow .. "' inconnue."); return end
    for name, frame in pairs(pages) do
        if frame and frame.setVisible then frame:setVisible(name == pageNameToShow)
        else log("ATTENTION: frame.setVisible manquant pour page " .. name) end
    end
    currentPageName = pageNameToShow; log("Affichage page: " .. pageNameToShow)
    if not isRemoteCall then transmitModemMessage({type = "page_change", page = pageNameToShow}) end
end

-- [[ Création des Éléments UI ]]
local function createMainFrame()
    log("Debut createMainFrame")
    if not term or not term.getSize then log("ERREUR: API 'term.getSize' non disponible."); error("API 'term.getSize' manquante") end
    local screenWidth, screenHeight = term.getSize()

    if not basalt or type(basalt) ~= "table" then log("ERREUR: 'basalt' n'est pas une table valide ici."); error("'basalt' non valide dans createMainFrame") end
    if not basalt.createFrame then log("ERREUR: basalt.createFrame est nil. Verifiez log initial."); error("basalt.createFrame est nil") end
    local frame = basalt.createFrame()
    if not frame then log("ERREUR: basalt.createFrame() a retourne nil."); error("basalt.createFrame() a echoue") end

    frame:setSize(screenWidth, screenHeight):setBackground(colors.black)
    if frame.setAlwaysOnTop then frame:setAlwaysOnTop(true)
    else log("ATTENTION: Methode 'setAlwaysOnTop' non trouvee sur frame.") end
    mainFrame = frame; log("Fin createMainFrame")
end

local function createNavBar()
    log("Debut createNavBar")
    if not mainFrame then log("ERREUR: mainFrame non initialise."); return end
    local screenWidth, screenHeight = mainFrame:getSize()
    local navBarHeight = 3
    
    if not basalt or type(basalt) ~= "table" then log("ERREUR: 'basalt' non valide dans createNavBar"); error("'basalt' non valide createNavBar") end
    if not basalt.createFrame then log("ERREUR: basalt.createFrame est nil dans createNavBar."); error("basalt.createFrame nil createNavBar") end
    navBarFrame = basalt.createFrame(mainFrame)
    if not navBarFrame then log("ERREUR: basalt.createFrame(mainFrame) a retourne nil."); return end
    navBarFrame:setSize(screenWidth, navBarHeight):setPosition(1, screenHeight - navBarHeight + 1):setBackground(colors.gray)

    local buttonWidth = 12; local numPageButtons = #pageOrder
    local totalButtonSpace = (numPageButtons * buttonWidth) + ((numPageButtons - 1) * 1) 
    local keypadButtonWidth = 10
    local startX = math.floor((screenWidth - (totalButtonSpace + keypadButtonWidth + 2)) / 2) + 1

    if not basalt.createButton then -- Verification cruciale
        log("ERREUR CRITIQUE dans createNavBar: basalt.createButton est nil. Type: " .. type(basalt.createButton) .. ". Verifiez le log initial pour le contenu de 'basalt'.")
        error("basalt.createButton est nil dans createNavBar (type: " .. type(basalt.createButton)..")") -- LIGNE 142 (environ)
    end

    for i, pageName in ipairs(pageOrder) do
        local btn = basalt.createButton(navBarFrame) 
        if not btn then log("ERREUR: basalt.createButton a retourne nil pour page " .. pageName); goto continue_navbar end
        btn:setText(pageTitles[pageName] or pageName):setPosition(startX, 1):setSize(buttonWidth, navBarHeight):onClick(function() showPage(pageName) end)
        startX = startX + buttonWidth + 1
        ::continue_navbar::
    end

    local keypadBtn = basalt.createButton(navBarFrame)
    if not keypadBtn then log("ERREUR: basalt.createButton a retourne nil pour Keypad"); return end
    keypadBtn:setText("Keypad"):setPosition(startX, 1):setSize(keypadButtonWidth, navBarHeight):onClick(function() keypad.toggleVisibility() end)
    log("Fin createNavBar")
end

function keypad.toggleVisibility()
    keypad.isVisible = not keypad.isVisible
    if keypad.frame then
        if not keypad.frame.setVisible then log("ATTENTION: keypad.frame.setVisible manquant"); return end
        keypad.frame:setVisible(keypad.isVisible)
        if keypad.isVisible then
            if keypad.frame.bringToFront then keypad.frame:bringToFront() else log("ATTENTION: keypad.frame.bringToFront manquant") end
            keypad.buffer = ""
            if keypad.display and keypad.display.setText then keypad.display:setText(keypad.buffer) end
        end
    end
    log("Keypad visibility: " .. tostring(keypad.isVisible))
end

function keypad.handleInput(char)
    if char == "ENTR" then log("Keypad Entree: " .. keypad.buffer); keypad.buffer = ""
    elseif char == "CLR" then keypad.buffer = ""
    elseif char == "CLOSE" then keypad.toggleVisibility(); return 
    else if #keypad.buffer < 20 then keypad.buffer = keypad.buffer .. char end
    end
    if keypad.display and keypad.display.setText then keypad.display:setText(keypad.buffer) end
end

local function createKeypad()
    log("Debut createKeypad")
    if not mainFrame then log("ERREUR: mainFrame non initialise."); return end
    if not basalt or not basalt.createFrame then log("ERREUR: basalt.createFrame est nil createKeypad"); error("basalt.createFrame nil createKeypad") end
    local screenW, screenH = mainFrame:getSize()
    local keypadW, keypadH = 22, 14 
    keypad.frame = basalt.createFrame(mainFrame)
    if not keypad.frame then log("ERREUR: basalt.createFrame nil pour keypad.frame"); return end
    keypad.frame:setSize(keypadW, keypadH):setPosition(math.floor((screenW - keypadW) / 2), math.floor((screenH - keypadH - 3) / 2)):setBackground(colors.darkGray):setVisible(keypad.isVisible)

    if not keypad.frame.addLabel then log("ERREUR: keypad.frame.addLabel manquant"); return end
    keypad.display = keypad.frame:addLabel()
    if not keypad.display then log("ERREUR: keypad.frame:addLabel() nil"); return end
    keypad.display:setText(keypad.buffer):setSize(keypadW - 2, 1):setPosition(2, 2):setBackground(colors.black):setForeground(colors.white)

    local btnLayout = {{"1","2","3"},{"4","5","6"},{"7","8","9"},{"CLR","0","ENTR"}}
    local btnW, btnH = 6, 2; local startY = 4
    if not keypad.frame.addButton then log("ERREUR: keypad.frame.addButton manquant"); return end
    for r, row in ipairs(btnLayout) do
        local startX = 2
        for c, caption in ipairs(row) do
            local btn = keypad.frame:addButton()
            if not btn then log("ERREUR: keypad.frame:addButton() nil pour "..caption); goto cont_keypad end
            btn:setText(caption):setPosition(startX, startY):setSize(btnW, btnH):onClick(function() keypad.handleInput(caption) end)
            startX = startX + btnW + 1
            ::cont_keypad::
        end
        startY = startY + btnH + 1
    end
    local closeBtn = keypad.frame:addButton()
    if not closeBtn then log("ERREUR: keypad.frame:addButton() nil pour fermer"); return end
    closeBtn:setText("X"):setSize(3,1):setPosition(keypadW - 3, 1):setBackground(colors.red):setForeground(colors.white):onClick(function() keypad.handleInput("CLOSE") end)
    log("Fin createKeypad")
end

local function populatePage(pageFrame, pageNameForTitle)
    if not pageFrame or not pageFrame.addLabel then log("ERREUR: pageFrame invalide ou addLabel manquant pour " .. pageNameForTitle); return end
    local textContent = "Contenu pour " .. pageNameForTitle
    if pageNameForTitle == "dashboard" then textContent = "Dashboard: Etats des usines et controles ON/OFF ici."
    elseif pageNameForTitle == "autocraft" then textContent = "Autocraft AE2: Liste des patrons, activation/desactivation."
    elseif pageNameForTitle == "turtleMap" then textContent = "Turtle Map: Controle des champs et des turtles agricoles."
    elseif pageNameForTitle == "turtleAnalysis" then textContent = "Analyse Turtles: Liste, minimap, details par turtle."
    elseif pageNameForTitle == "reactor" then textContent = "Controle Reacteur: Script a fournir par l'utilisateur."
    end
    pageFrame:addLabel():setText(textContent):setPosition("center", 5):setSize("parent", 1)
    if pageNameForTitle == "autocraft" then
        if apDevice and apDevice.getPatterns then pageFrame:addLabel():setText("Connecte a AP! (getPatterns existe)").setPosition("center", 7)
        else pageFrame:addLabel():setText("AP non connecte ou 'getPatterns' non dispo.").setPosition("center", 7) end
    end
end

local function createPages()
    log("Debut createPages")
    if not mainFrame then log("ERREUR: mainFrame non initialise."); return end
    if not basalt or not basalt.createFrame then log("ERREUR: basalt.createFrame nil createPages"); error("basalt.createFrame nil createPages") end
    local screenWidth, screenHeight = mainFrame:getSize()
    local navBarH = navBarFrame and navBarFrame.getHeight and navBarFrame:getHeight() or 3 
    local pageHeight = screenHeight - navBarH

    for _, name in ipairs(pageOrder) do
        pages[name] = basalt.createFrame(mainFrame)
        if not pages[name] then log("ERREUR: basalt.createFrame nil pour page " .. name); goto cont_create_pages end
        pages[name]:setSize(screenWidth, pageHeight):setPosition(1, 1):setBackground(colors.lightBlue):setVisible(false)
        if not pages[name].addLabel then log("ERREUR: pages["..name.."].addLabel manquant"); goto cont_create_pages end
        local titleLabel = pages[name]:addLabel()
        if not titleLabel then log("ERREUR: pages["..name.."]:addLabel() nil pour titre"); goto cont_create_pages end
        titleLabel:setText(pageTitles[name] or name):setPosition("center", 1):setBackground(pages[name]:getBackground()):setForeground(colors.black)
        populatePage(pages[name], name)
        ::cont_create_pages::
    end
    log("Fin createPages")
end

local function handleModemMessage(messageTable)
    if type(messageTable) ~= "table" then return end
    log("Modem Recu: type=" .. (messageTable.type or "nil"))
    if messageTable.type == "page_change" and messageTable.page then
        if currentPageName ~= messageTable.page then showPage(messageTable.page, true) end
    elseif messageTable.type == "command" then log("Commande recue: " .. textutils.serialize(messageTable)) end
end

local function mainLoop()
    log("Lancement boucle principale...")
    local function uiEventHandler() 
        if not basalt or not basalt.autoUpdate then log("ERREUR: basalt.autoUpdate manquant!"); while true do os.sleep(1) end end
        basalt.autoUpdate() 
    end
    local function modemEventHandler()
        while true do local _,_,sC,_,msg = os.pullEvent("modem_message"); if sC==MODEM_CHANNEL then handleModemMessage(msg) end end
    end
    if enderModem and parallel_available then log("UI et Modem en parallele."); parallel_api.waitForAny(uiEventHandler, modemEventHandler)
    else log("UI seulement."); uiEventHandler() end
end

local function run()
    term.clear(); term.setCursorPos(1,1); print("Demarrage Controleur Principal v2...")
    createMainFrame(); createNavBar(); createPages(); createKeypad()
    initPeripherals()
    if pages[currentPageName] then showPage(currentPageName)
    else log("ATTENTION: Page initiale '"..currentPageName.."' non creee."); if #pageOrder>0 and pages[pageOrder[1]] then showPage(pageOrder[1]) end end
    mainLoop()
end

local ok, err = pcall(run)
if not ok then
    pcall(function() term.setBackgroundColor(colors.black); term.setTextColor(colors.red); term.clear(); term.setCursorPos(1,1) end)
    print("ERREUR CRITIQUE DANS main.lua:"); print(tostring(err))
    if DEBUG_MODE and type(err)=="string" then print("\nTrace:"); for line in string.gmatch(debug.traceback(err,2),"[^\r\n]+") do print(line) end end
    print("\nScript arrete.")
end
