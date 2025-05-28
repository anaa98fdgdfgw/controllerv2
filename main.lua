-- Basalt2 Initialization
local basalt = require("basalt")

-- Create a main frame
local mainFrame = basalt.createFrame()
    :setSize("parent", "parent")
    :setBackground(colors.black)

-- Pages structure
local pages = {
    dashboard = basalt.createFrame(mainFrame):setBackground(colors.red),
    autocraft = basalt.createFrame(mainFrame):setBackground(colors.gray),
    turtleMap = basalt.createFrame(mainFrame):setBackground(colors.green),
    turtleAnalysis = basalt.createFrame(mainFrame):setBackground(colors.blue),
    bigReactor = basalt.createFrame(mainFrame):setBackground(colors.purple),
}

-- Navigation Bar
local navBar = basalt.createFrame(mainFrame)
    :setSize("parent", 3)
    :setPosition(1, "parent" - 3)
    :setBackground(colors.red)

-- Add navigation buttons
local buttons = {
    basalt.createButton(navBar):setText("Dashboard"):setPosition(2, 1):setSize(10, 3),
    basalt.createButton(navBar):setText("Autocraft"):setPosition(14, 1):setSize(10, 3),
    basalt.createButton(navBar):setText("Turtle Map"):setPosition(26, 1):setSize(10, 3),
    basalt.createButton(navBar):setText("Analysis"):setPosition(38, 1):setSize(10, 3),
    basalt.createButton(navBar):setText("Reactor"):setPosition(50, 1):setSize(10, 3),
}

-- Event handler for buttons
for name, button in pairs(buttons) do
    button:onClick(function()
        for pageName, pageFrame in pairs(pages) do
            pageFrame:setVisible(pageName == name)
        end
    end)
end

-- Sync between PC central and Pocket
local modem = peripheral.find("ender_modem")
if modem then
    modem.open(1) -- Channel for communication
end

-- Example Sync Function
local function syncPocketPC()
    while true do
        local event, id, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        print("Received message: "..message)
        -- Process sync logic here
    end
end
parallel.waitForAll(syncPocketPC, function() basalt.autoUpdate() end)