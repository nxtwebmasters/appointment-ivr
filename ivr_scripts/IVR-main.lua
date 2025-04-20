package.cpath ="/usr/lib/x86_64-linux-gnu/lua/5.2/?.so;" .. package.cpath
package.path = "/usr/share/lua/5.2/?.lua;" .. package.path
local https = require("ssl.https")
local http = require("socket.http")
local ltn12 = require "ltn12"
local json = require "json"

session:answer()

local prompts_folder = "/usr/share/freeswitch/sounds/prompts/"
function main_menu()

    local returnStr = "MAIN"
    while (session:ready() and (returnStr == "MAIN")) do
        returnStr = nil
        local digits = session:playAndGetDigits(1, 1, 1, 3000, "#", prompts_folder .. "welcome.mp3","", "")
        session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
        if (digits == "1") then
            dofile("/usr/share/freeswitch/scripts/myIvr-urdu.lua")
        elseif (digits == "2") then
            dofile("/usr/share/freeswitch/scripts/myIvr-english.lua")
        elseif (digits == nil or digits == '') then
            --do nothing
            returnStr = "MAIN"
        else
            --do nothing
            returnStr = "MAIN"
        end
        session:sleep(1000);
    end
    return returnStr
end


main_menu()
