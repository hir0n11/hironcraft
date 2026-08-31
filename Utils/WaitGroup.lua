local HironCraftScan = select(2, ...)

HironCraftScan.WaitGroup = HironCraftScan.Object:extend()

function HironCraftScan.WaitGroup:new(onFinish)
    self.counter = 0
    self.onFinish = onFinish
    self.isClosed = false
end

function HironCraftScan.WaitGroup:Add()
    self.counter = self.counter + 1
end

function HironCraftScan.WaitGroup:Done()
    self.counter = self.counter - 1
    self:Check()
end

-- Call this when you are done adding new tasks
function HironCraftScan.WaitGroup:Close()
    self.isClosed = true
    self:Check()
end

function HironCraftScan.WaitGroup:Check()
    if self.isClosed and self.counter <= 0 then
        if self.onFinish then
            self.onFinish()
        end
    end
end
