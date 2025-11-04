-- KnotAgain!
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs = ipairs
local table_insert = table.insert
local math_floor = math.floor
local math_max = math.max
local math_sqrt = math.sqrt
local math_min = math.min

local lg = love.graphics

local RopeUntangler = {}
RopeUntangler.__index = RopeUntangler

local function crossProduct(ax, ay, bx, by) return ax * by - ay * bx end

local function segmentsIntersect(x1, y1, x2, y2, x3, y3, x4, y4)
    local r_x, r_y = x2 - x1, y2 - y1
    local s_x, s_y = x4 - x3, y4 - y3

    local cross_r_s = crossProduct(r_x, r_y, s_x, s_y)
    if cross_r_s == 0 then return false end

    local t = crossProduct(x3 - x1, y3 - y1, s_x, s_y) / cross_r_s
    local u = crossProduct(x3 - x1, y3 - y1, r_x, r_y) / cross_r_s

    return t >= 0 and t <= 1 and u >= 0 and u <= 1
end

local function distance(x1, y1, x2, y2) return math_sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) end


local function createRopeSegments(self, x1, y1, x2, y2)
    local segments = {}
    local dist = distance(x1, y1, x2, y2)
    local numSegments = math_max(3, math_floor(dist / self.ropeSegLength))

    for i = 0, numSegments do
        local t = i / numSegments
        local x = x1 + (x2 - x1) * t
        local y = y1 + (y2 - y1) * t
        table_insert(segments, {
            x = x,
            y = y,
            oldX = x,
            oldY = y,
            radius = self.ropeRadius
        })
    end

    return segments
end

local function resolveRopeCollisions(self)
    local iterations = 3

    for _ = 1, iterations do
        for i = 1, #self.ropes do
            local rope1 = self.ropes[i]
            for j = i + 1, #self.ropes do
                local rope2 = self.ropes[j]

                for k = 1, #rope1.segments - 1 do
                    local seg1a = rope1.segments[k]
                    local seg1b = rope1.segments[k + 1]

                    for l = 1, #rope2.segments - 1 do
                        local seg2a = rope2.segments[l]
                        local seg2b = rope2.segments[l + 1]

                        -- Check if segments intersect
                        if segmentsIntersect(
                            seg1a.x, seg1a.y, seg1b.x, seg1b.y,
                            seg2a.x, seg2a.y, seg2b.x, seg2b.y
                        ) then
                            -- Find intersection point using line-line intersection
                            local x1, y1, x2, y2 = seg1a.x, seg1a.y, seg1b.x, seg1b.y
                            local x3, y3, x4, y4 = seg2a.x, seg2a.y, seg2b.x, seg2b.y

                            local den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
                            if den == 0 then goto continue end

                            local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
                            local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den

                            if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
                                -- Push segments away from each other
                                local pushForce = 2.0
                                local dx = (seg2a.x + seg2b.x) * 0.5 - (seg1a.x + seg1b.x) * 0.5
                                local dy = (seg2a.y + seg2b.y) * 0.5 - (seg1a.y + seg1b.y) * 0.5
                                local dist = math_sqrt(dx * dx + dy * dy)

                                if dist > 0 then
                                    dx, dy = dx / dist, dy / dist

                                    -- Apply push to rope1 segments (avoid moving pinned ends)
                                    if k > 1 then
                                        seg1a.x = seg1a.x - dx * pushForce * 0.5
                                        seg1a.y = seg1a.y - dy * pushForce * 0.5
                                    end
                                    if k < #rope1.segments - 1 then
                                        seg1b.x = seg1b.x - dx * pushForce * 0.5
                                        seg1b.y = seg1b.y - dy * pushForce * 0.5
                                    end

                                    -- Apply push to rope2 segments (avoid moving pinned ends)
                                    if l > 1 then
                                        seg2a.x = seg2a.x + dx * pushForce * 0.5
                                        seg2a.y = seg2a.y + dy * pushForce * 0.5
                                    end
                                    if l < #rope2.segments - 1 then
                                        seg2b.x = seg2b.x + dx * pushForce * 0.5
                                        seg2b.y = seg2b.y + dy * pushForce * 0.5
                                    end
                                end
                            end
                        end

                        ::continue::
                    end
                end
            end
        end
    end
end

local function updateRopePhysics(self)
    for _, rope in ipairs(self.ropes) do
        local node1 = self.nodes[rope.node1]
        local node2 = self.nodes[rope.node2]

        if node1 and node2 then
            -- Update rope segments with verlet integration
            local segments = rope.segments

            -- Pin first and last segments to nodes
            segments[1].x, segments[1].y = node1.x, node1.y
            segments[#segments].x, segments[#segments].y = node2.x, node2.y

            -- Apply constraints
            for i = 1, #segments - 1 do
                local seg1 = segments[i]
                local seg2 = segments[i + 1]

                local dx = seg2.x - seg1.x
                local dy = seg2.y - seg1.y
                local dist = math_sqrt(dx * dx + dy * dy)

                if dist > 0 then
                    local difference = self.ropeSegLength - dist
                    local percent = difference / dist / 2
                    local offsetX = dx * percent
                    local offsetY = dy * percent

                    if i > 1 then -- Don't move first segment (pinned to node1)
                        seg1.x = seg1.x - offsetX
                        seg1.y = seg1.y - offsetY
                    end

                    if i < #segments - 1 then -- Don't move last segment (pinned to node2)
                        seg2.x = seg2.x + offsetX
                        seg2.y = seg2.y + offsetY
                    end
                end
            end
        end
    end

    -- Resolve rope-rope collisions
    resolveRopeCollisions(self)
end

local function updateCrossings(self)
    self.crossings = {}

    for i = 1, #self.ropes do
        for j = i + 1, #self.ropes do
            local rope1 = self.ropes[i]
            local rope2 = self.ropes[j]

            local node1a = self.nodes[rope1.node1]
            local node1b = self.nodes[rope1.node2]
            local node2a = self.nodes[rope2.node1]
            local node2b = self.nodes[rope2.node2]

            if node1a and node1b and node2a and node2b then
                if segmentsIntersect(
                        node1a.x, node1a.y, node1b.x, node1b.y,
                        node2a.x, node2a.y, node2b.x, node2b.y
                    ) then
                    table_insert(self.crossings, {
                        rope1 = i,
                        rope2 = j,
                        x = (node1a.x + node1b.x + node2a.x + node2b.x) / 4,
                        y = (node1a.y + node1b.y + node2a.y + node2b.y) / 4
                    })
                end
            end
        end
    end
end

local function shuffle(t)
    for i = #t, 2, -1 do
        local j = love.math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function generateLevel(self, level)
    self.nodes = {}
    self.ropes = {}
    self.crossings = {}
    self.ropeSegments = {}

    local numRopes = math_min(3 + math_floor(level * 1.5), 12)
    local numNodes = numRopes * 2

    local margin = 80
    local playAreaWidth = self.screenWidth - margin * 2
    local playAreaHeight = self.screenHeight - margin * 2 - 100

    -- Create nodes more evenly scattered across a wider play area
    local centerX = self.screenWidth / 2
    local centerY = (self.screenHeight - 100) / 2
    local maxRadius = math_min(playAreaWidth, playAreaHeight) / 1.8
    local minRadius = maxRadius * 0.5

    for i = 1, numNodes do
        local angle = love.math.random() * math.pi * 2
        local r = love.math.random(minRadius, maxRadius)
        local x = centerX + math.cos(angle) * r + love.math.random(-60, 60)
        local y = centerY + math.sin(angle) * r + love.math.random(-60, 60)

        -- Clamp within screen bounds
        x = math_max(margin, math_min(self.screenWidth - margin, x))
        y = math_max(margin, math_min(self.screenHeight - margin - 100, y))

        table_insert(self.nodes, {
            id = i,
            x = x,
            y = y,
            radius = 12,
            color = { 0.8, 0.8, 0.9 },
            fixed = false
        })
    end

    -- Randomize node pairing so ropes cross and overlap
    local nodeIndices = {}
    for i = 1, numNodes do
        table_insert(nodeIndices, i)
    end
    nodeIndices = shuffle(nodeIndices)

    -- Create ropes between random node pairs
    for i = 1, numRopes do
        local node1 = self.nodes[nodeIndices[i * 2 - 1]]
        local node2 = self.nodes[nodeIndices[i * 2]]

        if node1 and node2 then
            table_insert(self.ropes, {
                node1 = node1.id,
                node2 = node2.id,
                color = {
                    love.math.random(0.6, 0.9),
                    love.math.random(0.6, 0.9),
                    love.math.random(0.6, 0.9)
                },
                segments = createRopeSegments(self, node1.x, node1.y, node2.x, node2.y)
            })
        end
    end

    -- Randomly fix a few nodes (for challenge)
    local numFixed = math_min(math_floor(level / 3), math_floor(numNodes / 3))
    for _ = 1, numFixed do
        local node = self.nodes[love.math.random(1, #self.nodes)]
        if not node.fixed then
            node.fixed = true
            node.color = { 0.5, 0.5, 0.7 }
        end
    end

    -- Add a slight "tangle shake" to intensify crossings
    for _, node in ipairs(self.nodes) do
        node.x = node.x + love.math.random(-40, 40)
        node.y = node.y + love.math.random(-40, 40)
    end

    updateCrossings(self)
    updateRopePhysics(self)
end

local function drawWinScreen(self)
    -- Semi-transparent overlay
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Win message
    lg.setColor(0.2, 0.8, 0.2)
    lg.setFont(self.fonts.title)
    lg.printf("LEVEL COMPLETE!", 0, self.screenHeight / 2 - 100, self.screenWidth, "center")

    lg.setColor(1, 1, 1)
    lg.setFont(self.fonts.medium)
    lg.printf("Score: +" .. (self.level * 100), 0, self.screenHeight / 2 - 30, self.screenWidth, "center")
    lg.printf("Press N for next level or click to continue", 0, self.screenHeight / 2 + 20, self.screenWidth, "center")
end

local function drawUI(self)
    -- Draw level info
    lg.setColor(1, 1, 1, 0.9)
    lg.setFont(self.fonts.medium)
    lg.print("Level: " .. self.level, 20, 20)
    lg.print("Score: " .. self.score, 20, 50)
    lg.print("Crossings: " .. #self.crossings, 20, 80)

    -- Draw instructions
    lg.setFont(self.fonts.small)
    lg.print("Drag nodes to untangle ropes", self.screenWidth - 275, 20)
    lg.print("Fixed nodes (X) cannot be moved", self.screenWidth - 275, 45)
    lg.print("Press R to restart level", self.screenWidth - 275, 70)
    lg.print("Press ESC for menu", self.screenWidth - 275, 95)
end

local function completeLevel(self)
    self.won = true
    self.score = self.score + self.level * 100
end

local function nextLevel(self)
    self.level = self.level + 1
    self.won = false
    generateLevel(self, self.level)
end

local function checkWinCondition(self) return #self.crossings == 0 end

function RopeUntangler.new()
    local instance = setmetatable({}, RopeUntangler)

    instance.screenWidth = 1000
    instance.screenHeight = 700
    instance.level = 1
    instance.score = 0
    instance.gameOver = false
    instance.won = false

    instance.nodes = {}
    instance.ropes = {}
    instance.crossings = {}
    instance.selectedNode = nil
    instance.dragging = false

    instance.ropeSegments = {}
    instance.ropeSegLength = 8
    instance.ropeRadius = 2 -- Added for collision detection

    instance.fonts = {
        small = lg.newFont(16),
        medium = lg.newFont(24),
        large = lg.newFont(36),
        title = lg.newFont(48)
    }

    return instance
end

function RopeUntangler:setScreenSize(width, height)
    self.screenWidth = width
    self.screenHeight = height
end

function RopeUntangler:handleClick(x, y)
    if self.gameOver then return end

    -- Check if clicking on a node
    for _, node in ipairs(self.nodes) do
        if not node.fixed and distance(x, y, node.x, node.y) <= node.radius then
            self.selectedNode = node
            self.dragging = true
            return
        end
    end
end

function RopeUntangler:handleMouseMove(x, y, dx, dy)
    if self.dragging and self.selectedNode then
        self.selectedNode.x = x
        self.selectedNode.y = y

        -- Keep within bounds
        local margin = 50
        self.selectedNode.x = math_max(margin, math_min(self.screenWidth - margin, self.selectedNode.x))
        self.selectedNode.y = math_max(margin, math_min(self.screenHeight - margin - 100, self.selectedNode.y))

        updateRopePhysics(self)
        updateCrossings(self)

        if checkWinCondition(self) then completeLevel(self) end
    end
end

function RopeUntangler:handleMouseRelease(x, y)
    self.dragging = false
    self.selectedNode = nil
end

function RopeUntangler:handleKeypress(key)
    if key == "r" then
        generateLevel(self, self.level)
    elseif key == "n" and self.won then
        nextLevel(self)
    end
end

function RopeUntangler:update(dt)
    updateRopePhysics(self)
end

function RopeUntangler:draw()
    -- Draw ropes with physics segments
    for _, rope in ipairs(self.ropes) do
        local segments = rope.segments

        -- Draw rope segments
        lg.setColor(rope.color[1] * 0.7, rope.color[2] * 0.7, rope.color[3] * 0.7, 1)
        lg.setLineWidth(3)

        for i = 1, #segments - 1 do
            lg.line(segments[i].x, segments[i].y, segments[i + 1].x, segments[i + 1].y)
        end

        lg.setLineWidth(1)
    end

    -- Draw rope crossings
    for _, crossing in ipairs(self.crossings) do
        lg.setColor(1, 0.2, 0.2, 0.8)
        lg.circle("fill", crossing.x, crossing.y, 6)
        lg.setColor(1, 1, 1, 1)
        lg.circle("line", crossing.x, crossing.y, 6)
    end

    -- Draw nodes
    for _, node in ipairs(self.nodes) do
        if node.fixed then
            lg.setColor(0.5, 0.5, 0.7)
            lg.circle("fill", node.x, node.y, node.radius)
            lg.setColor(1, 1, 1)
            lg.circle("line", node.x, node.y, node.radius)

            -- Draw cross for fixed nodes
            lg.setLineWidth(2)
            lg.line(node.x - 8, node.y - 8, node.x + 8, node.y + 8)
            lg.line(node.x + 8, node.y - 8, node.x - 8, node.y + 8)
            lg.setLineWidth(1)
        else
            lg.setColor(node.color[1], node.color[2], node.color[3])
            lg.circle("fill", node.x, node.y, node.radius)
            lg.setColor(1, 1, 1)
            lg.circle("line", node.x, node.y, node.radius)

            -- Highlight selected node
            if self.selectedNode == node then
                lg.setColor(1, 1, 0, 0.5)
                lg.circle("fill", node.x, node.y, node.radius + 4)
            end
        end
    end

    -- Draw UI
    drawUI(self)

    -- Draw win screen
    if self.won then drawWinScreen(self) end
end

function RopeUntangler:startNewGame(difficulty, category)
    self.level = 1
    self.score = 0
    self.gameOver = false
    self.won = false
    generateLevel(self, self.level)
end

function RopeUntangler:isGameOver() return self.gameOver end

return RopeUntangler