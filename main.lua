-- Basalt2 Initialization
local basalt = require("basalt")

-- Create a main frame
local mainFrame = basalt.createFrame()
    :setSize("parent", "parent")
    :setBackground(colors.black)

-- Pages structure
local pages = {
    dashboard = basalt.createFrame(mainFrame):setBackground(colors.red):setVisible(true),
    autocraft = basalt.createFrame(mainFrame):setBackground(colors.gray):setVisible(false),
    turtleMap = basalt.createFrame(mainFrame):setBackground(colors.green):setVisible(false),
    turtleAnalysis = basalt.createFrame(mainFrame):setBackground(colors.blue):setVisible(false),
    bigReactor = basalt.createFrame(mainFrame):setBackground(colors.purple):setVisible(false),
}

-- Navigation Bar
local navBar = basalt.createFrame(mainFrame)
    :setSize("parent", 3)
    :setPosition(1, "parent" - 3)
    :setBackground(colors.red)

-- Add buttons to the navigation bar
local buttons = {
    dashboard = basalt.createButton(navBar):setText("Dashboard"):setPosition(2, 1):setSize(10, 3),
    autocraft = basalt.createButton(navBar):setText("Autocraft"):setPosition(14, 1):setSize(10, 3),
    turtleMap = basalt.createButton(navBar):setText("Turtle Map"):setPosition(26, 1):setSize(10, 3),
    turtleAnalysis = basalt.createButton(navBar):setText("Analysis"):setPosition(38, 1):setSize(10, 3),
    bigReactor = basalt.createButton(navBar):setText("Reactor"):setPosition(50, 1):setSize(10, 3),
}

-- Event handlers for navigation buttons
for pageName, button in pairs(buttons) do
    button:onClick(function()
        for name, frame in pairs(pages) do
            frame:setVisible(name == pageName)
        end
    end)
end

-- Sync between PC central and Pocket using Ender Modem
local modem = peripheral.find("ender_modem")
if modem then
    modem.open(1) -- Channel for communication
else
    error("Ender modem not found! Please install and configure it.")
end

-- Example Sync Function
local function syncPocketPC()
    while true do
        local event, id, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        print("Received message: "..message)
        if message == "syncCommand" then
            -- Example placeholder for syncing logic
            print("Syncing command from PC central...")
        end
    end
end

-- Basic page content placeholders
pages.dashboard:addLabel():setText("Dashboard Page"):setPosition("center", "center"):setForeground(colors.white)
pages.autocraft:addLabel():setText("Autocraft Page"):setPosition("center", "center"):setForeground(colors.white)
pages.turtleMap:addLabel():setText("Turtle Map Page"):setPosition("center", "center"):setForeground(colors.white)
pages.turtleAnalysis:addLabel():setText("Turtle Analysis Page"):setPosition("center", "center"):setForeground(colors.white)
pages.bigReactor:addLabel():setText("Big Reactor Page"):setPosition("center", "center"):setForeground(colors.white)

-- Run the UI and Sync concurrently
parallel.waitForAll(syncPocketPC, function() basalt.autoUpdate() end)
