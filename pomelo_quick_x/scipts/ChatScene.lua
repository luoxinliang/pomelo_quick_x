local M = class("MainScene", function()
    return display.newScene("MainScene")
end)

function M:ctor()
  self.username = "user"..math.random(1,10000)
  self.rid = "rid"..math.random(1,1000)
  echoInfo("self.username=%s",self.username)
  echoInfo("self.rid=%s",self.rid)
  
  self:initView()
  self:initNet()
end

function M:initView()
  local loginLabel = ui.newTTFLabelMenuItem({
    text = "login",
    size = 32,
    x = display.cx,
    y = display.top - 128,
    listener = handler(self, self.onLoginClick),
  })

  local sendLabel = ui.newTTFLabelMenuItem({
    text = "send message",
    size = 32,
    x = display.cx,
    y = display.top - 160,
    listener = handler(self, self.onSendMsgClick),
  })

  self:addChild(ui.newMenu({loginLabel, sendLabel}))
end

function M:initNet()
    game.pomelo:on("onChat",handler(self,self.onChat))
    game.pomelo:on("onAdd",handler(self,self.onAdd))
    game.pomelo:on("onLeave",handler(self,self.onLeave))
end

function M:onChat(data)
    echoInfo("onChat")
    echoInfo("%s receive message from:%s,content:%s",data.from,data.target,data.msg)
end

function M:onAdd(data)
    echoInfo("onAdd")
    echoInfo("user-%s login!",json.encode(data.user))
end

function M:onLeave(data)
    echoInfo("onLeave")
    echoInfo("user-%s leave!",json.encode(data.user))
end

function M:onLoginClick()
    self:queryEntry(function(host,port)
        game.pomelo:init({host=host,port=port},
            function()
                local route = "connector.entryHandler.enter"
                game.pomelo:request(route,{username=self.username,rid=self.rid},
                    function(data)
                        if data.error then
                            echoInfo("login fail! error=%s",data.error)
                        else
                            echoInfo("login success!")
                            echoInfo("ddfd data=%s",json.encode(data))
                        end
                    end
                )
            end)
    end)
end

function M:onSendMsgClick()
    local route = 'chat.chatHandler.send'
    game.pomelo:request(route,{rid=self.rid,content="hello!",from=self.username,target="*"},
        function(data)
        end
    )
end

-- query connector
function M:queryEntry(cb) 
    game.pomelo:init({host="127.0.0.1",port="3014"},--自己架设服务器，参考pomelo官方文档的chatofpomelo示例
        function()
            local route = 'gate.gateHandler.queryEntry'
            game.pomelo:request(route,{uid=self.username},
                function(data) 
                    game.pomelo:disconnect()
                    echoInfo("123 data=%s",json.encode(data))
                    if data.error then
                        return
                    end
                    cb(data.host,data.port)
                end)
        end
    )
end

function M:onEnter()

end

return M