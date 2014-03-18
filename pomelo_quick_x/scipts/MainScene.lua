local M = class("MainScene", function()
    return display.newScene("MainScene")
end)

function M:ctor()
  local __luaSocketLabel = ui.newTTFLabelMenuItem({
    text = "pomelo init",
    size = 32,
    x = display.cx,
    y = display.top - 128,
    listener = handler(self, self.onInitClicked),
  })

  local __luaSocketSendLabel = ui.newTTFLabelMenuItem({
    text = "pomelo request",
    size = 32,
    x = display.cx,
    y = display.top - 160,
    listener = handler(self, self.onRequestClicked),
  })

  self:addChild(ui.newMenu({__luaSocketLabel, __luaSocketSendLabel}))

end

function M:onInitClicked()
    game.pomelo:init({host="your host",port="your port"}, -- !!!! replace with your *host* and *port*  !!!!
        function() 
        -- do something
        end
    )
end

function M:onRequestClicked()
    local route = 'your route'   -- !!!! replace with your *route* !!!!
    game.pomelo:request(route,{},
        function(response)
            -- do somegthing
        end
    )
end

-- pomelo call back
function M:onGameStart()
    echoInfo("onGameStart")
end

function M:onEnter()
    -- just example....
    game.pomelo:on("onGameStart",handler(self,self.onGameStart))
--    game.pomelo:on("onGameOtherThing",handler(self,self.onGameOtherThing))
end

return M