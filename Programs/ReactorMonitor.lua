--[[
    Reactor Monitor Program
    Monitor all info about the attached reactor
    Broadcast when requested on stateRequestChannel
]]

--Load APIs
os.loadAPI("constants")
os.loadAPI("utils")
os.loadAPI("graphics")

--Program Vars
local debug = constants.DEBUG
local runMain = true
local cycleCounter = 0
local rodInsertion = {}
local cLabel = nil

--Peripherals
local reactor = nil
local modem = nil

--[[
    Initialize PC setup
    Label pc, get peripherals

    @return {boolean} - Return true if initialization ran succesfully
]]
local function init()
    utils.debugPrint(debug, "Running initialization")
    utils.debugPrint(debug, "    Setting state request channel")
    cLabel = "Reactor - Ch " .. tostring(constants.REACTOR_CHANNEL)
    os.setComputerLabel(cLabel)
    utils.debugPrint(debug, "    Getting reactor Wrapper")
    reactor = utils.getPeripheralHandle(constants.BR_REACTOR_HANDLE)
    utils.debugPrint(debug, "    Opening modem channels for listening")
    modem = utils.getAndOpenModems(constants.REACTOR_CHANNEL)
    return true
end

--[[
    Main function
    Handles incoming events
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
                --If message is state request
                and p2 == constants.REACTOR_CHANNEL
                and tostring(p4) == constants.REACTOR_REQUEST_MESSAGE
            then
                utils.debugPrint(debug, "    State Request received, creating state message")
                controlRodCount = reactor.getNumberOfControlRods()
                for i=0,controlRodCount-1 do 
                    rodInsertion[i] = reactor.getControlRodLevel(i)
                end
                --State Structure
                local tState = {
                    label = cLabel,
                    active = reactor.getActive(),
                    controlRodCount = reactor.getNumberOfControlRods(),
                    controlRodInsertion = rodInsertion, 
                    fuelTemperature = reactor.getFuelTemperature(),
                    casingTemperature = reactor.getCasingTemperature(),
                    fuelAmount = reactor.getFuelAmount(),
                    wasteAmount = reactor.getWasteAmount(),
                    hotFluidProducedLastTick = reactor.getHotFluidProducedLastTick(),
                    coolantType = reactor.getCoolantType(),
                    coolantAmount = reactor.getCoolantAmount(),
                    coolantAmountMax = reactor.getCoolantAmountMax(),
                    hotFluidType = reactor.getHotFluidType(),
                    hotFluidAmount = reactor.getHotFluidAmount(),
                    hotFluidAmountMax = reactor.getHotFluidAmountMax(),
                    fuelReactivity = reactor.getFuelReactivity(),
                    fuelConsumedLastTick = reactor.getFuelConsumedLastTick(),
                }
                --Send state message to Reply Channel
                peripheral.call(p1, "transmit", p3, p2, textutils.serialize(tState))
                utils.debugPrint(debug, "    State send succesful")
            --If event is new peripheral and peripheral is modem
            --Add new modem peripheral
            elseif evt == "peripheral"  
                and peripheral.getType(p1) == "modem"
                and stateRequestChannel >= 0
            then
                utils.debugPrint(debug, "New modem added, opening channels")
                modem = utils.getAndOpenModems(constants.REACTOR_CHANNEL)
            else 
                utils.debugPrint(debug, "Unknown event, continuing with new cycle")
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