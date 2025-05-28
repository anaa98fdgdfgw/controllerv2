-- Contrôleur Principal v2 - ComputerCraft

-- Charger les bibliothèques nécessaires
local basalt = require("basalt")
-- term et fs sont globaux, pas besoin de require
local shell = require("shell")
local textutils = require("textutils")

-- [[ Gestion de l'API Parallel ]]
local parallel_api
local parallel_available = false
local status_parallel, res_parallel = pcall(function() parallel_api = require("parallel") end)

if status_parallel and type(parallel_api) == "table" and parallel_api.waitForAny then
    parallel_available = true
    print("[Controller] API Parallel chargee avec succes.")
else
    print("[Controller] ATTENTION: API Parallel non disponible ou n'a pas pu etre chargee.")
    if not status_parallel then print("[Controller] Erreur pcall pour require('parallel'): " .. tostring(res_parallel)) end
    print("[Controller] Le script fonctionnera sans multitache pour le modem et l'UI si le modem est utilise.")
end

-- [[ Configuration ]]
local MODEM_CHANNEL = 65001
local DEBUG_MODE = true

-- [[ Variables Globales ]]
local enderModem
local apDevice

local mainFrame
local navBarFrame
local keypad = {
    frame = nil,
    display = nil,
    buffer = "",
    isVisible = false,
    target = nil
}

local pages = {}
local pageOrder = {"dashboard", "autocraft", "turtleMap", "turtleAnalysis", "reactor"}
local pageTitles = {
    dashboard = "Tableau de Bord",
    autocraft = "Autocraft AE2",
    turtleMap = "Carte & Turtles",
    turtleAnalysis = "Analyse Turtles",
    reactor = "Controle Reacteur"
}
local currentPageName = pageOrder[1]

-- [[ Fonctions Utilitaires ]]
local function log(message)
    if DEBUG_MODE then
        print("[Controller] " .. tostring(message))
    end
end

local function transmitModemMessage(messageTable)
    if enderModem and enderModem.isOpen() and enderModem.transmit then
        local success, err = enderModem.transmit(MODEM_CHANNEL, MODEM_CHANNEL, messageTable)
        if not success then
            log("Erreur transmission modem: " .. tostring(err))
        end
        return success
    end
    return false
end

-- [[ Initialisation des Périphériques ]]
local function initPeripherals()
    log("Initialisation des peripheriques...")
    local modemSide = peripheral.find("ender_modem")
    if modemSide then
        enderModem = modemSide
        enderModem.open(MODEM_CHANNEL)
        log("Modem Ender ouvert sur le canal " .. MODEM_CHANNEL)
    else
        log("ATTENTION: Modem Ender non trouve.")
    end

    local foundAPDevice
    local apTypesToTry = {"me_controller", "ae2_interface", "ae_controller"}
    for _, pType in ipairs(apTypesToTry) do
        foundAPDevice = peripheral.find(pType)
        if foundAPDevice then break end
    end
    
    if not foundAPDevice then
        for _, name in ipairs(peripheral.getNames()) do
            if string.match(peripheral.getType(name) or "", "ae2") or string.match(peripheral.getType(name) or "", "me_controller") then
                foundAPDevice = peripheral.wrap(name)
                log("Peripherique potentiel pour AP trouve par nom/type: " .. name)
                break
            end
        end
    end

    if foundAPDevice then
        apDevice = foundAPDevice
        log("Advanced Peripherals (AE2) connecte. Type: " .. (peripheral.getType(apDevice.getName()) or "inconnu"))
    else
        log("ATTENTION: Aucun peripherique compatible Advanced Peripherals (AE2) trouve.")
    end
end

-- [[ Gestion des Pages et Navigation ]]
local function showPage(pageNameToShow, isRemoteCall)
    isRemoteCall = isRemoteCall or false
    if not pages[pageNameToShow] then
        log("Erreur: Page '" .. pageNameToShow .. "' inconnue.")
        return
    end

    for name, frame in pairs(pages) do
        frame:setVisible(name == pageNameToShow)
    end
    currentPageName = pageNameToShow
    log("Affichage de la page: " .. pageNameToShow)

    if not isRemoteCall then
        transmitModemMessage({type = "page_change", page = pageNameToShow})
    end
end

-- [[ Création des Éléments UI ]]
local function createMainFrame()
    log("Debut createMainFrame")
    if not term or not term.getSize then
        log("ERREUR CRITIQUE: API 'term' ou 'term.getSize' non disponible.")
        error("API 'term' non disponible pour getSize")
    end
    local screenWidth, screenHeight = term.getSize()
    log("Dimensions ecran: " .. screenWidth .. "x" .. screenHeight)

    if not basalt or not basalt.createFrame then
        log("ERREUR CRITIQUE: API 'basalt' ou 'basalt.createFrame' non disponible.")
        error("API 'basalt' non disponible pour createFrame")
    end
    local frame = basalt.createFrame()

    if not frame then
        log("ERREUR CRITIQUE: basalt.createFrame() a retourne nil.")
        error("basalt.createFrame() a echoue")
    end
    log("Frame creee par basalt.createFrame(). Type: " .. type(frame) .. ", Adresse: " .. tostring(frame))

    if not frame.setSize then log("ERREUR: Methode 'setSize' non trouvee sur l'objet frame."); error("Methode 'setSize' manquante") end
    frame:setSize(screenWidth, screenHeight)
    log("Frame apres setSize. Type: " .. type(frame) .. ", Adresse: " .. tostring(frame))

    if not colors or type(colors.black) ~= "number" then
        log("ATTENTION: API 'colors' ou 'colors.black' non disponible ou type incorrect. Type: " .. type(colors.black) .. ". Valeur: " .. tostring(colors.black))
    else
        log("colors.black type: " .. type(colors.black) .. ", value: " .. tostring(colors.black))
    end
    
    if not frame.setBackground then log("ERREUR: Methode 'setBackground' non trouvee sur l'objet frame."); error("Methode 'setBackground' manquante") end
    frame:setBackground(colors.black) 
    log("Frame apres setBackground. Type: " .. type(frame) .. ", Adresse: " .. tostring(frame))

    if not frame then -- Verification cruciale si setBackground pouvait retourner nil
        log("ERREUR CRITIQUE: L'objet frame est devenu nil apres setBackground. Verifiez colors.black et la methode setBackground de Basalt.")
        error("Objet frame est nil avant setAlwaysOnTop")
    end

    if not frame.setAlwaysOnTop then
        log("ERREUR: Methode 'setAlwaysOnTop' non trouvee sur l'objet frame.")
        log("Cela indique un probleme avec l'installation de Basalt ou une version incompatible.")
        error("Methode 'setAlwaysOnTop' manquante sur frame (" .. tostring(frame) .. ")")
    end
    frame:setAlwaysOnTop(true)
    log("Frame apres setAlwaysOnTop. Type: " .. type(frame) .. ", Adresse: " .. tostring(frame))

    mainFrame = frame
    log("Fin createMainFrame, mainFrame assigne.")
end

local function createNavBar()
    log("Debut createNavBar")
    if not mainFrame then log("ERREUR: mainFrame non initialise avant createNavBar"); return end
    local screenWidth, screenHeight = mainFrame:getSize()
    local navBarHeight = 3
    navBarFrame = basalt.createFrame(mainFrame)
        :setSize(screenWidth, navBarHeight)
        :setPosition(1, screenHeight - navBarHeight + 1)
        :setBackground(colors.gray)

    local buttonWidth = 12 
    local numPageButtons = #pageOrder
    local totalButtonSpace = (numPageButtons * buttonWidth) + ((numPageButtons - 1) * 1) 
    local keypadButtonWidth = 10
    local startX = math.floor((screenWidth - (totalButtonSpace + keypadButtonWidth + 2)) / 2) + 1

    for i, pageName in ipairs(pageOrder) do
        basalt.createButton(navBarFrame)
            :setText(pageTitles[pageName] or pageName)
            :setPosition(startX, 1)
            :setSize(buttonWidth, navBarHeight)
            :onClick(function() showPage(pageName) end)
        startX = startX + buttonWidth + 1
    end

    basalt.createButton(navBarFrame)
        :setText("Keypad")
        :setPosition(startX, 1)
        :setSize(keypadButtonWidth, navBarHeight)
        :onClick(function() keypad.toggleVisibility() end)
    log("Fin createNavBar")
end

function keypad.toggleVisibility()
    keypad.isVisible = not keypad.isVisible
    if keypad.frame then
        keypad.frame:setVisible(keypad.isVisible)
        if keypad.isVisible then
            keypad.frame:bringToFront()
            keypad.buffer = ""
            if keypad.display then keypad.display:setText(keypad.buffer) end
        end
    end
    log("Keypad visibility: " .. tostring(keypad.isVisible))
end

function keypad.handleInput(char)
    if char == "ENTR" then
        log("Keypad Entree: " .. keypad.buffer)
        keypad.buffer = ""
    elseif char == "CLR" then
        keypad.buffer = ""
    elseif char == "CLOSE" then
        keypad.toggleVisibility()
        return 
    else
        if #keypad.buffer < 20 then 
            keypad.buffer = keypad.buffer .. char
        end
    end
    if keypad.display then keypad.display:setText(keypad.buffer) end
end

local function createKeypad()
    log("Debut createKeypad")
    if not mainFrame then log("ERREUR: mainFrame non initialise avant createKeypad"); return end
    local screenW, screenH = mainFrame:getSize()
    local keypadW, keypadH = 22, 14 
    keypad.frame = basalt.createFrame(mainFrame)
        :setSize(keypadW, keypadH)
        :setPosition(math.floor((screenW - keypadW) / 2), math.floor((screenH - keypadH - 3) / 2)) 
        :setBackground(colors.darkGray)
        :setVisible(keypad.isVisible)

    keypad.display = keypad.frame:addLabel()
        :setText(keypad.buffer)
        :setSize(keypadW - 2, 1)
        :setPosition(2, 2)
        :setBackground(colors.black)
        :setForeground(colors.white)

    local btnLayout = {{"1", "2", "3"}, {"4", "5", "6"}, {"7", "8", "9"}, {"CLR", "0", "ENTR"}}
    local btnW, btnH = 6, 2
    local startY = 4

    for r, row in ipairs(btnLayout) do
        local startX = 2
        for c, caption in ipairs(row) do
            keypad.frame:addButton()
                :setText(caption)
                :setPosition(startX, startY)
                :setSize(btnW, btnH)
                :onClick(function() keypad.handleInput(caption) end)
            startX = startX + btnW + 1
        end
        startY = startY + btnH + 1
    end
    
    keypad.frame:addButton()
        :setText("X"):setSize(3,1):setPosition(keypadW - 3, 1)
        :setBackground(colors.red):setForeground(colors.white)
        :onClick(function() keypad.handleInput("CLOSE") end)
    log("Fin createKeypad")
end

local function populatePage_Dashboard(pageFrame)
    pageFrame:addLabel():setText("Dashboard: Etats des usines et controles ON/OFF ici."):setPosition("center", 5):setSize("parent", 1)
end

local function populatePage_Autocraft(pageFrame)
    pageFrame:addLabel():setText("Autocraft AE2: Liste des patrons, activation/desactivation."):setPosition("center", 5):setSize("parent", 1)
    if apDevice and apDevice.getPatterns then
        pageFrame:addLabel():setText("Connecte a AP! (getPatterns existe)").setPosition("center", 7)
    else
        pageFrame:addLabel():setText("AP non connecte ou 'getPatterns' non dispo.").setPosition("center", 7)
    end
end

local function populatePage_TurtleMap(pageFrame)
    pageFrame:addLabel():setText("Turtle Map: Controle des champs et des turtles agricoles."):setPosition("center", 5):setSize("parent", 1)
end

local function populatePage_TurtleAnalysis(pageFrame)
    pageFrame:addLabel():setText("Analyse Turtles: Liste, minimap, details par turtle."):setPosition("center", 5):setSize("parent", 1)
end

local function populatePage_Reactor(pageFrame)
    pageFrame:addLabel():setText("Controle Reacteur: Script a fournir par l'utilisateur."):setPosition("center", 5):setSize("parent", 1)
end

local function createPages()
    log("Debut createPages")
    if not mainFrame then log("ERREUR: mainFrame non initialise avant createPages"); return end
    local screenWidth, screenHeight = mainFrame:getSize()
    local navBarHeight = navBarFrame and navBarFrame:getHeight() or 3 -- S'assurer que navBarFrame existe ou utiliser une valeur par defaut
    local pageHeight = screenHeight - navBarHeight

    for _, name in ipairs(pageOrder) do
        pages[name] = basalt.createFrame(mainFrame)
            :setSize(screenWidth, pageHeight):setPosition(1, 1)
            :setBackground(colors.lightBlue):setVisible(false)
        pages[name]:addLabel()
            :setText(pageTitles[name] or name):setPosition("center", 1)
            :setBackground(pages[name]:getBackground()):setForeground(colors.black)

        if name == "dashboard" then populatePage_Dashboard(pages[name])
        elseif name == "autocraft" then populatePage_Autocraft(pages[name])
        elseif name == "turtleMap" then populatePage_TurtleMap(pages[name])
        elseif name == "turtleAnalysis" then populatePage_TurtleAnalysis(pages[name])
        elseif name == "reactor" then populatePage_Reactor(pages[name])
        end
    end
    log("Fin createPages")
end

local function handleModemMessage(messageTable)
    if type(messageTable) ~= "table" then return end
    log("Message Modem Recu: type=" .. (messageTable.type or "nil"))

    if messageTable.type == "page_change" and messageTable.page then
        if currentPageName ~= messageTable.page then
            showPage(messageTable.page, true)
        end
    elseif messageTable.type == "command" then
        log("Commande recue: " .. textutils.serialize(messageTable))
    end
end

local function mainLoop()
    log("Lancement de la boucle principale...")
    local function uiEventHandler() basalt.autoUpdate() end
    local function modemEventHandler()
        while true do
            local event, side, senderChannel, replyChannel, message, distance = os.pullEvent("modem_message")
            if senderChannel == MODEM_CHANNEL then handleModemMessage(message) end
        end
    end

    if enderModem and parallel_available then
        log("Lancement UI et Modem en parallele.")
        parallel_api.waitForAny(uiEventHandler, modemEventHandler)
    else
        log("Lancement UI seulement (pas de parallel_api ou pas de modem).")
        uiEventHandler()
    end
end

local function run()
    term.clear()
    term.setCursorPos(1,1)
    print("Demarrage du Controleur Principal v2...")

    -- L'ordre est important ici
    createMainFrame()
    createNavBar()   -- NavBar depend de mainFrame pour sa position relative en bas
    createPages()    -- Pages dependent de mainFrame et navBarFrame (pour la hauteur)
    createKeypad()   -- Keypad depend de mainFrame
    
    initPeripherals()
    showPage(currentPageName)
    mainLoop()
end

-- Execution securisee
local ok, err = pcall(run)
if not ok then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    term.clear()
    term.setCursorPos(1,1)
    print("ERREUR CRITIQUE DANS main.lua:")
    print(tostring(err))
    if DEBUG_MODE and type(err) == "string" then
        print("\nTrace:")
        for line in string.gmatch(debug.traceback(err, 2), "[^\r\n]+") do print(line) end
    end
    print("\nLe script s'est arrete.")
end