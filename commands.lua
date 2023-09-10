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

    if attributes == nil then
        C4:SendToProxy(5001, 'ONLINE_CHANGED', { STATE = false })
        return
    end

    if attributes["brightness"] ~= nil then
        C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED',
            { LIGHT_BRIGHTNESS_CURRENT = MapValue(tonumber(attributes["brightness"]), 100, 255) })
    end

    if attributes["xy_color"] ~= nil then
        local xyTable = attributes["xy_color"]

        if xyTable ~= nil then
            C4:SendToProxy(5001, 'LIGHT_COLOR_CHANGED',
                { LIGHT_COLOR_CURRENT_X = xyTable[1], LIGHT_COLOR_CURRENT_Y = xyTable[2] })
        else
            print("Invalid X,Y format")
        end
    end

    if state ~= nil then
        if state == "off" then
            C4:SendToProxy(5001, 'LIGHT_BRIGHTNESS_CHANGED', { LIGHT_BRIGHTNESS_CURRENT = 0 })
        end
    end
end

function MapValue(oldValue, low, high)
    local newValue = ((oldValue * low) / high)

    return math.floor(newValue + 0.5) -- Round to the nearest integer
end