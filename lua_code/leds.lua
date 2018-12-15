local states = {
    -- current = { r=0, g=0, b=0 },
    current = { r=1, g=1, b=1 },
    wanted = { r=0, g=0, b=0 }
}

dofile("config.lua")

_G.cjson = sjson

local steps = 5
local timer_leds = tmr.create()

ws2812.init()
local buffer = ws2812.newBuffer(PIXELS + 1, 3)
-- buffer:fill(0,0,0)
buffer:fill(1,1,1)
ws2812.write(buffer)

function update()
    local updateNeeded = false
    -- print("leds timer started")
    for _,color in ipairs({"r","g","b"}) do
        if (states.current[color] ~= states.wanted[color]) then
            -- Update needed
            updateNeeded = true;
            if (states.current[color] < states.wanted[color]) then
                states.current[color] = states.current[color] + steps
                if (states.current[color] > states.wanted[color]) then
                    states.current[color] = states.wanted[color]
                end
            end
            if (states.current[color] > states.wanted[color]) then
                states.current[color] = states.current[color] - steps
                if (states.current[color] < states.wanted[color]) then
                    states.current[color] = states.wanted[color]
                end
            end
        end
    end
    if (updateNeeded) then
        if (PIXELS_START ~= nil and PIXELS_END ~= nil) then
            for i=PIXELS_START,PIXELS_END,1 do
                -- buffer:set(i,states.current["r"], states.current["g"], states.current["b"])
                -- print(string.format("leds in: r=%d g=%d b=%d", states.current["r"], states.current["g"], states.current["b"]))
                buffer:set(i,states.current["g"], states.current["r"], states.current["b"])
            end
            ws2812.write(buffer)
        else
            -- buffer:fill(states.current["r"], states.current["g"], states.current["b"])
            buffer:fill(states.current["g"], states.current["r"], states.current["b"])
            ws2812.write(buffer)
        end
    else
        -- print("leds timer stopped")
        tmr.stop(timer_leds)
    end
end
tmr.register(timer_leds,50,tmr.ALARM_AUTO, update)


function setColor(color, callback)
    states.wanted = color
    local running, mode = tmr.state(timer_leds)
    callback()
    if (not running) then
        tmr.start(timer_leds)
    end
end

function handle(data, client)
    if (data.action == "set") then 
        print(string.format("setting leds to: r=%d g=%d b=%d", data.color.r, data.color.g, data.color.b))
        setColor(data.color, function()
            client:send("OK")
        end)
        return
    end
    client:send("UNKNOWN COMMAND")
end


srv=net.createServer(net.TCP)
srv:listen(LEDS_SERVER,function(conn)
    conn:on("receive", function(client,request)
        local body = ""
        local isBody = false
        for line in lines(request) do
           line = trim(line)
           if (line == "" and not isBody) then 
            isBody = true 
           end
           if (isBody) then
            body = body .. line
           end
        end

        local result, data = pcall(cjson.decode,body)
        if (not result) then
            client:send("ERROR WHILE PARSING JSON")
            return
        end

        local result, error = pcall(handle, data, client)
        if (not result) then
            client:send("ERROR WHILE HANDLING REQUEST")
            return
        end        
    end)
    conn:on("sent", function (c) c:close() end)
end)
