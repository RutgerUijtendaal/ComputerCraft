--Load APIs
os.loadAPI("constants")
os.loadAPI("utils")
os.loadAPI("graphics")

--Peripherals
local modem = nil

--Program vars
local debug = constants.DEBUG

local function main()
    modem = utils.getAndOpenModems(constants.CC_CONTROL_CHANNEL)
    while true do 
        graphics.clearTerm()
        utils.debugPrint(debug, "Computer Remote")
        utils.debugPrint(debug, "------------------------")
        utils.debugPrint(debug, "Available Commands:")
        utils.debugPrint(debug, "")
        utils.debugPrint(debug, "r: Restart Network")
        utils.debugPrint(debug, "q: Shut down the network")
        utils.debugPrint(debug, "s: Start up Network")
        utils.debugPrint(debug, "------------------------")
        local event, key = os.pullEvent("key")
        if key == keys.r then
            utils.debugPrint(debug, "Rebooting network...")
            os.sleep(0.5)
            modem.transmit(constants.CC_COMMAND_CHANNEL, constants.CC_CONTROL_CHANNEL, constants.REBOOT_REQUEST_MESSAGE)
        end
        if key == keys.q then
            utils.debugPrint(debug, "Shutting down the network...")
            os.sleep(0.5)
            modem.transmit(constants.CC_COMMAND_CHANNEL, constants.CC_CONTROL_CHANNEL, constants.SHUT_DOWN_REQUEST_MESSAGE)
        end
        if key == keys.s then
            utils.debugPrint(debug, "Starting up the network...")
            os.sleep(0.5)
            modem.transmit(constants.CC_COMMAND_CHANNEL, constants.CC_CONTROL_CHANNEL, constants.START_UP_REQUEST_MESSAGE)
        end        
    end
end

sleep(2)
main()