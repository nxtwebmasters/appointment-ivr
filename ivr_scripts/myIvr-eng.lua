package.cpath ="/usr/lib/x86_64-linux-gnu/lua/5.2/?.so;" .. package.cpath
package.path = "/usr/share/lua/5.2/?.lua;" .. package.path
local https = require("ssl.https")
local http = require("socket.http")
local ltn12 = require "ltn12"
local json = require("json")
local config = require "config"

session:answer()
local call_started_timestamp = os.time() * 1000;
freeswitch.consoleLog("INFO",  "IVR CALL STARTED AT : " .. call_started_timestamp)


local call_uuid = session:getVariable("uuid");
freeswitch.consoleLog("INFO", "CALL UUID : " .. call_uuid)

local caller_id_number = session:getVariable("caller_id_number");
freeswitch.consoleLog("INFO", "CALLER ID NUMBER : " .. caller_id_number)

local call_id = session:getVariable("sip_call_id")
freeswitch.consoleLog("INFO", "SIP CALL ID : " .. call_id)

local destination_number = session:getVariable("destination_number");
freeswitch.consoleLog("INFO", "SERVICE IDENTIFIER : " .. destination_number)

-- 0 to 20, then 30/40/50/60/70/80/90
local digit_prompts = "/usr/share/freeswitch/sounds/prompts/english/digits/"
-- January to December in format mon-00 till mon-12
local month_prompts = "/usr/share/freeswitch/sounds/prompts/english/months/"

local dept_prompts = "/usr/share/freeswitch/sounds/prompts/english/departments/"
local doc_prompts = "/usr/share/freeswitch/sounds/prompts/english/doctors/"
-- Sunday to Monday in format day-0 till day-6
-- a-m and p-m
-- local time_prompts = "/usr/share/freeswitch/sounds/en/us/callie/time/8000/"
local prompts_folder = "/usr/share/freeswitch/sounds/prompts/english/"


local department = nil;
local doctor = nil;
local date = nil;
local slot = nil;
local response = {}

session:setAutoHangup(false)

local appointmentInfo = {}

session:setVariable("playback_delimiter", "!")

session:setVariable("session_in_hangup_hook", "true");
session:setHangupHook("menu_abandoned");

-- Avoids call hangup when menu completed
function emptyfunc()
    -- do nothing
end

function makeExampleDoctor(name, alias, date1, date2, slot1, slot2, slot3) 

    local timings = {}
    local timings1 = {}
    local timings2 = {}

    local slots1 = {}
    local slots2 = {}

    local doctor1 = {}

    timings1["date"] = date1
    timings2["date"] = date2

    table.insert(slots1, slot1)
    table.insert(slots1, slot2)

    table.insert(slots2, slot3)

    timings1["slots"] = slots1
    timings2["slots"] = slots2
    
    table.insert(timings, timings1)
    table.insert(timings, timings2)
    
    doctor1["name"] = name
    doctor1["alias"] = alias
    doctor1["timings"] = timings

    return doctor1
end

function over_twenty_prompt(digits)
    local decade = string.sub(digits, 1,1) .. "0"
    local unit = string.sub(digits, 2,2)
    local wholePrompt = digit_prompts .. decade .. ".mp3!"

    freeswitch.consoleLog("INFO", "--" .. unit .. "--")

    if (unit ~= "0") then
        wholePrompt = wholePrompt .. digit_prompts .. unit .. ".mp3!"
    end

    return wholePrompt
end

function speak_time(time) 
    -- local time = "00:16"
    local ampm = "am"
    local hours = string.sub(time, 1,2)
    local mins = string.sub(time, 4,5)

    local hoursNum = tonumber(hours)
    local minsNum = tonumber(mins)
    if (hoursNum > 11) then
        ampm = "pm"
    end

    if (hoursNum < 1) then
        hoursNum = 12
    end

    if (hoursNum > 12) then
        hoursNum = hoursNum % 12
    end

    local minsPrompt = ""
    if (minsNum == 0) then
        minsPrompt = ""
    else
        minsPrompt = digit_prompts .. tostring(minsNum) .. ".mp3!"
    end

    local timePrompt = digit_prompts .. tostring(hoursNum) .. ".mp3!" .. minsPrompt .. prompts_folder .. ampm .. ".mp3"
    return timePrompt
end

function speak_date(date)
    -- local date = "2025-01-08"
    local yearThousands = string.sub(date, 1,1)
    local yearDecade = string.sub(date, 3,3)
    local yearUnit = string.sub(date, 4,4)
    local month = string.sub(date, 6,7)
    local day = tonumber(string.sub(date, 9,10))
    local date_digit_prompts = "/usr/share/freeswitch/sounds/prompts/english/date_digits/"

    local dayPrompt = ""
    dayPrompt = date_digit_prompts .. tostring(day) .. ".mp3!"
    

    local timePrompt = dayPrompt .. month_prompts .. "mon-" .. month .. ".mp3"
    session:consoleLog("info", "DATE PROMPT: ".. timePrompt .."\n")
    return timePrompt
end

function menu_abandoned()
    freeswitch.consoleLog("INFO", "--------------------MENU ABANDONED--------------------\n")
	local call_hangup_timestamp = os.time() * 1000;
    freeswitch.consoleLog("INFO", "--------------------MENU ABANDONED AT " .. tostring(call_hangup_timestamp) "--------------------\n")
end

function menu_completed()
    freeswitch.consoleLog("INFO", "--------------------MENU COMPLETED--------------------\n")
	local call_hangup_timestamp = os.time() * 1000;
    freeswitch.consoleLog("INFO", "--------------------MENU COMPLETED AT " .. call_hangup_timestamp "--------------------\n")
end

function select_department() 
    local prompt_whole = prompts_folder .. "please_enter.mp3!"
    local index = 1
    for _, department in ipairs(response) do
        prompt_whole = prompt_whole .. digit_prompts .. tostring(index) .. ".mp3!" .. prompts_folder .. "for.mp3!" .. dept_prompts .. department["alias"] .. ".mp3!"
        index = index + 1
    end

    prompt_whole = prompt_whole .. prompts_folder .. "zero_prev_star_main.mp3!"
    local returnStr = "PREV"
    while (session:ready() and returnStr == "PREV") do
        returnStr = "PREV"
        
            local digits = session:playAndGetDigits(1, 1, 1, 8000, "#", prompt_whole, prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "0") then
                return "PREV"
                -- session:streamFile(prompts_folder .. "invalid_entry.mp3");
            elseif (digits == "*") then
                return "MAIN"
            elseif (#digits > 0 and #digits < 2) then
                if (tonumber(digits) > #response) then
                    session:streamFile(prompts_folder .. "invalid_entry.mp3");
                else
                    freeswitch.consoleLog("NOTICE", "SELECTED  " .. json.encode(response[tonumber(digits)]["name"]))
                    department = response[tonumber(digits)]
                    returnStr = select_doctor(department)
                end
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return returnStr;
end

function select_doctor(dept)
    local doctors = dept["doctors"]

    local prompt_whole = prompts_folder .. "please_enter.mp3!"
    local index = 1
    for ind, doctor in ipairs(doctors) do
        prompt_whole = prompt_whole .. digit_prompts .. tostring(index) .. ".mp3!" .. prompts_folder .. "for.mp3!" .. doc_prompts .. doctor["alias"]:gsub(" ", "_") .. ".mp3!"
        index = index + 1
    end
    prompt_whole = prompt_whole .. prompts_folder .. "zero_prev_star_main.mp3!" 

    local returnStr = "PREV"
    while (session:ready() and returnStr == "PREV") do
        returnStr = "PREV"
        
            local digits = session:playAndGetDigits(1, 1, 1, 8000, "#", prompt_whole, prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "0") then
                return "PREV"
                -- session:streamFile(prompts_folder .. "invalid_entry.mp3");
            elseif (digits == "*") then
                return "MAIN"
            elseif (#digits > 0 and #digits < 2) then
                if (tonumber(digits) > #doctors) then
                    session:streamFile(prompts_folder .. "invalid_entry.mp3");
                else
                    freeswitch.consoleLog("NOTICE", "SELECTED  " .. json.encode(doctors[tonumber(digits)]))
                    doctor = doctors[tonumber(digits)]
                    returnStr = select_day(doctor["timings"])
                end
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return returnStr;
end

function select_day(timings)
    session:streamFile(prompts_folder .. "doctor_days.mp3");
    local prompt_whole = prompts_folder .. "please_enter.mp3!"
    local index = 1
    for _, timing in ipairs(timings) do
        prompt_whole = prompt_whole .. digit_prompts .. tostring(index) .. ".mp3!" .. prompts_folder .. "for.mp3!" .. speak_date(timing["date"]) .. "!"
        index = index + 1
    end
    prompt_whole = prompt_whole .. prompts_folder .. "zero_prev_star_main.mp3!"

    local returnStr = "PREV"
    while (session:ready() and returnStr == "PREV") do
        returnStr = "PREV"
        
            local digits = session:playAndGetDigits(1, 1, 1, 8000, "#", prompt_whole, prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "0") then
                return "PREV"
                -- session:streamFile(prompts_folder .. "invalid_entry.mp3");
            elseif (digits == "*") then
                return "MAIN"
            elseif (#digits > 0 and #digits < 2) then
                if (tonumber(digits) > #timings) then
                    session:streamFile(prompts_folder .. "invalid_entry.mp3");
                else
                    freeswitch.consoleLog("NOTICE", "SELECTED  " .. json.encode(timings[tonumber(digits)]))
                    date = timings[tonumber(digits)]
                    returnStr = select_slot(date)
                end
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return returnStr;
end

function select_slot(day)

    local slots = day["slots"]
    if (#slots < 1) then
        slot = ""
        returnStr = post_appointment_info()
    end
    session:streamFile(prompts_folder .. "doctor_times.mp3");
    local prompt_whole = prompts_folder .. "please_enter.mp3!"
    local index = 1
    for ind, slot in ipairs(slots) do
        prompt_whole = prompt_whole .. digit_prompts .. tostring(index) .. ".mp3!" .. prompts_folder .. "for.mp3!" .. speak_time(slot["timeFrom"]) .. "!" 
    
        -- .. prompts_folder .. "to.mp3!" .. speak_time(slot["timeTo"]) .. "!"
        index = index + 1
    end
    prompt_whole = prompt_whole .. prompts_folder .. "zero_prev_star_main.mp3!"

    local returnStr = "PREV"
    while (session:ready() and returnStr == "PREV") do
        returnStr = "PREV"
        
            local digits = session:playAndGetDigits(1, 1, 1, 8000, "#", prompt_whole, prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "0") then
                return "PREV"
                -- session:streamFile(prompts_folder .. "invalid_entry.mp3");
            elseif (digits == "*") then
                return "MAIN"
            elseif (#digits > 0 and #digits < 2) then
                if (tonumber(digits) > #slots) then
                    session:streamFile(prompts_folder .. "invalid_entry.mp3");
                else
                    freeswitch.consoleLog("NOTICE", "SELECTED  " .. json.encode(slots[tonumber(digits)]))
                    slot = slots[tonumber(digits)]
                    returnStr = recap()
                end
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return returnStr;
end

function recap()

    local prompt_whole = prompts_folder .. "you_have_requested_an_appointment_with.mp3!" .. doc_prompts .. doctor["alias"]:gsub(" ", "_") .. ".mp3!" .. prompts_folder .. "on.mp3!" .. speak_date(date["date"]) .. "!" .. prompts_folder .."at.mp3!" .. speak_time(slot["timeFrom"]) .. "!" .. prompts_folder .. "press_one_to_confirm_this_appointment.mp3!" .. prompts_folder .. "zero_prev_star_main.mp3!"
    
    local returnStr = "PREV"
    while (session:ready() and returnStr == "PREV") do
        returnStr = "PREV"
        
            local digits = session:playAndGetDigits(1, 1, 1, 8000, "#", prompt_whole, prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "0") then
                return "PREV"
                -- session:streamFile(prompts_folder .. "invalid_entry.mp3");
            elseif (digits == "*") then
                return "MAIN"
            elseif (digits == "1") then
                returnStr = post_appointment_info()
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return returnStr;
end

function post_appointment_info() 
    -- here post the doctor info to server and get response
    -- local mockStatus = 200
    -- local status = mockStatus
    local prompt_whole = prompts_folder .. "your_appointment_with.mp3!" .. doc_prompts .. doctor["alias"]:gsub(" ", "_") .. ".mp3!" .. prompts_folder .. "on.mp3!" .. speak_date(date["date"]) .. "!".. prompts_folder .. "at.mp3!" .. speak_time(slot["timeFrom"]) .. "!"

    local req_body = {
        type = "ivr_appointment",
        status = "pending",
        created_by = "appointment_ivr",
        department_alias = department["alias"],
        doctor_alias = doctor["alias"],
        date = date["date"],
        slot = json.encode(slot):gsub("\\", ""),
        patient_ani = session:getVariable("caller_id_number")
    }
    
    
    local req_body1 = json.encode(req_body)
	freeswitch.consoleLog("INFO", "POSTING APPOINTMENT INFO :" .. req_body1 .. "\n")
    local response_body = {}

    local res, code, headers, status = https.request {
        method = "POST",
        url = config.createAppointmentApi,
        source = ltn12.source.string(req_body1),
        headers = {
            ["content-type"] = "application/json",
            ["Content-Length"] = string.len(req_body1)
        },
        sink = ltn12.sink.table(response_body)
    }

	freeswitch.consoleLog("INFO", "RESPONSE BODY = " .. tostring(res) .. "\n STATUS CODE = " .. tostring(code) .. "\n  STATUS BODY = " .. tostring(status) .."\n")
    

    freeswitch.consoleLog("INFO", "RESPONSE:  "  .. json.encode(response_body))
    
    if (code == 200 or code == 201 or code == 202) then
        session:streamFile(prompt_whole .. prompts_folder .. "has_been_confirmed.mp3")
        session:streamFile(prompts_folder .. "receive_appointment_id.mp3")
        session:streamFile(prompts_folder .. "thank_for_time.mp3")
        -- your appointment with Doctor <doctor name> on <date> at <slot start time> has been confirmed with id number <id>
        -- thank you for your time
        session:setHangupHook("menu_completed");
        session:hangup()
        return "END"
    else
        session:streamFile(prompt_whole .. prompts_folder .. "could_not_confirm.mp3")
        -- your appointment with Doctor <doctor name> on <date> at <slot start time> could not be confirmed at this time. Please try again later
        return "MAIN"
    end
end


function main_menu()

    local returnStr = "MAIN"
    while (session:ready() and (returnStr == "PREV" or returnStr == "MAIN")) do
        returnStr = "MAIN"
        
            local digits = session:playAndGetDigits(1, 1, 1, 3000, "#", prompts_folder .. "main_menu.mp3", prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "1") then
                returnStr = call_appointment_api()
            elseif (digits == "2") then
                returnStr = cancel_appointment()
            elseif (digits == "3") then
                returnStr = appointment_status()
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return returnStr
end

function call_appointment_api()
	local response_body = {}

	local res, code, headers, status = https.request {
		method = "GET",
		url = config.getAllSchedulesApi,
		source = ltn12.source.string(""),
		headers = {
			["content-type"] = "application/json",
		},
		sink = ltn12.sink.table(response_body)
	}
	freeswitch.consoleLog("INFO", "RESPONSE BODY = " .. json.encode(response_body) .. "\n STATUS CODE = " .. tostring(code) .. "\n  STATUS BODY = " .. tostring(status) .."\n")
	

    local fixedResponse = ""

    for a, b in ipairs(response_body) do
       fixedResponse  = fixedResponse .. b
    end

	freeswitch.consoleLog("INFO", "RESPONSE BODY = " .. fixedResponse .. "\n STATUS CODE = " .. tostring(code) .. "\n  STATUS BODY = " .. tostring(status) .."\n")

    response = json.decode(fixedResponse)["data"]

    if (code == 200 or code == 201 or code == 202) then
        return select_department()
    else
        session:streamFile(prompts_folder .. "cannot_book.mp3");
        return "MAIN"
    end

    -- CALL HOSPITAL API TO GET DEPARTMENTS AND DOCTORS AND TIMES
end	

function mock() 
    
    local responseItem = {}
    responseItem["name"] = "Emergency"
    local doctors = {}
    
    local timings1 = {
        timeFrom = "10:00",
        timeTo = "10:30"
    }
    local timings2 = {
        timeFrom = "20:00",
        timeTo = "20:20"
    }
    local timings3 = {
        timeFrom = "08:10",
        timeTo = "08:30"
    }
    local timings4 = {
        timeFrom = "10:00",
        timeTo = "10:10"
    } 
    
    local doctor1 = makeExampleDoctor("Emily Carter", "emily_carter", "2025-03-09", "2025-07-20", timings1, timings2,timings3)
    local doctor2 = makeExampleDoctor("David Hartman", "david_hartman", "2025-01-11", "2025-11-05", timings1, timings3, timings4)

    table.insert(doctors, doctor1)
    table.insert(doctors, doctor2)

    responseItem["doctors"] = doctors
    table.insert(response, responseItem)
    local req_body1 = json.encode(response)

    freeswitch.consoleLog("INFO", "DEPARTMENT INFO     "  .. req_body1)
    local mockStatus = 200
    local status = mockStatus
    if (status == 200) then
        return select_department()
    else
        session:streamFile(prompts_folder .. "cannot_book.mp3");
        return "MAIN"
    end
end

function cancel_appointment()
    local prompt_whole = prompts_folder .. "please_enter.mp3!" -- appointment id or press * to return to main menu

    local returnStr = "PREV"
    while (session:ready() and returnStr == "PREV") do
        returnStr = "PREV"
        
            local digits = session:playAndGetDigits(1, 14, 1, 8000, "#", prompts_folder .. "enter_appointment_id_or_return.mp3", prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "*") then
                return "MAIN"
            elseif (#digits > 7 and #digits < 15) then
                -- CALL HOSPITAL API WITH APPOINTMENT ID
                local responseStatus = 404
                if (responseStatus == 200) then
                    speak_date(date)
                    speak_time(timefrom)
                    speak_time(timeto)
                elseif (responseStatus == 404) then
                    session:streamFile(prompts_folder .. "appointment_not_found.mp3");
                    -- APPOINTMENT CANNOT BE CANCELLED OR NOT FOUND
                    return "MAIN"
                else
                    session:streamFile(prompts_folder .. "appointment_cancel_fail.mp3");
                    return "MAIN"
                end
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return nil
end	

function appointment_status()

    local returnStr = "PREV"
    while (session:ready() and returnStr == "PREV") do
        returnStr = "PREV"
        
            local digits = session:playAndGetDigits(1, 14, 1, 5000, "#", prompts_folder .. "enter_appointment_id_or_return.mp3", prompts_folder .. "invalid_entry.mp3", "")
            session:consoleLog("info", "DIGIT PRESSED: ".. digits .."\n")
            if (digits == "*") then
                return "MAIN"
            elseif (#digits > 7 and #digits < 15) then
                -- CALL HOSPITAL API WITH APPOINTMENT ID
                local response_body = {}

                local res, code, headers, status = https.request {
                    method = "GET",
                    url = config.appointmentStatusApi .. tostring(digits) .. "-APT",
                    source = ltn12.source.string(""),
                    headers = {
                        ["content-type"] = "application/json",
                    },
                    sink = ltn12.sink.table(response_body)
                }

                freeswitch.consoleLog("INFO", "RESPONSE BODY = " .. response_body[1] .. "\n STATUS CODE = " .. tostring(code) .. "\n  STATUS BODY = " .. tostring(status) .."\n")

                -- CALL HOSPITAL API WITH APPOINTMENT ID
                if (code == 200 or code == 201 or code == 202) then
                    session:streamFile(prompts_folder .. "your_appointment_status_is.mp3!" .. prompts_folder .. json.decode(response_body[1])["data"]["appointment_status"] .. ".mp3!");
                    return "MAIN"
                else
                    session:streamFile(prompts_folder .. "appointment_not_found.mp3");
                    -- APPOINTMENT CANNOT BE CANCELLED OR NOT FOUND
                end
            elseif (digits == nil or digits == '') then
                --do nothing
            else
                session:streamFile(prompts_folder .. "invalid_entry.mp3");
            end
            session:sleep(1000);
    end
    return nil
end	

-- function nothing()
--     freeswitch.consoleLog("INFO", "REQUEST AGENT OPTION SELECTED\n")
-- 	session:setVariable("session_in_hangup_hook", "false");
-- 	session:sleep(1000);
-- 	session:setVariable("session_in_hangup_hook", "true");
-- 	session:setHangupHook("session_transfer");
-- 	local json_activites = json.encode(activities)
-- 	if (not session:ready()) then
--         menu_abandoned()
--     else
--         menu_completed(activities)
--     end
-- 	freeswitch.consoleLog("INFO", "IVR JOURNEY : " ..json_activites )	
-- end

session:streamFile(prompts_folder .. "welcome.mp3!")
main_menu()
