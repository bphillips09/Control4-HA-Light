SUPPORTED_ATTRIBUTES = {}
MIN_K_TEMP = 500
MAX_K_TEMP = 20000
HAS_BRIGHTNESS = true
HAS_EFFECTS = false
LAST_EFFECT = "Select Effect"
EFFECTS_LIST = {}
WAS_ON = false

function RFP.SYNCHRONIZE(idBinding, strCommand, tParams)
    C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED', { LIGHT_BRIGHTNESS_CURRENT = LIGHT_LEVEL })
end

function RFP.BUTTON_ACTION(idBinding, strCommand, tParams)
    if tParams.ACTION == "2" then
        if tParams.BUTTON_ID == "0" then
            SetLightValue(100)
        elseif tParams.BUTTON_ID == "1" then
            SetLightValue(0)
        else
            if WAS_ON then
                SetLightValue(0)
            else
                SetLightValue(100)
            end
        end
    end
end

function RFP.PUSH_SCENE(idBinding, strCommand, tParams)
    local scene_value = C4:ParseXml(tParams.ELEMENTS)
    C4:PersistSetValue("ALS:" .. tParams.SCENE_ID, scene_value, false) 
end

function RFP.ACTIVATE_SCENE(idBinding, strCommand, tParams)
    local scene_value = C4:PersistGetValue("ALS:" .. tParams.SCENE_ID, false) 
    print("Loading Advanced Lighting Scene " .. tParams.SCENE_ID)
    for _, v in pairs(scene_value["ChildNodes"]) do
        if v["Name"] == "level" or v["Name"] == "brightness" then
            SetLightValue(v["Value"]) 
            break
        end
    end
end

function RFP.ON(idBinding, strCommand, tParams)
    local turnOnServiceCall = {
        domain = "light",
        service = "turn_on",

        service_data = {},

        target = {
            entity_id = EntityID
        }
    }
    tParams = {
        JSON = JSON:encode(turnOnServiceCall)
    }
    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.OFF(idBinding, strCommand, tParams)
    local turnOffServiceCall = {
        domain = "light",
        service = "turn_off",

        service_data = {},

        target = {
            entity_id = EntityID
        }
    }
    tParams = {
        JSON = JSON:encode(turnOffServiceCall)
    }
    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.DO_PUSH(idBinding, strCommand, tParams)
    --Do nothing for now
end

function RFP.DO_RELEASE(idBinding, strCommand, tParams)
    --Do nothing for now
end

function RFP.DO_CLICK(idBinding, strCommand, tParams)
    local tParams = {
        ACTION = "2",
        BUTTON_ID = ""
    }
    
    if idBinding == 200 then
        tParams.BUTTON_ID = "0"
    elseif idBinding == 201 then
        tParams.BUTTON_ID = "1"
    elseif idBinding == 202 then
        tParams.BUTTON_ID = "2"
    end

    RFP:BUTTON_ACTION(strCommand, tParams)
end

function SetLightValue(value)
    local tParams = {
        LIGHT_BRIGHTNESS_TARGET = value
    }

    RFP.SET_BRIGHTNESS_TARGET(nil, nil, tParams)
end

function RFP.SET_COLOR_TARGET(idBinding, strCommand, tParams)
    local targetX = tParams.LIGHT_COLOR_TARGET_X
    local targetY = tParams.LIGHT_COLOR_TARGET_Y

    local colorServiceCall = {
        domain = "light",
        service = "turn_on",

        service_data = {
            xy_color = {
                targetX, targetY
            }
        },

        target = {
            entity_id = EntityID
        }
    }

    tParams = {
        JSON = JSON:encode(colorServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_BRIGHTNESS_TARGET(idBinding, strCommand, tParams)
    local target = tonumber(tParams.LIGHT_BRIGHTNESS_TARGET)

    local targetMappedValue = MapValue(target, 255, 100)
    local brightnessServiceCall = {
        domain = "light",
        service = "turn_on",

        service_data = {
            brightness = targetMappedValue
        },

        target = {
            entity_id = EntityID
        }
    }

    if not HAS_BRIGHTNESS then
        brightnessServiceCall.service_data = {}
    end

    if target == 0 then
        brightnessServiceCall.service_data = {}
        brightnessServiceCall["service"] = "turn_off"
    end

    tParams = {
        JSON = JSON:encode(brightnessServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_LEVEL(idBinding, strCommand, tParams)
    tParams["LIGHT_BRIGHTNESS_TARGET"] = tParams.LEVEL

    RFP:SET_BRIGHTNESS_TARGET(strCommand, tParams)
end

function RFP.GROUP_SET_LEVEL(idBinding, strCommand, tParams)
    tParams["LIGHT_BRIGHTNESS_TARGET"] = tParams.LEVEL

    RFP:SET_BRIGHTNESS_TARGET(strCommand, tParams)
end

function RFP.GROUP_RAMP_TO_LEVEL(idBinding, strCommand, tParams)
    tParams["LIGHT_BRIGHTNESS_TARGET"] = tParams.LEVEL

    RFP:SET_BRIGHTNESS_TARGET(strCommand, tParams)
end

function RFP.SELECT_LIGHT_EFFECT(idBinding, strCommand, tParams)
    local brightnessServiceCall = {
        domain = "light",
        service = "turn_on",

        service_data = {
            effect = tostring(tParams.value)
        },

        target = {
            entity_id = EntityID
        }
    }

    tParams = {
        JSON = JSON:encode(brightnessServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.RECEIEVE_STATE(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.response)

    local stateData

    if jsonData ~= nil then
        stateData = jsonData
    end

    Parse(stateData)
end

function RFP.RECEIEVE_EVENT(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.data)

    local eventData

    if jsonData ~= nil then
        eventData = jsonData["event"]["data"]["new_state"]
    end

    Parse(eventData)
end

function Parse(data)
    if data == nil then
        print("NO DATA")
        return
    end

    if data["entity_id"] ~= EntityID then
        return
    end

    if not Connected then
        C4:SendToProxy(5001, 'ONLINE_CHANGED', { STATE = true })
        Connected = true
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if state ~= nil then
        if state == "off" then
            WAS_ON = false
            C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED', { LIGHT_BRIGHTNESS_CURRENT = 0 })
        elseif state == "on" and not HAS_BRIGHTNESS then
            WAS_ON = true
            C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED', { LIGHT_BRIGHTNESS_CURRENT = 100 })
        elseif state == "on" then
            WAS_ON = true
        end
    end

    if attributes == nil then
        C4:SendToProxy(5001, 'ONLINE_CHANGED', { STATE = false })
        return
    end

    local selectedAttribute = attributes["brightness"]
    if selectedAttribute ~= nil then
        C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED',
            { LIGHT_BRIGHTNESS_CURRENT = MapValue(tonumber(selectedAttribute), 100, 255) })
    end

    selectedAttribute = attributes["xy_color"]
    if selectedAttribute ~= nil then
        local xyTable = selectedAttribute

        if xyTable ~= nil then
            C4:SendToProxy(5001, 'LIGHT_COLOR_CHANGED',
                { LIGHT_COLOR_CURRENT_X = xyTable[1], LIGHT_COLOR_CURRENT_Y = xyTable[2] })
        else
            print("Invalid X,Y format")
        end
    end

    selectedAttribute = attributes["min_color_temp_kelvin"]
    if selectedAttribute ~= nil and MIN_K_TEMP ~= tonumber(selectedAttribute) then
        MIN_K_TEMP = tonumber(selectedAttribute)
    end

    selectedAttribute = attributes["max_color_temp_kelvin"]
    if selectedAttribute ~= nil and MAX_K_TEMP ~= tonumber(selectedAttribute) then
        MAX_K_TEMP = tonumber(selectedAttribute)
    end

    selectedAttribute = attributes["effect"]
    if selectedAttribute ~= nil and LAST_EFFECT ~= selectedAttribute then
        LAST_EFFECT = selectedAttribute

        C4:SendToProxy(5001, 'EXTRAS_STATE_CHANGED', { XML = GetEffectsStateXML() }, 'NOTIFY')
    elseif selectedAttribute == nil then
        LAST_EFFECT = "Select Effect"
        C4:SendToProxy(5001, 'EXTRAS_STATE_CHANGED', { XML = GetEffectsStateXML() }, 'NOTIFY')
    end

    selectedAttribute = attributes["effect_list"]
    if selectedAttribute ~= nil and not TablesMatch(EFFECTS_LIST, selectedAttribute) then
        EFFECTS_LIST = selectedAttribute
        HAS_EFFECTS = true

        C4:SendToProxy(5001, 'EXTRAS_SETUP_CHANGED', { XML = GetEffectsXML() }, 'NOTIFY')
    elseif selectedAttribute == nil then
        EFFECTS_LIST = {}
        HAS_EFFECTS = false
    end

    selectedAttribute = attributes["supported_color_modes"]
    if selectedAttribute ~= nil and not TablesMatch(SUPPORTED_ATTRIBUTES, selectedAttribute) then
        SUPPORTED_ATTRIBUTES = selectedAttribute

        HAS_BRIGHTNESS = true
        local hasColor = false
        local hasCCT = false

        if HasValue(SUPPORTED_ATTRIBUTES, "onoff") then
            HAS_BRIGHTNESS = false
        elseif HasValue(SUPPORTED_ATTRIBUTES, "brightness") then
            HAS_BRIGHTNESS = true
        end

        if GetStatesHasColor() then
            hasColor = true

            if HasValue(SUPPORTED_ATTRIBUTES, "color_temp") then
                hasCCT = true
            end
        end

        if hasCCT == false then
            MIN_K_TEMP = 0
            MAX_K_TEMP = 0
        end

        local tParams = {
            dimmer = HAS_BRIGHTNESS,
            set_level = HAS_BRIGHTNESS,
            supports_target = HAS_BRIGHTNESS,
            supports_color = hasColor,
            supports_color_correlated_temperature = hasCCT,
            color_correlated_temperature_min = MIN_K_TEMP,
            color_correlated_temperature_max = MAX_K_TEMP,
            has_extras = HAS_EFFECTS
        }

        C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams, "NOTIFY")
    end
end

function GetStatesHasColor()
    return HasValue(SUPPORTED_ATTRIBUTES, "color_temp") or HasValue(SUPPORTED_ATTRIBUTES, "hs") or HasValue(SUPPORTED_ATTRIBUTES, "xy") or HasValue(SUPPORTED_ATTRIBUTES, "rgb")
    or HasValue(SUPPORTED_ATTRIBUTES, "rgbw") or HasValue(SUPPORTED_ATTRIBUTES, "rgbww")
end

function GetEffectsStateXML()
    return '<extras_state><extra><object id="effect" value="' .. LAST_EFFECT .. '"/></extra></extras_state>'
end

function GetEffectsXML()
    local extras = ""
    local items = ""

    extras =
        '<extras_setup><extra><section label="Effects"><object type="list" id="effect" label="Effect" command="SELECT_LIGHT_EFFECT" value="'
        .. LAST_EFFECT .. '"><list maxselections="1" minselections="1">'

    for _, effect in pairs(EFFECTS_LIST) do
        items = items .. '<item text="' .. effect .. '" value="' .. effect .. '"/>'
    end

    return extras .. items .. '</list></object></section></extra></extras_setup>'
end
