--local Protobuf = require("Protobuf") -- 暂时还不支持protobuf，如有可能，请加上并告知。谢谢。
local scheduler = require("framework.scheduler")

local Protocol = require("pomelo.Protocol")
local Package = require("pomelo.Package")
local Message = require("pomelo.Message")
local Emitter = require("pomelo.Emitter")

local RES_OK = 200
local RES_FAIL = 500
local RES_OLD_CLIENT = 501

local LUA_WS_CLIENT_TYPE = 'lua-websocket'
local LUA_WS_CLIENT_VERSION = '0.0.1'

-- 继承Emitter
local Pomelo = class("Pomelo",function()
    return Emitter.new()
end)

function Pomelo:ctor()
    self.socket = nil
    self.reqId = 1
    --Map from request id to route
    self.routeMap = {}
    
    self.heartbeatInterval = 0
    self.heartbeatTimeout = 0
    self.nextHeartbeatTimeout = 0
    self.gapThreshold = 1       -- heartbeat gap threashold
    self.heartbeatId = nil
    self.heartbeatTimeoutId = nil

    self.handshakeBuffer = {
        sys = {
            type = LUA_WS_CLIENT_TYPE,
            version = LUA_WS_CLIENT_VERSION
        },
        user= {}
    }
    
    self.handlers = {}
    self.handlers[Package.TYPE_HANDSHAKE] = handler(self,self._handshake)
    self.handlers[Package.TYPE_HEARTBEAT] = handler(self,self.heartbeat)
    self.handlers[Package.TYPE_DATA] = handler(self,self._onData)
    self.handlers[Package.TYPE_KICK] = handler(self,self._onKick)

end

function Pomelo:init(params,cb)
    self.initCallback = cb
    
    local host = params.host
    local port = params.port

    local url = 'ws://' .. host
    if port then
        url = url .. ':' .. port
    end

    self.handshakeBuffer.user = params.user
    self.handshakeCallback = params.handshakeCallback
    
    self:_initWebSocket(url,cb)
end

function Pomelo:request(route,msg,cb) 
    if not route then 
        return
    end
    
    if not self:_isReady() then
        printError("Pomelo:request() - socket not ready")
        return
    end 
    
    self.reqId = self.reqId + 1
    self:_sendMessage(self.reqId,route,msg)
    
    self._callbacks[self.reqId] = cb
    self.routeMap[self.reqId] = route
end

function Pomelo:notify(route,msg) 
    if not self:_isReady() then
        printError("WebSockets:_send() - socket not ready")
        return
    end 
    
    local msg = msg or {}
    self:_sendMessage(0,route,msg)
end 

function Pomelo:disconnect() 
--    printf("Pomelo:disconnect()")
    if self.socket and self.socket:getReadyState() == kStateOpen then
        self.socket:close()
        self.socket = nil
    end       

    if self.heartbeatId then
        self:_clearTimeout(self.heartbeatId)
        self.heartbeatId = nil
    end
    
    if self.heartbeatTimeoutId then
        self:_clearTimeout(self.heartbeatTimeoutId)
        self.heartbeatTimeoutId = nil
    end
    
    self:removeAllListener()
end

function Pomelo:_initWebSocket(url,cb) 
    local onopen = function(event) 
        local obj = Package.encode(Package.TYPE_HANDSHAKE,Protocol.strencode(json.encode(self.handshakeBuffer)))
        self:_send(obj)
    end

    local onmessage = function(message)
        self:_processPackage(Package.decode(message),cb)
        -- new package arrived,update the heartbeat timeout
        if self.heartbeatTimeout~=0 then
            self.nextHeartbeatTimeout = os.time() + self.heartbeatTimeout
        end
    end

    local onerror = function(event) 
        self:emit('io-error',event)
    end

    local onclose = function(event)
        self:emit('close',event)
    end

    self.socket = cc.WebSocket:create(url)
    
    self.socket:registerScriptHandler(onopen,cc.WEBSOCKET_OPEN)
    self.socket:registerScriptHandler(onmessage,cc.WEBSOCKET_MESSAGE)
    self.socket:registerScriptHandler(onclose,cc.WEBSOCKET_CLOSE)
    self.socket:registerScriptHandler(onerror,cc.WEBSOCKET_ERROR)
    
end

function Pomelo:_processPackage(msg)
    self.handlers[msg.type](msg.body)
end
    
function Pomelo:_processMessage(msg) 
    if msg.id==0 then
        -- server push message
        self:emit(msg.route,msg.body)
    end

    --if have a id then find the callback function with the request
    local cb = self._callbacks[msg.id]
    self._callbacks[msg.id] = nil
    if type(cb) ~= 'function' then
        return
    end
    
    cb(msg.body)
end

function Pomelo:_processMessageBatch(msgs) 
    for i=1,#msgs do
        self:_processMessage(pomelo,msgs[i])
    end
end

function Pomelo:_isReady()
    return self.socket and self.socket:getReadyState() == cc.WEBSOCKET_STATE_OPEN
end

function Pomelo:_sendMessage(reqId,route,msg)
--    printf("Pomelo:_sendMessage")
    local _type = Message.TYPE_REQUEST
    if reqId == 0 then
        _type = Message.TYPE_NOTIFY
    end

    --compress message by Protobuf
    -- TODO 暂时不支持 Protobuf
    local protos = {}
    if self.data.protos then
       protos = self.data.protos.client
    end
    
    if protos[route] then
        msg = Protobuf.encode(route,msg)
    else 
        msg = Protocol.strencode(json.encode(msg))
    end
    
    local compressRoute = 0
    if self.dict and self.dict[route] then
        route = self.dict[route]
        compressRoute = 1
    end

    msg = Message.encode(reqId,_type,compressRoute,route,msg)
    
    local packet = Package.encode(Package.TYPE_DATA,msg)
    
    self:_send(packet)
end

function Pomelo:_send(packet)
    if self:_isReady() then
        self.socket:sendBinary(packet,table.nums(packet))
    end
end

function Pomelo:heartbeat(data)
--    printf("Pomelo:heartbeat(data)")
     
    if self.heartbeatInterval==0 then
        -- no heartbeat
        return
    end

    if self.heartbeatId~=nil then
        -- already in a heartbeat interval
        return
    end
    
    if self.heartbeatTimeoutId~=nil then
        self:_clearTimeout(self.heartbeatTimeoutId)
        self.heartbeatTimeoutId = nil
    end

    local obj = Package.encode(Package.TYPE_HEARTBEAT)
    self.heartbeatId = self:_setTimeout(
        function() 
            self:_send(obj)
          
--            self.nextHeartbeatTimeout = os.time() + self.heartbeatTimeout
--            self.heartbeatTimeoutId = self:_setTimeout(handler(self,self.heartbeatTimeoutCb),self.heartbeatTimeout)
       
            self:_clearTimeout(self.heartbeatId)
            self.heartbeatId = nil
        end,
        self.heartbeatInterval)
end

function Pomelo:heartbeatTimeoutCb() 
    local gap = self.nextHeartbeatTimeout - os.time()
    if gap > self.gapThreshold then
        self.heartbeatTimeoutId = self:_setTimeout(handler(self,self.heartbeatTimeoutCb),gap)
    else 
        self:emit('heartbeat timeout')
--        printf('heartbeat timeout')
        self:disconnect()
    end
end

function Pomelo:_handshake(data) 
    data = json.decode(Protocol.strdecode(data))
    
    if data.code == RES_OLD_CLIENT then
        self:emit('error','client version not fullfill')
        return
    end

    if data.code ~= RES_OK then
        self:emit('error','_handshake fail')
        return
    end

    self:_handshakeInit(data)

    local obj = Package.encode(Package.TYPE_HANDSHAKE_ACK)
    self:_send(obj)
    
    if self.initCallback then
        self:initCallback(self.socket)
        initCallback = nil
    end
    
end

function Pomelo:_onData(data) 
    local msg = Message.decode(data)
    if msg.id > 0 then
        msg.route = self.routeMap[msg.id]
        self.routeMap[msg.id] = nil
        if not msg.route then
            return
        end
    end
    msg.body = self:_deCompose(msg)
    self:_processMessage(msg)
end

function Pomelo:_onKick(data) 
    self:emit('onKick')
end
        
function Pomelo:_deCompose(msg) 
  local protos = {}
  if self.data.protos then
    protos = self.data.protos.server
  end
  
  local abbrs = self.data.abbrs
  local route = msg.route

  --Decompose route from dict
  if msg.compressRoute~=0 then
    if not abbrs[route] then
        return {}
    end
    msg.route = abbrs[route]
    route = msg.route
  end
  
  if protos[route] then
      return Protobuf.decode(route,msg.body)
  else 
      return json.decode(Protocol.strdecode(msg.body))
  end

  return msg
end

function Pomelo:_handshakeInit(data) 
--    printf("Pomelo:_handshakeInit(data=)",json.encode(data))
    if data.sys and data.sys.heartbeat then
        self.heartbeatInterval = data.sys.heartbeat         -- heartbeat interval
        self.heartbeatTimeout = self.heartbeatInterval * 2  -- max heartbeat timeout
    else 
        self.heartbeatInterval = 0
        self.heartbeatTimeout = 0
    end

    self:_initData(data)

    if type(self.handshakeCallback) == 'function' then
        self:handshakeCallback(data.user)
    end
  
end

--Initilize data used in pomelo client
function Pomelo:_initData(data) 
    if not data or not data.sys then
        return
    end
    
    self.data = self.data or {}
    local dict = data.sys.dict
    local protos = data.sys.protos

    --Init compress dict
    if dict then
        self.data.dict = dict
        self.data.abbrs = {}
        for k,v in ipairs(dict) do
            self.data.abbrs[dict[k]] = k
        end
    end
    
--    --Init Protobuf protos
--    if protos then
--        self.data.protos = {
--            server = protos.server or {},
--            client = protos.client or {}
--         }
--        if Protobuf then
--            Protobuf.init({
--               encoderProtosprotos=client,
--                decoderProtos=protos.server
--            })
--        end
--    end

end

function Pomelo:_setTimeout(fn,delay)
    scheduler.performWithDelayGlobal(fn,delay)
end

function Pomelo:_clearTimeout(fn)
    if fn and fn ~= 0 then
        scheduler.unscheduleGlobal(fn)
    end
end

return Pomelo
