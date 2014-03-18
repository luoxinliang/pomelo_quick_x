local Emitter = class("Emitter")

function Emitter:ctor()
  self._callbacks = {}
end

function Emitter:on(event,fn) 
  if not self._callbacks[event] then
    self._callbacks[event] = {}
  end
  table.insert(self._callbacks[event],fn)
end

function Emitter:once(event,fn,args) 
    function on() 
        self:off(event,on)
        fn(args)
    end
    fn._off = on
    self:on(event,on)
    return self
end

function Emitter:removeAllListener()
  self._callbacks = {}
  return self
end

function Emitter:off(event,fn)
  return self:removeListener(event,fn)
end

function Emitter:removeListener(event,fn)
    local callbacks = self._callbacks[event]
    if not callbacks then
      return self
    end
  
    if not fn then
        self._callbacks[event] = nil
        return self
    end
  
    local i = table.indexOf(callbacks,fn._off or fn)
    if i then
        table.remove(callbacks,i)
    end
    
    return self
end

function Emitter:emit(event,args) 
--    echoInfo("Emitter:emit event=%s",event)
    local callbacks = self._callbacks[event]

    if callbacks then
        for i=1,#callbacks do
            callbacks[i](args)
        end
    end 
    
    return self
end

function Emitter:listeners(event) 
    return self._callbacks[event] or {}
end   
 
function Emitter:hasListeners(event) 
    return #self.listeners(event)>0
end
  
return Emitter

