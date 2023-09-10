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
	local target = tParams.LIGHT_BRIGHTNESS_TARGET

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