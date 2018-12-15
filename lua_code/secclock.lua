n=require("ntp")

dofile("config.lua")

local tmr_alarm, tmr_unregister, tmr_ALARM_SINGLE, tmr_ALARM_AUTO, tmr_create, tmr_now = tmr.alarm, tmr.unregister, tmr.ALARM_SINGLE, tmr.ALARM_AUTO, tmr.create, tmr.now
local string_find, string_gmatch, string_format, string_sub, string_gsub = string.find, string.gmatch, string.format, string.sub, string.gsub
local gpio_mode, gpio_serout, gpio_write, gpio_HIGH, gpio_LOW, gpio_OUTPUT, gpio_INT, gpio_PULLUP = gpio.mode, gpio.serout, gpio.write, gpio.HIGH, gpio.LOW, gpio.OUTPUT, gpio.INT, gpio.PULLUP
local pwm_setup, pwm_setduty, pwm_start, pwm_stop = pwm.setup, pwm.setduty, pwm.start, pwm.stop

--display == (19*60+15) * 60

local state = true
local tmr_sync = tmr_create()
local tmr_adjust = tmr_create()
local tmr_zero = tmr_create()

-- based on: https://www.instructables.com/id/Motorize-IoT-With-ESP8266/
gpio_mode(DIRA, gpio_OUTPUT)
gpio_write(DIRA, gpio_LOW)
gpio_mode(LEDZ, gpio_OUTPUT)
gpio_write(LEDZ, gpio_LOW)
gpio_write(PWMA, gpio_OUTPUT)
gpio_write(PWMA, gpio_LOW)
-- gpio_mode(PWMA, gpio_INT, gpio_PULLUP)
pwm_setup(PWMA, 1000, 1023)
pwm_setduty(PWMA, 0)
pwm_start(PWMA)

local function display_s()
  local minute = display / 60
  local hour = minute / 60
  minute = minute % 60
  return string_format("%02d:%02d", hour, minute)
end

local last_step = 0
function step()
  local now = tmr_now()
  local dif = now - last_step
  dif = ( (dif < 0) and ((dif + 0x7FFFFFFE) + 1) or dif) /1000 -- workaround for #1691
  if dif < (IMPULSE + DELAY) then return end

  -- local pin = state and PIN1 or PIN2
  state = not state
  direction = state and gpio_HIGH or gpio_LOW
  display = (display + 60) % 86400
  print(string_format("display shows %s, signal direction %d (free mem: %d)", display_s(), direction, node.heap()))
  --gpio_serout(pin, gpio_HIGH, {IMPULSE*1000, DELAY*1000}, 1, 1)
  -- gpio_write(pin, gpio_HIGH)
  gpio_write(DIRA, direction)
  gpio_write(LEDZ, direction)
  -- gpio_write(PWMA, gpio_HIGH)
  pwm_setduty(PWMA, 1023)
  -- tmr_alarm(tmr_zero, IMPULSE, tmr_ALARM_SINGLE, function() return gpio_write(PWMA, gpio_LOW) end)
  tmr_alarm(tmr_zero, IMPULSE, tmr_ALARM_SINGLE, function() return pwm_setduty(PWMA, 0) end)
  last_step = now
end

function adjust()
  local nowdate = n:time()
  local now = nowdate % 86400
  local dif = (now - display) / 60 -- difference in minutes
  if dif < -10 then dif = dif + 1440 end

  print(string_format("display shows %s, time is %s, %d minutes difference (free mem: %d)", display_s(), n:format(nowdate), dif, node.heap()))
  if dif > 0 then
    step()
    dif = dif - 1
    if dif > 0 then
      tmr_alarm(tmr_adjust, IMPULSE + DELAY, tmr_ALARM_SINGLE, adjust)
    end
  end
end

local cronent
function timeSync()
    n:syncdns(function ()
      if not display then display = ((n:time() % 86400) / 60) * 60 end
      if not cronent then cronent = cron.schedule("* * * * *", adjust) end
      return tmr_alarm(tmr_sync, 90*60*1000, tmr_ALARM_AUTO, timeSync) 
    end, function() 
      return tmr_alarm(tmr_sync, 10*1000, tmr_ALARM_SINGLE, timeSync) 
    end)
end

timeSync()

srv=net.createServer(net.TCP)
srv:listen(CLOCK_SERVER,function(conn)
  conn:on("receive", function(client, request)
    local _, _, method, path, vars = string_find(request, "([A-Z]+) (.+)?(.+) HTTP")
    if(method == nil)then
        _, _, method, path = string_find(request, "([A-Z]+) (.+) HTTP")
    end
    print("request: ", method, path, vars)
    path = string_sub(path, 2) -- remove first char, i.e. "/"
    local index = (path == "")
    path = index and "index.html" or path
    local fd = file.open(path, "r")
    if not fd then 
        client:send("HTTP/1.0 404 Not Found\r\n\r\n404 Not Found\r\n") 
        return
    end
    if index then
      local _GET = {}
      if (vars ~= nil)then
          for k, v in string_gmatch(vars, "(%w+)=([%w%%]+)&*") do
            _GET[k] = v
          end
      end
      local _GET_time = _GET.time
      _GET = nil
      if(_GET_time) then
        local _, _, hour, minute = string_find(_GET_time, "([0-9]+)%%3A([0-9]+)")
        print(string_format("set time to: %02d:%02d", hour, minute))
        display = hour*3600+minute*60
        adjust()
      end

      local line, content = "", ""
      while line do
          line = string_gsub(line, "$TIME", display_s())
          content = content .. line
          line = fd:readline()
      end
      fd:close()
      if content then 
        client:send(content, function (c) 
          c:close() 
          c:on("sent", nil)
        end) 
      end
    else
      local function sendfile()
        local line=fd:read(1024)
        if line then
          client:send(line, sendfile)
        else
          fd:close()
          client:close()
          client:on("sent", nil)
        end
      end
      sendfile()
    end
  end)
end)
