local fn="secclock"
local smph = "semaphore.tmp"

dofile("config.lua")

local tmr_create, tmr_alarm, tmr_ALARM_SINGLE = tmr.create, tmr.alarm, tmr.ALARM_SINGLE

gpio.mode(DIRA, gpio.OUTPUT);
gpio.write(DIRA, gpio.LOW);
gpio.mode(PWMA, gpio.OUTPUT);
gpio.write(PWMA, gpio.LOW);

local function con(t)
  for ssid, _ in pairs(t) do
    if ssid == SSID then
      print("SSID: "..ssid)
      wifi.sta.config({ssid=SSID, pwd=PASSWORD})
      wifi.sta.connect()
      return
    end
  end
  enduser_setup.start();
end

local function disarm()
    print("disarming semaphore")
    file.remove(smph)
end

print("Setting up WIFI...")
wifi.setmode(wifi.STATION)
wifi.setphymode(wifi.PHYMODE_G)
wifi.sta.getap(con, 1)
tmr_alarm(0,1000,1,function() 
  if wifi.sta.getip()== nil then 
    print("IP unavailable...") 
  else 
    tmr.stop(0)
    print("IP: "..wifi.sta.getip())
    print("Starting "..fn.." in 1 seconds")
        tmr_alarm(0, 1000, 0, function() 
            print("telnet")
            require("telnet")
            print("helpers")
            require("helpers")
            print("leds")
            require("leds")
            if not file.exists(smph) then
                file.open(smph, "w"):close()
                tmr_create():alarm(60000, tmr_ALARM_SINGLE, disarm)
                print(fn)
                require(fn)
            else
              print("semaphore armed - stopping")
              tmr_restart=tmr_create()
              tmr_restart:alarm(600000, tmr_ALARM_SINGLE, function()
                  disarm()
                  node.restart()
              end)
            end
        end)
  end 
end)
