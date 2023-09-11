SUPPORTED_ATTRIBUTES = {}
MIN_K_TEMP = 500
MAX_K_TEMP = 20000
HAS_BRIGHTNESS = true

function RFP.SYNCHRONIZE(idBinding, strCommand, tParams)
    C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED', { LIGHT_BRIGHTNESS_CURRENT = LIGHT_LEVEL })
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
    
        if target == 0 then
            brightnessServiceCall["service"] = "turn_off"
        end
    end

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
            C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED', { LIGHT_BRIGHTNESS_CURRENT = 0 })
        elseif state == "on" and not HAS_BRIGHTNESS then
            C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED', { LIGHT_BRIGHTNESS_CURRENT = 100 })
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
        else
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
            supports_color = hasColor,
            supports_color_correlated_temperature = hasCCT,
            color_correlated_temperature_min = MIN_K_TEMP,
            color_correlated_temperature_max = MAX_K_TEMP
        }

        C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams)
    end
end