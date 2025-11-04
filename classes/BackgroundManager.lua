-- KnotAgain!
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs = ipairs
local math_sin = math.sin
local math_random = math.random
local table_insert = table.insert
local lg = love.graphics

local BackgroundManager = {}
BackgroundManager.__index = BackgroundManager

local function initFloatingRopes(self)
    self.floatingRopes = {}
    local ropeCount = 15

    for _ = 1, ropeCount do
        local startX = math_random() * 1200
        local startY = math_random() * 1200
        local endX = startX + math_random(-200, 200)
        local endY = startY + math_random(-200, 200)

        table_insert(self.floatingRopes, {
            startX = startX,
            startY = startY,
            endX = endX,
            endY = endY,
            segments = {},
            color = {
                math_random(0.6, 0.8),
                math_random(0.6, 0.8),
                math_random(0.7, 0.9)
            },
            speedX = math_random(-10, 10),
            speedY = math_random(-10, 10),
            pulseSpeed = math_random(0.5, 2),
            alpha = math_random(0.1, 0.3)
        })
    end

    -- Initialize segments for all ropes
    for _, rope in ipairs(self.floatingRopes) do
        rope.segments = self:createRopeSegments(rope.startX, rope.startY, rope.endX, rope.endY, 12)
    end
end

function BackgroundManager:createRopeSegments(x1, y1, x2, y2, segmentCount)
    local segments = {}
    for i = 0, segmentCount do
        local t = i / segmentCount
        local x = x1 + (x2 - x1) * t
        local y = y1 + (y2 - y1) * t
        table_insert(segments, { x = x, y = y })
    end
    return segments
end

local function initFloatingNodes(self)
    self.floatingNodes = {}
    local nodeCount = 25

    for _ = 1, nodeCount do
        table_insert(self.floatingNodes, {
            x = math_random() * 1200,
            y = math_random() * 1200,
            radius = math_random(4, 10),
            speedX = math_random(-15, 15),
            speedY = math_random(-15, 15),
            pulseSpeed = math_random(1, 3),
            alpha = math_random(0.2, 0.5),
            color = {
                math_random(0.7, 0.9),
                math_random(0.7, 0.9),
                math_random(0.8, 1.0)
            }
        })
    end
end

function BackgroundManager.new()
    local instance = setmetatable({}, BackgroundManager)
    instance.floatingRopes = {}
    instance.floatingNodes = {}
    instance.time = 0
    instance.pulseValue = 0

    initFloatingRopes(instance)
    initFloatingNodes(instance)

    return instance
end

function BackgroundManager:update(dt)
    self.time = self.time + dt
    self.pulseValue = math_sin(self.time * 2) * 0.5 + 0.5

    -- Update floating ropes
    for _, rope in ipairs(self.floatingRopes) do
        rope.startX = rope.startX + rope.speedX * dt
        rope.startY = rope.startY + rope.speedY * dt
        rope.endX = rope.endX + rope.speedX * dt
        rope.endY = rope.endY + rope.speedY * dt

        -- Update segments with simple wave motion
        for i, segment in ipairs(rope.segments) do
            local t = (i - 1) / (#rope.segments - 1)
            local wave = math_sin(self.time * rope.pulseSpeed + i * 0.5) * 3
            segment.x = rope.startX + (rope.endX - rope.startX) * t
            segment.y = rope.startY + (rope.endY - rope.startY) * t + wave
        end

        -- Wrap around screen edges
        if rope.startX < -200 then rope.startX = 1400 end
        if rope.startX > 1400 then rope.startX = -200 end
        if rope.startY < -200 then rope.startY = 1400 end
        if rope.startY > 1400 then rope.startY = -200 end
        if rope.endX < -200 then rope.endX = 1400 end
        if rope.endX > 1400 then rope.endX = -200 end
        if rope.endY < -200 then rope.endY = 1400 end
        if rope.endY > 1400 then rope.endY = -200 end
    end

    -- Update floating nodes
    for _, node in ipairs(self.floatingNodes) do
        node.x = node.x + node.speedX * dt
        node.y = node.y + node.speedY * dt

        -- Wrap around screen edges
        if node.x < -50 then node.x = 1250 end
        if node.x > 1250 then node.x = -50 end
        if node.y < -50 then node.y = 1250 end
        if node.y > 1250 then node.y = -50 end
    end
end

function BackgroundManager:drawMenuBackground(screenWidth, screenHeight, time)
    -- Gradient background with pulsing effect
    for y = 0, screenHeight, 2 do
        local progress = y / screenHeight
        local pulse = (math_sin(time * 2 + progress * 4) + 1) * 0.1
        local wave = math_sin(progress * 8 + time * 3) * 0.05

        local r = 0.1 + progress * 0.2 + pulse + wave
        local g = 0.15 + progress * 0.15 + pulse
        local b = 0.25 + progress * 0.3 + pulse

        lg.setColor(r, g, b, 0.8)
        lg.rectangle("fill", 0, y, screenWidth, 2)
    end

    -- Draw floating ropes
    for _, rope in ipairs(self.floatingRopes) do
        local pulseAlpha = rope.alpha * (0.7 + math_sin(time * rope.pulseSpeed) * 0.3)

        lg.setColor(rope.color[1], rope.color[2], rope.color[3], pulseAlpha)
        lg.setLineWidth(2)

        -- Draw rope segments
        for i = 1, #rope.segments - 1 do
            lg.line(rope.segments[i].x, rope.segments[i].y, rope.segments[i + 1].x, rope.segments[i + 1].y)
        end

        lg.setLineWidth(1)
    end

    -- Draw floating nodes
    for _, node in ipairs(self.floatingNodes) do
        local pulse = math_sin(time * node.pulseSpeed) * 0.3 + 0.7
        local currentAlpha = node.alpha * pulse

        lg.setColor(node.color[1], node.color[2], node.color[3], currentAlpha)
        lg.circle("fill", node.x, node.y, node.radius)
        lg.setColor(1, 1, 1, currentAlpha * 0.5)
        lg.circle("line", node.x, node.y, node.radius)
    end

    -- Central rope knot design
    lg.setColor(0.4, 0.6, 0.8, 0.15 + self.pulseValue * 0.1)
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2 - 5

    -- Draw a stylized rope knot
    lg.setLineWidth(6)
    lg.circle("line", centerX, centerY, 80)
    lg.circle("line", centerX, centerY, 50)

    -- Cross lines through the knot
    lg.line(centerX - 80, centerY, centerX + 80, centerY)
    lg.line(centerX, centerY - 80, centerX, centerY + 80)

    lg.setLineWidth(1)
end

function BackgroundManager:drawGameBackground(screenWidth, screenHeight, time)
    -- Dark, atmospheric gradient for gameplay
    for y = 0, screenHeight, 1.5 do
        local progress = y / screenHeight
        local wave = math_sin(progress * 12 + time * 0.8) * 0.03
        local pulse = math_sin(progress * 6 + time) * 0.02

        local r = 0.05 + wave + pulse
        local g = 0.08 + progress * 0.06 + wave
        local b = 0.12 + progress * 0.1 + pulse

        lg.setColor(r, g, b, 0.9)
        lg.rectangle("fill", 0, y, screenWidth, 1.5)
    end

    -- Draw subtle grid pattern
    lg.setColor(0.15, 0.25, 0.35, 0.08)
    local gridSize = 60
    local offset = math_sin(time * 0.3) * 5

    for x = -offset, screenWidth + offset, gridSize do
        for y = -offset, screenHeight + offset, gridSize do
            lg.push()
            lg.translate(x, y)

            -- Draw grid dots
            lg.circle("fill", 0, 0, 1.5)

            lg.pop()
        end
    end

    -- Draw very subtle floating ropes in background
    for _, rope in ipairs(self.floatingRopes) do
        local pulseAlpha = rope.alpha * 0.3 * (0.5 + math_sin(time * rope.pulseSpeed) * 0.5)

        lg.setColor(rope.color[1], rope.color[2], rope.color[3], pulseAlpha)
        lg.setLineWidth(1)

        -- Draw only every other segment for performance
        for i = 1, #rope.segments - 1, 2 do
            lg.line(rope.segments[i].x, rope.segments[i].y, rope.segments[i + 1].x, rope.segments[i + 1].y)
        end

        lg.setLineWidth(1)
    end
end

return BackgroundManager
