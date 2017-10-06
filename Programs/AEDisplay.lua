--[[
    AE System Data Gatherer and Display

    Collects data from the AE Monitor PC
    Displays on monitor
]]

--Load APIs
os.loadAPI("constants")
os.loadAPI("utils")
os.loadAPI("graphics")

--Peripherals
local mon = nil
local mod = nil

--Program Vars
local debug = constants.DEBUG
local runMain = true
local cLabel = nil
local cycleCounter = 0

local aeItemList = nil
local aeCraftingList = nil
local aePowerUsage = nil

local aeCPUList = {}

local colorsList = {colors.orange, 
                    colors.lightBlue, 
                    colors.purple, 
                    colors.lime, 
                    colors.pink, 
                    colors.cyan, 
                    colors.magenta, 
                    colors.blue,  
                    colors.red,
                    colors.lightGray,
                    colors.green,
                    colors.yellow,
                    colors.brown}

--Monitor vars
local terminalScreen = nil
local generalDisplayWindow = nil
local craftingWindow = nil
local itemWindow = nil

--[[
    Render the Crafting CPUs 
]]
local function renderCrafting()
    term.redirect(craftingWindow)
    local currentWindowWidth, currentWindowHeight = term.getSize()
    local iterator = 0
    graphics.writeText(2, 4, " CPU# |  Data   | Value  ")
    graphics.writeText(2, 5, "-------------------------")
    for k, cpu in pairs(aeCraftingList) do
        graphics.writeText(2, k+5+iterator, "  #" .. k .. "  ", colorsList[k])
        graphics.writeText(8, k+5+iterator, "| Status: |")
        graphics.writeText(2, k+6+iterator, "        ", colorsList[k])
        graphics.writeText(8, k+6+iterator, "| Size:   |")
        if cpu["busy"] == true then
            graphics.writeTextAllignRight(currentWindowWidth, k+5+iterator, "  Busy  ", colors.red)
        else
            graphics.writeTextAllignRight(currentWindowWidth, k+5+iterator, "  Free  ", colors.green)
        end
        graphics.writeTextAllignRight(currentWindowWidth, k+6+iterator, "        ", colors.yellow, colors.black)
        graphics.writeTextAllignRight(currentWindowWidth-1, k+6+iterator, cpu["storage"], colors.yellow, colors.black)
        graphics.writeText(2, k+7+iterator, "-------------------------")
        iterator = iterator + 2
    end

    term.redirect(mon)
end

--[[
    Render the items list
    Sort items based on Qty
    TODO: Some items don't appear in the list
]]
local function renderItems()
    term.redirect(itemWindow)
    local currentWindowWidth, currentWindowHeight = term.getSize()
    graphics.writeText(2, 4, " Name            | Count ")
    graphics.writeText(2, 5, "-------------------------")
    local itemList = {}
    for k, item in pairs(aeItemList) do
        if item.item.qty > 1000 then
            local itemName = item.item.display_name
            local itemQuantity = item.item.qty
            itemList[itemName] = itemQuantity
        end
    end
    local i = 6
    for itemName, itemQuantity in utils.sortTable(itemList, function(t,a,b) return t[b] < t[a] end) do
        --Write sorted results to screen
        graphics.writeText(2, i, string.sub(itemName, 1, 17), colors.black, colorsList[(i-5)%14])
        graphics.writeText(19, i, "|")
        graphics.writeTextAllignRight(currentWindowWidth, i, itemQuantity)
        --If the max amount of lines (13)is reached break the loop
        i = i + 1
        if i == currentWindowHeight-1 then break end
    end
    graphics.writeText(2, currentWindowHeight-1, "-------------------------")
    term.redirect(mon)
end

local function renderGeneralDisplay()

end

--[[
    Wait for a new response from a request
    Process received request

    @param {int} expectedReplyChannel - Expected reply channel from a received modem message to ensure the right data is received
]]
local function getNewEvent(expectedReplyChannel)
    utils.debugPrint(debug, "Waiting on new event...")
    local timeout = os.startTimer(2)
    local evt, p1, p2, p3, p4, p5 = os.pullEvent()
    os.cancelTimer(timeout)   
    if evt == "modem_message" then
        utils.debugPrint(debug, "    New Modem Event Received")
        --If we get an interrupt command from the Command Channel handle that instead
        if p3 == constants.AE_MONITOR_CRAFTING_REPLY 
            and p3 == expectedReplyChannel 
        then
            utils.debugPrint(debug, "        Received Crafting Response")
            aeCraftingList = textutils.unserialize(p4)
            return true
        elseif p3 == constants.AE_MONITOR_ITEM_REPLY
            and p3 == expectedReplyChannel
        then
            utils.debugPrint(debug, "        Received Item Response")
            aeItemList = textutils.unserialize(p4)
            return true
        elseif p3 == constants.AE_MONITOR_POWER_REPLY
            and p3 == expectedReplyChannel
        then
            utils.debugPrint(debug, "        Received Power Response")
            aePowerUsage = p4
            return true
        end
    elseif evt == "timer" 
        and p1 == timeout
    then
        utils.debugPrint(debug, "    Event wait time ran out, continuing program")
        return false
    else 
        utils.debugPrint(debug, "    Unknown request received, continuing program")
        return false
    end

end

--[[
    Setup Windows
]]
local function setupWindows()
    utils.debugPrint(debug, "        Creating General Display Window")
    generalDisplayWindow = graphics.setupWindow("General Display", 2, 0, colors.purple)
    utils.debugPrint(debug, "        Creating Item Window")
    itemWindow = graphics.setupWindow("Items", 2, 1, colors.cyan)
    utils.debugPrint(debug, "        Creating Crafting Window")
    craftingWindow = graphics.setupWindow("Crafting", 2, 2, colors.green)
end

--[[
    Initialize PC setup
    Label pc, get peripherals
    Set up Monitor and get the monitor vars
    Set up Windows
]]
local function init()
    utils.debugPrint(debug, "Running initialization")
    utils.debugPrint(debug, "    Computer Label")
    cLabel ="AE Display - Ch " .. constants.AE_DISPLAY_CHANNEL
    os.setComputerLabel(cLabel)
    utils.debugPrint(debug, "    Getting Monitor Wrapper")    
    mon = utils.getPeripheralHandle("monitor")
    terminalScreen = term.redirect(mon) --Original PC terminal saved as var
    utils.debugPrint(debug, "    Getting Modem Wrapper")
    mod = utils.getAndOpenModems(constants.AE_DISPLAY_CHANNEL)
    utils.debugPrint(debug, "    Resetting Screen")
    graphics.resetScreen()
    utils.debugPrint(debug, "    Setting up windows")
    setupWindows()
    return true
end

--[[
    Main function
    Gets data from the AE interface monitors and sets them to display
]]
local function main()
    graphics.clearTerm()
    if init() then 
        utils.debugPrint(debug, "Initialization succesful")
    else
        utils.error("Failed to initialize program succesfully")
    end
    sleep(2)
    while true do
        if runMain then 
            --Start new set of debug data on monitor
            graphics.clearTerm()
            utils.debugPrint(debug, "Starting cycle: " .. tostring(cycleCounter))
            utils.debugPrint(debug, "------------------------------------")
            cycleCounter = cycleCounter + 1
            --Start Data gather from AE Interface
            utils.debugPrint(debug, "Sending Crafting Request")
            mod.transmit(constants.AE_MONITOR_CHANNEL, constants.AE_DISPLAY_CHANNEL, constants.AE_CRAFTING_REQUEST_MESSAGE)
            if getNewEvent(constants.AE_MONITOR_CRAFTING_REPLY) == false then
                utils.debugPrint(debug, "    Failed to get Crafting data")
            else
                utils.debugPrint(debug, "    Updating Crafting Window")
                renderCrafting()
            end
            os.sleep(0.2)
            utils.debugPrint(debug, "Sending Item Request")
            mod.transmit(constants.AE_MONITOR_CHANNEL, constants.AE_DISPLAY_CHANNEL, constants.AE_ITEMS_REQUEST_MESSAGE)
            if getNewEvent(constants.AE_MONITOR_ITEM_REPLY) == false then
                utils.debugPrint(debug, "    Failed to get Item data")
            else
                utils.debugPrint(debug, "    Updating Item Window")
                renderItems()
            end
            os.sleep(0.2)
            utils.debugPrint(debug, "Sending Power Request")
            mod.transmit(constants.AE_MONITOR_CHANNEL, constants.AE_DISPLAY_CHANNEL, constants.AE_POWER_REQUEST_MESSAGE)
            if getNewEvent(constants.AE_MONITOR_POWER_REPLY) == false then
                utils.debugPrint(debug, "    Failed to get Power data")
            else
                utils.debugPrint(debug, "    Updating Power Window")
                renderGeneralDisplay()
            end
        else
            os.sleep(10)
        end        
    end
end

--[[
    Computer control function. Listens for signals on the Control channel
    Manages direct commands to the pc like rebooting the system
]]
local function computerControl()
    sleep(2)
    while true do
        local evt, p1, p2, p3, p4, p5 = os.pullEvent()
        if evt == "modem_message"
            and p2 == constants.CC_COMMAND_CHANNEL
            and p3 == constants.CC_CONTROL_CHANNEL
            and tostring(p4) == constants.REBOOT_REQUEST_MESSAGE
        then
            utils.debugPrint(debug, "Received Reboot Request")
            utils.debugPrint(debug, "Rebooting")
            peripheral.call(p1, "transmit", p3, p2, true)
            os.reboot()
        elseif evt =="modem_message"
            and p2 == constants.CC_COMMAND_CHANNEL
            and p3 == constants.CC_CONTROL_CHANNEL
            and tostring(p4) == constants.SHUT_DOWN_REQUEST_MESSAGE
        then
            utils.debugPrint(debug, "Received Shut Down Request")
            utils.debugPrint(debug, "Quiting main event loop")
            peripheral.call(p1, "transmit", p3, p2, true)
            runMain = false
        elseif evt =="modem_message"
            and p2 == constants.CC_COMMAND_CHANNEL
            and p3 == constants.CC_CONTROL_CHANNEL
            and tostring(p4) == constants.START_UP_REQUEST_MESSAGE
        then
            utils.debugPrint(debug, "Received Start Up Request")
            utils.debugPrint(debug, "Starting main event loop")
            peripheral.call(p1, "transmit", p3, p2, true)
            runMain = true
        end
    end
end

sleep(2) --Sleep for 2 seconds to deal with server lag
parallel.waitForAll(main, computerControl)