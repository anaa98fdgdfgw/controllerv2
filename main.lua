-- Contrôleur Principal v2 - ComputerCraft

-- Charger les bibliothèques nécessaires
local basalt = require("basalt") -- Basalt2 s'enregistre generalement comme "basalt"
local term = require("term")
local fs = require("fs")
local parallel = require("parallel")
local shell =require("shell")
local textutils = require("textutils") -- Pour serialiser/deserialiser les messages modem

-- [[ Configuration ]]
local MODEM_CHANNEL = 65001 -- Canal de communication modem (assurez-vous qu'il est unique)
local DEBUG_MODE = true    -- Activer pour des messages de débogage dans la console

-- [[ Variables Globales ]]
-- Peripheriques
local enderModem
local apDevice -- Pour Advanced Peripherals (ex: AE2 Controller)
-- (BigReactor sera géré plus tard)

-- UI Elements
local mainFrame
local navBarFrame
local keypad = {
    frame = nil,
    display = nil,
    buffer = "",
    isVisible = false,
    target = nil -- Element cible pour l'entree du keypad (futur usage)
}

local pages = {} -- Table pour stocker les frames de chaque page
local pageOrder = {"dashboard", "autocraft", "turtleMap", "turtleAnalysis", "reactor"}
local pageTitles = {
    dashboard = "Tableau de Bord",
    autocraft = "Autocraft AE2",
    turtleMap = "Carte & Turtles",
    turtleAnalysis = "Analyse Turtles",
    reactor = "Controle Reacteur"
}
local currentPageName = pageOrder[1] -- Page initiale

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
    -- Ender Modem
    local modemSide = peripheral.find("ender_modem")
    if modemSide then
        enderModem = modemSide
        enderModem.open(MODEM_CHANNEL)
        log("Modem Ender ouvert sur le canal " .. MODEM_CHANNEL)
    else
        log("ATTENTION: Modem Ender non trouve.")
    end

    -- Advanced Peripherals (pour AE2)
    -- Tente de trouver un controlleur ME ou une interface AE2
    -- Les noms peuvent varier; "me_controller", "interface", ou specifique a AP.
    local foundAPDevice
    local apTypesToTry = {"me_controller", "ae2_interface", "ae_controller"} -- Ajoutez d'autres types si necessaire

    for _, pType in ipairs(apTypesToTry) do
        foundAPDevice = peripheral.find(pType)
        if foundAPDevice then break end
    end
    
    -- Si non trouvé par type, chercher par nom contenant "ae2" ou "me"
    if not foundAPDevice then
        for _, name in ipairs(peripheral.getNames()) do
            if string.match(peripheral.getType(name) or "", "ae2") or string.match(peripheral.getType(name) or "", "me_controller") then
                foundAPDevice = peripheral.wrap(name)
                log("Peripherique potentiel pour AP trouve par type: " .. name)
                break
            end
        end
    end

    if foundAPDevice then
        apDevice = foundAPDevice
        log("Advanced Peripherals (AE2) connecte. Type: " .. (peripheral.getType(apDevice.getName()) or "inconnu"))
        -- Exemple de verification:
        -- if apDevice.getPatterns then log("Fonction getPatterns() disponible sur apDevice.") end
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

    if not isRemoteCall then -- Si ce n'est pas un appel distant, notifier l'autre appareil
        transmitModemMessage({type = "page_change", page = pageNameToShow})
    end
end

-- [[ Création des Éléments UI ]]
local function createMainFrame()
    local screenWidth, screenHeight = term.getSize()
    mainFrame = basalt.createFrame()
        :setSize(screenWidth, screenHeight)
        :setBackground(colors.black)
        :setAlwaysOnTop(true)
end

local function createNavBar()
    local screenWidth, screenHeight = mainFrame:getSize()
    local navBarHeight = 3
    navBarFrame = basalt.createFrame(mainFrame)
        :setSize(screenWidth, navBarHeight)
        :setPosition(1, screenHeight - navBarHeight + 1)
        :setBackground(colors.gray)

    local buttonWidth = 12 -- Largeur approximative par bouton
    local numPageButtons = #pageOrder
    local totalButtonSpace = (numPageButtons * buttonWidth) + ((numPageButtons - 1) * 1) -- Avec espacement
    
    local keypadButtonWidth = 10
    local startX = math.floor((screenWidth - (totalButtonSpace + keypadButtonWidth + 2)) / 2) + 1


    for i, pageName in ipairs(pageOrder) do
        local btn = basalt.createButton(navBarFrame)
            :setText(pageTitles[pageName] or pageName)
            :setPosition(startX, 1)
            :setSize(buttonWidth, navBarHeight)
            :onClick(function() showPage(pageName) end)
        startX = startX + buttonWidth + 1
    end

    -- Bouton Keypad
    basalt.createButton(navBarFrame)
        :setText("Keypad")
        :setPosition(startX, 1)
        :setSize(keypadButtonWidth, navBarHeight)
        :onClick(function() keypad.toggleVisibility() end)
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
        -- Action a definir (ex: appeler une fonction avec keypad.buffer)
        keypad.buffer = ""
    elseif char == "CLR" then
        keypad.buffer = ""
    elseif char == "CLOSE" then
        keypad.toggleVisibility()
        return -- Ne pas ajouter "CLOSE" au buffer
    else
        if #keypad.buffer < 20 then -- Limite la longueur
            keypad.buffer = keypad.buffer .. char
        end
    end
    if keypad.display then keypad.display:setText(keypad.buffer) end
end

local function createKeypad()
    local screenW, screenH = mainFrame:getSize()
    local keypadW, keypadH = 22, 14 -- Dimensions du keypad
    keypad.frame = basalt.createFrame(mainFrame)
        :setSize(keypadW, keypadH)
        :setPosition(math.floor((screenW - keypadW) / 2), math.floor((screenH - keypadH - 3) / 2)) -- Centré au-dessus de la nav bar
        :setBackground(colors.darkGray)
        :setVisible(keypad.isVisible)

    keypad.display = keypad.frame:addLabel()
        :setText(keypad.buffer)
        :setSize(keypadW - 2, 1)
        :setPosition(2, 2)
        :setBackground(colors.black)
        :setForeground(colors.white)

    local btnLayout = {
        {"1", "2", "3"},
        {"4", "5", "6"},
        {"7", "8", "9"},
        {"CLR", "0", "ENTR"}
    }
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
    
    keypad.frame:addButton() -- Bouton Fermer
        :setText("X")
        :setSize(3,1)
        :setPosition(keypadW - 3, 1)
        :setBackground(colors.red)
        :setForeground(colors.white)
        :onClick(function() keypad.handleInput("CLOSE") end)
end

-- Fonctions pour peupler le contenu de chaque page (A IMPLEMENTER)
local function populatePage_Dashboard(pageFrame)
    pageFrame:addLabel():setText("Dashboard: Etats des usines et controles ON/OFF ici."):setPosition("center", 5):setSize("parent", 1)
end

local function populatePage_Autocraft(pageFrame)
    pageFrame:addLabel():setText("Autocraft AE2: Liste des patrons, activation/desactivation."):setPosition("center", 5):setSize("parent", 1)
    if apDevice and apDevice.getPatterns then
        -- Exemple: local patterns = apDevice.getPatterns() ... puis afficher
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
    local screenWidth, screenHeight = mainFrame:getSize()
    local navBarHeight = 3
    local pageHeight = screenHeight - navBarHeight

    for _, name in ipairs(pageOrder) do
        pages[name] = basalt.createFrame(mainFrame)
            :setSize(screenWidth, pageHeight)
            :setPosition(1, 1)
            :setBackground(colors.lightBlue) -- Fond par defaut des pages
            :setVisible(false)

        -- Titre de la page
        pages[name]:addLabel()
            :setText(pageTitles[name] or name)
            :setPosition("center", 1)
            :setBackground(pages[name]:getBackground()) -- Transparent par rapport au fond de page
            :setForeground(colors.black)

        -- Peupler la page specifique
        if name == "dashboard" then populatePage_Dashboard(pages[name])
        elseif name == "autocraft" then populatePage_Autocraft(pages[name])
        elseif name == "turtleMap" then populatePage_TurtleMap(pages[name])
        elseif name == "turtleAnalysis" then populatePage_TurtleAnalysis(pages[name])
        elseif name == "reactor" then populatePage_Reactor(pages[name])
        end
    end
end

-- [[ Gestion des Messages Modem ]]
local function handleModemMessage(messageTable)
    if type(messageTable) ~= "table" then return end
    log("Message Modem Recu: type=" .. (messageTable.type or "nil"))

    if messageTable.type == "page_change" and messageTable.page then
        if currentPageName ~= messageTable.page then -- Eviter boucle si deja sur la page
            showPage(messageTable.page, true) -- true pour indiquer un appel distant
        end
    elseif messageTable.type == "command" then
        -- Traiter d'autres commandes (ex: etat d'une usine change, etc.)
        log("Commande recue: " .. textutils.serialize(messageTable))
    end
end

-- [[ Boucle Principale et Gestion des Événements ]]
local function mainLoop()
    log("Lancement de la boucle principale...")

    local function uiEventHandler()
        basalt.autoUpdate() -- Bloquant; gere les evenements UI et redessine
    end

    local function modemEventHandler()
        while true do
            local event, side, senderChannel, replyChannel, message, distance = os.pullEvent("modem_message")
            if senderChannel == MODEM_CHANNEL then -- Filtrer par canal
                handleModemMessage(message)
            end
        end
    end

    if enderModem then
        parallel.waitForAny(uiEventHandler, modemEventHandler)
    else
        uiEventHandler() -- Si pas de modem, seulement la UI
    end
end

-- [[ Démarrage du Script ]]
local function run()
    term.clear()
    term.setCursorPos(1,1)
    print("Demarrage du Controleur Principal v2...")

    createMainFrame()
    createPages()    -- Creer les frames des pages
    createNavBar()   -- Creer la barre de navigation
    createKeypad()   -- Creer le keypad (initialement cache)

    initPeripherals() -- Initialiser modem, AP, etc.

    showPage(currentPageName) -- Afficher la page initiale

    mainLoop() -- Lancer la boucle d'evenements
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
    if DEBUG_MODE and type(err) == "string" then -- Afficher la trace si disponible
        print("\nTrace:")
        for line in string.gmatch(debug.traceback(err, 2), "[^\r\n]+") do
            print(line)
        end
    end
    print("\nLe script s'est arrete.")
end
