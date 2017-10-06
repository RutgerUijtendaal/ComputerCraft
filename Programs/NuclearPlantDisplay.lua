--[[
    Nuclear Power Plant Data Gatherer and Display

    Collects data from turbines and reactors
    Displays on monitor
]]

--Load APIs
os.loadAPI("constants")
os.loadAPI("utils")
os.loadAPI("graphics")

--Channel vars
local replyChannel = constants.NUCLEAR_DISPLAY_CHANNEL
local reactorChannel  = constants.REACTOR_CHANNEL
local turbine1Channel = constants.TURBINE_CHANNEL_BASE
local turbine2Channel = constants.TURBINE_CHANNEL_BASE + 1
local turbine3Channel = constants.TURBINE_CHANNEL_BASE + 2

--Turbine Data
local nuclearState = {}

--Peripherals
local mon = nil
local mod = nil

--Program Vars
local debug = constants.DEBUG
local runMain = true
local cLabel = nil
local cycleCounter = 0

--Monitor Vars
local terminalScreen = nil
local generalDisplayWindow = nil
local reactorWindow = nil
local turbine1Window = nil
local turbine2Window = nil
local turbine3Window = nil

--[[
    Display Turbine Data

    @param {int} tChannel - Channel number of the turbine to display data from
    @param {object} tWindow - CC Window object of the turbine 
]]
local function renderTurbine(tChannel, tWindow)
    --Get Turbine Data Strings
    local active = {}
    if nuclearState[tChannel]["active"] then
        active = { "  Running  ", colors.green}
    else
        active = {"  Offline  ", colors.red}
    end
    local rotorspeed = {}
    if math.floor(nuclearState[tChannel]["rotorSpeed"]) > 1750
        and math.floor(nuclearState[tChannel]["rotorSpeed"]) < 1850
    then
        rotorspeed = {tostring(math.floor(nuclearState[tChannel]["rotorSpeed"])) .. " RPM", colors.green}
    else
        rotorspeed = {tostring(math.floor(nuclearState[tChannel]["rotorSpeed"])) .. " RPM", colors.red}    
    end
    local energy = {}
    if math.floor(nuclearState[tChannel]["energyProducedLastTick"]) > 15000 then
        energy = {tostring(math.floor(nuclearState[tChannel]["energyProducedLastTick"])) .. " RF/Tick", colors.green}
    else
        energy = {tostring(math.floor(nuclearState[tChannel]["energyProducedLastTick"])) .. " RF/Tick", colors.red}
    end
    local flowrate = {}
    if  nuclearState[tChannel]["fluidFlowRate"] > nuclearState[tChannel]["fluidFlowRateMax"]-15
        or nuclearState[tChannel]["fluidFlowRate"] < nuclearState[tChannel]["fluidFlowRateMax"]+15
    then 
        flowrate = {nuclearState[tChannel]["fluidFlowRate"] .. "/" .. nuclearState[tChannel]["fluidFlowRateMax"] .. " mB/Tick", colors.green}
    else
        flowrate = {nuclearState[tChannel]["fluidFlowRate"] .. "/" .. nuclearState[tChannel]["fluidFlowRateMax"] .. " mB/Tick", colors.red}
    end
    --Get Turbine window
    term.redirect(tWindow)
    local currentWindowWidth, currentWindowHeight = term.getSize()
    --Draw data
    graphics.writeText(2, 5, "Turbine Status:")
    graphics.writeTextAllignRight(currentWindowWidth, 6, active[1], active[2])

    graphics.writeText(2, 8, "Rotor Speed:")
    graphics.writeTextAllignRight(currentWindowWidth, 9, rotorspeed[1], rotorspeed[2])

    graphics.writeText(2, 11, "Energy Production:")
    graphics.writeTextAllignRight(currentWindowWidth, 12, energy[1], energy[2])

    graphics.writeText(2, 14, "Flowrate/Max Flowrate:")
    graphics.writeTextAllignRight(currentWindowWidth, 15, flowrate[1], flowrate[2])
    term.redirect(mon)
end

--[[
    Display Reactor Data

    @param {int} tChannel - Channel number of the reactor to display data from
    @param {object} tWindow - CC Window object of the reactor 
]]
local function renderReactor(rChannel, rWindow)
    --Get Reactor Data Strings
    local active = {}
    if nuclearState[rChannel]["active"] then
        active = { "  Running  ", colors.green}
    else
        active = {"  Offline  ", colors.red}
    end
    local fuelTemperature = {}
    if math.floor(nuclearState[rChannel]["fuelTemperature"]) > 380
        and math.floor(nuclearState[rChannel]["fuelTemperature"]) < 430
    then
        fuelTemperature = {tostring(math.floor(nuclearState[rChannel]["fuelTemperature"])) .. " C", colors.green}
    else
        fuelTemperature = {tostring(math.floor(nuclearState[rChannel]["fuelTemperature"])) .. " C", colors.red}    
    end    
    local casingTemperature = {}
    if math.floor(nuclearState[rChannel]["casingTemperature"]) > 325
        and math.floor(nuclearState[rChannel]["casingTemperature"]) < 375
    then
        casingTemperature = {tostring(math.floor(nuclearState[rChannel]["casingTemperature"])) .. " C", colors.green}
    else
        casingTemperature = {tostring(math.floor(nuclearState[rChannel]["casingTemperature"])) .. " C", colors.red}    
    end  
    local fuelReactivity = {}
    if math.floor(nuclearState[rChannel]["fuelReactivity"]) > 440
        and math.floor(nuclearState[rChannel]["fuelReactivity"]) < 460
    then
        fuelReactivity = {tostring(math.floor(nuclearState[rChannel]["fuelReactivity"])) .. " %", colors.green}
    else
        fuelReactivity = {tostring(math.floor(nuclearState[rChannel]["fuelReactivity"])) .. " %", colors.red}    
    end  
    --Get Reactor window
    term.redirect(rWindow)
    local currentWindowWidth, currentWindowHeight = term.getSize()
    --Draw data
    graphics.writeText(2, 5, "Reactor Status:")
    graphics.writeTextAllignRight(currentWindowWidth, 6, active[1], active[2])

    graphics.writeText(2, 8, "Core Temperature:")
    graphics.writeTextAllignRight(currentWindowWidth, 9, fuelTemperature[1], fuelTemperature[2])

    graphics.writeText(2, 11, "Casing Temperature:")
    graphics.writeTextAllignRight(currentWindowWidth, 12, casingTemperature[1], casingTemperature[2])

    graphics.writeText(2, 14, "Fuel Reactivity:")
    graphics.writeTextAllignRight(currentWindowWidth, 15, fuelReactivity[1], fuelReactivity[2])
    term.redirect(mon)
end

--[[
    Display General Display Data

    @param {object} tWindow - CC Window object of the General Display     
]]
local function renderGeneralDisplay(gWindow)
    --Get General Display Data Strings
    local controlRodCount = nuclearState[reactorChannel]["controlRodCount"]
    local controlRodInsertion = nuclearState[reactorChannel]["controlRodInsertion"]
    local fuelConsumptionSec = nuclearState[reactorChannel]["fuelConsumedLastTick"]*20
    local fuelConsumption = {}
    if nuclearState[reactorChannel]["fuelConsumedLastTick"] > 0.55 then
        fuelConsumption = {string.sub(fuelConsumptionSec, 1, 5) .. " mB/sec", colors.green}
    else
        fuelConsumption = {string.sub(fuelConsumptionSec, 1, 5) .. " mB/sec", colors.red}
    end    
    local secondsPerIngot = (1000/nuclearState[reactorChannel]["fuelConsumedLastTick"])/20
    local ingotConsumption = {string.sub(secondsPerIngot, 1, 5) .. " sec/Ingot", colors.lime}
    local totalEnergyProduced = nuclearState[turbine1Channel]["energyProducedLastTick"] + nuclearState[turbine2Channel]["energyProducedLastTick"] + nuclearState[turbine3Channel]["energyProducedLastTick"]    
    local energy = {}
    if math.floor(totalEnergyProduced) > 45000 then
        energy = {tostring(math.floor(totalEnergyProduced)) .. " RF/tick", colors.green}
    else
        energy = {tostring(math.floor(totalEnergyProduced)) .. " RF/tick", colors.red}
    end
    local hotFluidProduced = {}
    if math.floor(nuclearState[reactorChannel]["hotFluidProducedLastTick"]) == 3900 then
        hotFluidProduced = {nuclearState[reactorChannel]["hotFluidProducedLastTick"] .. " mB/tick", colors.green}
    else
        hotFluidProduced = {nuclearState[reactorChannel]["hotFluidProducedLastTick"] .. " mB/tick", colors.red}
    end
    local fuelAmount = {nuclearState[reactorChannel]["fuelAmount"] .. " mB", colors.lime}
    local wasteAmount = {nuclearState[reactorChannel]["wasteAmount"] .. " mB", colors.cyan}
    --Get General Display Window
    term.redirect(gWindow)
    local currentWindowWidth, currentWindowHeight = term.getSize()
    --Draw Data
    graphics.writeText(2, 5, "Fuel Consumption:")
    graphics.writeTextAllignRight(currentWindowWidth, 6, ingotConsumption[1], ingotConsumption[2])

    graphics.writeText(2, 8, "Hot Fluid Production:")
    graphics.writeTextAllignRight(currentWindowWidth, 9, hotFluidProduced[1], hotFluidProduced[2])
    
    graphics.writeText(2, 11, "Total Energy Produced:")
    graphics.writeTextAllignRight(currentWindowWidth, 12, energy[1], energy[2])

    graphics.writeText(2, 14, "Fuel In Reactor")
    graphics.writeTextAllignRight(currentWindowWidth, 15, fuelAmount[1], fuelAmount[2])

    graphics.writeText(2, 17, "Waste In Reactor:")
    graphics.writeTextAllignRight(currentWindowWidth, 18, wasteAmount[1], wasteAmount[2])

    graphics.writeText(2, 20, "Rod Ins. Percentage:")
    graphics.writeText(8, 22, "| Rod# | Ins. | ")
    graphics.writeText(7, 23, "-----------------")
    for i=0,controlRodCount-1 do
        graphics.writeText(8, i+24, "|  #" .. i .. "  |      | ")
        graphics.writeText(16, i+24, "  " .. controlRodInsertion[i] .. "% ", colors.orange)
    end
    term.redirect(mon)
end

--[[
    Setup Windows
]]
local function setupWindows()
    utils.debugPrint(debug, "        Creating General Display Window")
    generalDisplayWindow = graphics.setupWindow("General Display", 2, 0, colors.purple)
    utils.debugPrint(debug, "        Creating Reactor Window")
    reactorWindow = graphics.setupWindow("Reactor", 1, 1, colors.green)
    utils.debugPrint(debug, "        Creating Turbine 1 Window")
    turbine1Window = graphics.setupWindow("Turbine 1", 1, 2, colors.lightBlue)
    utils.debugPrint(debug, "        Creating Turbine 2 Window")
    turbine2Window = graphics.setupWindow("Turbine 2", 1, 4, colors.blue)
    utils.debugPrint(debug, "        Creating Turbine 3 Window")
    turbine3Window = graphics.setupWindow("Turbine 3", 1, 5, colors.cyan)
end

--[[
    Update State data

    @param {int} sChannel - The State channel used as table key - channels set through CL arguments
    @param {table} sState - State data table
]]
local function updateStateData(sChannel, sState)
    if sChannel == 300 then
        utils.debugPrint(debug, "    Updating Data for Reactor")
    else
        utils.debugPrint(debug, "    Updating Data for Turbine " .. tostring(sChannel%300))
    end
    nuclearState[sChannel] = textutils.unserialize(sState)
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
        if p3 == reactorChannel 
            and p3 == expectedReplyChannel 
        then
            utils.debugPrint(debug, "        Received Reactor Response")
            updateStateData(p3, p4)
            return true
        elseif p3 == turbine1Channel
            or p3 == turbine2Channel
            or p3 == turbine3Channel
            and p3 == expectedReplyChannel
        then
            utils.debugPrint(debug, "        Received Turbine " .. tostring(p3%300) .. " Response" )
            updateStateData(p3, p4)
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
    Initialize PC setup
    Label pc, get peripherals
    Set up Monitor and get the monitor vars
    Set up Windows
]]
local function init()
    utils.debugPrint(debug, "Running initialization")
    utils.debugPrint(debug, "    Computer Label")
    cLabel ="Nuclear Display - Ch " .. constants.NUCLEAR_DISPLAY_CHANNEL
    os.setComputerLabel(cLabel)
    utils.debugPrint(debug, "    Getting Monitor Wrapper")    
    mon = utils.getPeripheralHandle("monitor")
    terminalScreen = term.redirect(mon) --Original PC terminal saved as var
    utils.debugPrint(debug, "    Getting Modem Wrapper")
    mod = utils.getAndOpenModems(replyChannel)
    utils.debugPrint(debug, "    Resetting Screen")
    graphics.resetScreen()
    utils.debugPrint(debug, "    Setting up windows")
    setupWindows()
    return true
end

--[[
    Main function
    Gets data from Turbine and Reactor monitors and sets them to display
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
            succesfulCycle = true
            --Start Data gather from reactor and turbines
            utils.debugPrint(debug, "Sending Reactor Request")
            mod.transmit(reactorChannel, replyChannel, constants.REACTOR_REQUEST_MESSAGE)
            if getNewEvent(reactorChannel) == false then
                succesfulCycle = false
                utils.debugPrint(debug, "    Failed to get Reactor data")
            else
                utils.debugPrint(debug, "    Updating Reactor Window")
                renderReactor(reactorChannel, reactorWindow)
            end
            utils.debugPrint(debug, "Sending Turbine 1 Request")
            mod.transmit(turbine1Channel, replyChannel, constants.TURBINE_REQUEST_MESSAGE)
            if getNewEvent(turbine1Channel) == false then
                succesfulCycle = false
                utils.debugPrint(debug, "    Failed to get Turbine 1 data")
            else
                utils.debugPrint(debug, "    Updating Turbine 1 Window")
                renderTurbine(turbine1Channel, turbine1Window)
            end
            utils.debugPrint(debug, "Sending Turbine 2 Request")
            mod.transmit(turbine2Channel, replyChannel, constants.TURBINE_REQUEST_MESSAGE)
            if getNewEvent(turbine2Channel) == false then
                succesfulCycle = false
                utils.debugPrint(debug, "    Failed to get Turbine 2 data")
            else
                utils.debugPrint(debug, "    Updating Turbine 2 Window")
                renderTurbine(turbine2Channel, turbine2Window)
            end
            utils.debugPrint(debug, "Sending Turbine 3 Request")
            mod.transmit(turbine3Channel, replyChannel, constants.TURBINE_REQUEST_MESSAGE)
            if getNewEvent(turbine3Channel) == false  then
                succesfulCycle = false
                utils.debugPrint(debug, "    Failed to get Turbine 3 data")
            else
                utils.debugPrint(debug, "    Updating Turbine 3 Window")
                renderTurbine(turbine3Channel, turbine3Window)
            end
            if succesfulCycle then
                utils.debugPrint(debug, "All data requests send and received")
                utils.debugPrint(debug, "    Updating General Display Data Window")
                renderGeneralDisplay(generalDisplayWindow)
            else
                utils.debugPrint(debug, "Failed getting some of the data, retrying next cycle")
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