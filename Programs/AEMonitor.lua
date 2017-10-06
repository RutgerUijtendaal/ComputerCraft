--[[
    AE System monitor program
    Gets item lists and AE system info from attached AE Interface
    Broadcasts requested info to reply channel of request
]]

--Load APIs
os.loadAPI("constants")
os.loadAPI("utils")
os.loadAPI("graphics")

--Program Vars
local debug = constants.DEBUG
local runMain = true
local cycleCounter = 0
local cLabel = 0

--Peripherals
local aeInterface = nil
local modem = nil

--[[
    Initialize PC setup
    Label pc, get peripherals

    @return {boolean} - Return true if initialization ran succesfully
]]
local function init()
    utils.debugPrint(debug, "Running initialization")
    utils.debugPrint(debug, "    Setting Interface request channel")
    cLabel = "AE Monitor - Ch " .. tostring(constants.AE_MONITOR_CHANNEL)
    os.setComputerLabel(cLabel)
    utils.debugPrint(debug, "    Getting Interface Wrapper")
    aeInterface = utils.getPeripheralHandle(constants.AE_INTERFACE_HANDLE)
    utils.debugPrint(debug, "    Opening modem channels for listening")
    modem = utils.getAndOpenModems(constants.AE_MONITOR_CHANNEL)
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
    while true do
        if runMain then
            --Start new set of debug data on monitor
            utils.debugPrint(debug, "")
            utils.debugPrint(debug, "Starting cycle: " .. tostring(cycleCounter))
            utils.debugPrint(debug, "------------------------------------")
            cycleCounter = cycleCounter + 1
            -- Wait for new event
            utils.debugPrint(debug, "Waiting on new event...")
            local evt, p1, p2, p3, p4, p5 = os.pullEvent()
            -- If new event is modem_message
            -- http://computercraft.info/wiki/Modem_message_(event)
            if evt == "modem_message"
                --If message is crafting request
                and p2 == constants.AE_MONITOR_CHANNEL
                and tostring(p4) == constants.AE_CRAFTING_REQUEST_MESSAGE
            then
                utils.debugPrint(debug, "    Crafting Request received, creating message")
                peripheral.call(p1, "transmit", p3, constants.AE_MONITOR_CRAFTING_REPLY, textutils.serialize(aeInterface.getCraftingCPUs()))
                utils.debugPrint(debug, "    Message send succesful")
            elseif evt == "modem_message"
                --If message is item request
                and p2 == constants.AE_MONITOR_CHANNEL
                and tostring(p4) == constants.AE_ITEMS_REQUEST_MESSAGE
            then
                utils.debugPrint(debug, "    Item List Request received, creating message")
                peripheral.call(p1, "transmit", p3, constants.AE_MONITOR_ITEM_REPLY, textutils.serialize(aeInterface.getAvailableItems("ALL")))
                utils.debugPrint(debug, "    Message send succesful")
            elseif evt == "modem_message"
                --If message is power request
                and p2 == constants.AE_MONITOR_CHANNEL
                and tostring(p4) == constants.AE_POWER_REQUEST_MESSAGE
            then
                utils.debugPrint(debug, "    Power Request received, creating message")
                peripheral.call(p1, "transmit", p3, constants.AE_MONITOR_POWER_REPLY, aeInterface.getIdlePowerUsage())
                utils.debugPrint(debug, "    Message send succesful")
            --If event is new peripheral and peripheral is modem add new modem
            elseif evt == "peripheral"  
                and peripheral.getType(p1) == "modem"
            then
                utils.debugPrint(debug, "    New modem added, opening channels")
                modem = utils.getAndOpenModems(constants.AE_MONITOR_CHANNEL)
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