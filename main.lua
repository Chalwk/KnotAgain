-- Knot Again! - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

-- =============================================
-- CONFIG & THEME
-- =============================================
local CONFIG = {
    ropeWidth = 10,
    ropeCore = 6,
    ropeColors = {
        { 0.96, 0.36, 0.36 }, -- Red
        { 0.36, 0.86, 0.36 }, -- Green
        { 0.36, 0.56, 0.96 }, -- Blue
        { 0.96, 0.86, 0.26 }, -- Yellow
        { 0.76, 0.36, 0.96 }, -- Purple
        { 0.26, 0.92, 0.92 }, -- Cyan
        { 0.96, 0.66, 0.36 }, -- Orange
    },

    smoothSpeed = 14,
    snapRadius = 0.35, -- in cell units
    particleTTL = 1.2,
}

local THEME = {
    backgroundTop = { 0.055, 0.06, 0.09 },
    backgroundBottom = { 0.09, 0.12, 0.18 },
    gridDot = { 0.26, 0.28, 0.34, 0.55 },
    uiPanel = { 0, 0, 0, 0.38 },
    panelAccent = { 1, 1, 1, 0.06 },
    highlight = { 1, 1, 1, 0.9 },
    shadow = { 0, 0, 0, 0.45 },
}

-- =============================================
-- GAME STATE
-- =============================================
local gameState = {
    currentLevel = 1,
    draggingPoint = nil,
    draggingRope = nil,
    win = false,
    ropes = {},
    gridWidth = 0,
    gridHeight = 0,
    gridStartX = 0,
    gridStartY = 0,
    cellSize = 60,
    particles = {},
    timeSinceWin = 0,
}

-- local helpers
local lg = love.graphics
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local math_sqrt = math.sqrt
local table_insert = table.insert
local table_sort = table.sort
local ipairs = ipairs

-- =============================================
-- Utilities
-- =============================================
local function lerp(a, b, t)
    return a + (b - a) * (t < 1 and t or 1)
end

local function setRandomSeed()
    love.math.setRandomSeed(math.floor(love.timer.getTime() * 1000) % 999999)
end

local function drawVerticalGradient(x, y, w, h, topCol, bottomCol)
    -- simple vertical gradient by many thin rectangles
    local steps = 40
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local r = lerp(topCol[1], bottomCol[1], t)
        local g = lerp(topCol[2], bottomCol[2], t)
        local b = lerp(topCol[3], bottomCol[3], t)
        lg.setColor(r, g, b)
        lg.rectangle('fill', x, y + (i * h / steps), w, h / steps)
    end
end

-- =============================================
-- Grid math
-- =============================================
local function calculateGridPosition()
    local windowWidth, windowHeight = lg.getDimensions()
    local topMargin = 120
    local sideMargin = 50
    local bottomMargin = 50

    local availableWidth = windowWidth - (sideMargin * 2)
    local availableHeight = windowHeight - (topMargin + bottomMargin)
    local maxCellWidth = availableWidth / gameState.gridWidth
    local maxCellHeight = availableHeight / gameState.gridHeight

    gameState.cellSize = math_min(maxCellWidth, maxCellHeight, 92)
    gameState.cellSize = math_max(gameState.cellSize, 28)

    local totalGridWidth = gameState.gridWidth * gameState.cellSize
    local totalGridHeight = gameState.gridHeight * gameState.cellSize

    gameState.gridStartX = (windowWidth - totalGridWidth) / 2
    gameState.gridStartY = topMargin + (availableHeight - totalGridHeight) / 2
end

local function gridToScreen(gridX, gridY)
    local x = gameState.gridStartX + (gridX - 0.5) * gameState.cellSize
    local y = gameState.gridStartY + (gridY - 0.5) * gameState.cellSize
    return x, y
end

-- ==========================
-- Geometry & intersections
-- ==========================
local function cross(x1, y1, x2, y2) return x1 * y2 - y1 * x2 end

local function segmentsIntersect(a1x, a1y, a2x, a2y, b1x, b1y, b2x, b2y)
    local r_x, r_y = a2x - a1x, a2y - a1y
    local s_x, s_y = b2x - b1x, b2y - b1y
    local d = cross(r_x, r_y, s_x, s_y)
    if math_abs(d) < 0.0001 then return false end
    local t = cross(b1x - a1x, b1y - a1y, s_x, s_y) / d
    local u = cross(b1x - a1x, b1y - a1y, r_x, r_y) / d
    return t >= 0 and t <= 1 and u >= 0 and u <= 1
end

local function checkIntersections()
    for i, rope1 in ipairs(gameState.ropes) do
        for j, rope2 in ipairs(gameState.ropes) do
            if i ~= j then
                for k = 1, #rope1.points - 1 do
                    for l = 1, #rope2.points - 1 do
                        local a1x, a1y = gridToScreen(rope1.points[k].x, rope1.points[k].y)
                        local a2x, a2y = gridToScreen(rope1.points[k + 1].x, rope1.points[k + 1].y)
                        local b1x, b1y = gridToScreen(rope2.points[l].x, rope2.points[l].y)
                        local b2x, b2y = gridToScreen(rope2.points[l + 1].x, rope2.points[l + 1].y)
                        if segmentsIntersect(a1x, a1y, a2x, a2y, b1x, b1y, b2x, b2y) then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function checkWinCondition()
    return not checkIntersections()
end

-- =============================================
-- Level generation (kept core behaviour but cleaned)
-- =============================================
local function generateRopePath(gridSize, startSide)
    local startX, startY
    if startSide == 1 then
        startX, startY = love.math.random(1, gridSize), 1
    elseif startSide == 2 then
        startX, startY = gridSize, love.math.random(1, gridSize)
    elseif startSide == 3 then
        startX, startY = love.math.random(1, gridSize), gridSize
    else
        startX, startY = 1, love.math.random(1, gridSize)
    end

    local points = { { x = startX, y = startY } }
    local currentX, currentY = startX, startY
    local numPoints = love.math.random(2, 4)
    for _ = 1, numPoints do
        local dirs = {}
        if currentX > 1 then table_insert(dirs, { dx = -1, dy = 0 }) end
        if currentX < gridSize then table_insert(dirs, { dx = 1, dy = 0 }) end
        if currentY > 1 then table_insert(dirs, { dx = 0, dy = -1 }) end
        if currentY < gridSize then table_insert(dirs, { dx = 0, dy = 1 }) end
        local dir = dirs[love.math.random(#dirs)]
        currentX, currentY = currentX + dir.dx, currentY + dir.dy
        table_insert(points, { x = currentX, y = currentY })
    end
    return points, currentX, currentY
end

local function addRopeEndPoint(points, side, gridSize)
    local x, y
    if side == 1 then
        x, y = love.math.random(1, gridSize), 1
    elseif side == 2 then
        x, y = gridSize, love.math.random(1, gridSize)
    elseif side == 3 then
        x, y = love.math.random(1, gridSize), gridSize
    else
        x, y = 1, love.math.random(1, gridSize)
    end
    table_insert(points, { x = x, y = y })
    return #points
end

local function createTangles()
    local tangles = 0
    local maxTangles = math_min(gameState.currentLevel * 2, #gameState.ropes * 3)
    while tangles < maxTangles and not checkIntersections() do
        for i = 1, #gameState.ropes do
            for j = i + 1, #gameState.ropes do
                local r1, r2 = gameState.ropes[i], gameState.ropes[j]
                for k = 2, #r1.points - 1 do
                    for l = 2, #r2.points - 1 do
                        local tx, ty = r1.points[k].x, r1.points[k].y
                        r1.points[k].x, r1.points[k].y = r2.points[l].x, r2.points[l].y
                        r2.points[l].x, r2.points[l].y = tx, ty
                        if checkIntersections() then
                            tangles = tangles + 1
                            if tangles >= maxTangles then return end
                        else
                            r2.points[l].x, r2.points[l].y = r1.points[k].x, r1.points[k].y
                            r1.points[k].x, r1.points[k].y = tx, ty
                        end
                    end
                end
            end
        end
        break
    end
end

local function generateLevel(level)
    setRandomSeed()
    local baseSize = 4
    local gridSize = math_min(baseSize + math_floor((level - 1) / 3), 12)
    local numRopes = love.math.random(2, math_min(2 + math_floor(level / 2), 7))
    gameState.gridWidth, gameState.gridHeight = gridSize, gridSize
    gameState.ropes, gameState.win = {}, false
    gameState.particles = {}
    gameState.timeSinceWin = 0

    for i = 1, numRopes do
        local startSide = love.math.random(4)
        local points = generateRopePath(gridSize, startSide)
        local endSide
        repeat endSide = love.math.random(4) until endSide ~= startSide
        local endIndex = addRopeEndPoint(points, endSide, gridSize)
        local rope = {
            points = points,
            targetPoints = {},
            color = CONFIG.ropeColors[((i - 1) % #CONFIG.ropeColors) + 1],
            startPoint = 1,
            endPoint = endIndex,
        }
        for j, pt in ipairs(points) do
            rope.targetPoints[j] = { x = pt.x, y = pt.y }
        end
        table_insert(gameState.ropes, rope)
    end

    createTangles()

    if not checkIntersections() then
        for _, rope in ipairs(gameState.ropes) do
            for j = 2, #rope.points - 1 do
                rope.points[j].x = math_max(1, math_min(gridSize, rope.points[j].x + love.math.random(-1, 1)))
                rope.points[j].y = math_max(1, math_min(gridSize, rope.points[j].y + love.math.random(-1, 1)))
            end
        end
    end

    gameState.win = checkWinCondition()
    if gameState.win then generateLevel(level) end
end

-- =============================================
-- Smoothing helper: catmull-rom style interpolation to draw animated ropes
-- =============================================
local function smoothPath(pts, resolution)
    -- pts are grid coords; convert to screen coords and produce smoothed list
    local out = {}
    local function add(x, y) table_insert(out, { x = x, y = y }) end

    if #pts == 0 then return out end
    -- convert to screen
    local screenPts = {}
    for i, p in ipairs(pts) do
        local sx, sy = gridToScreen(p.x, p.y)
        -- center of cell
        local cx = sx
        local cy = sy
        screenPts[i] = { x = cx, y = cy }
    end

    -- simple linear interpolation with one extra smoothing pass
    for i = 1, #screenPts - 1 do
        local a = screenPts[i]
        local b = screenPts[i + 1]
        add(a.x, a.y)
        for t = 1, resolution - 1 do
            local tt = t / resolution
            local ix = lerp(a.x, b.x, tt)
            local iy = lerp(a.y, b.y, tt)
            add(ix, iy)
        end
    end
    -- add last
    local last = screenPts[#screenPts]
    add(last.x, last.y)

    -- gentle smoothing pass (moving average)
    for _ = 1, 1 do
        for i = 2, #out - 1 do
            out[i].x = (out[i - 1].x + out[i].x + out[i + 1].x) / 3
            out[i].y = (out[i - 1].y + out[i].y + out[i + 1].y) / 3
        end
    end

    return out
end

-- =============================================
-- Particles (for small win flourish)
-- =============================================
local function spawnParticle(x, y, color)
    table_insert(gameState.particles, {
        x = x,
        y = y,
        vx = love.math.random(-100, 100),
        vy = love.math.random(-220, -40),
        ttl = CONFIG.particleTTL,
        color = color,
        size = love.math.random(2, 5),
    })
end

local function updateParticles(dt)
    for i = #gameState.particles, 1, -1 do
        local p = gameState.particles[i]
        p.ttl = p.ttl - dt
        if p.ttl <= 0 then
            table.remove(gameState.particles, i)
        else
            p.vy = p.vy + (300 * dt)
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
        end
    end
end

local function drawParticles()
    for _, p in ipairs(gameState.particles) do
        local alpha = math_max(0, p.ttl / CONFIG.particleTTL)
        lg.setColor(p.color[1], p.color[2], p.color[3], alpha)
        lg.circle('fill', p.x, p.y, p.size)
    end
end

-- =============================================
-- Rendering
-- =============================================
local hoverPoint = nil

local function drawBackground()
    -- gradient background
    drawVerticalGradient(0, 0, lg.getWidth(), lg.getHeight(), THEME.backgroundTop, THEME.backgroundBottom)

    -- soft vignette
    lg.setBlendMode('multiply', 'premultiplied')
    lg.setColor(0, 0, 0, 0.08)
    lg.rectangle('fill', 0, 0, lg.getWidth(), lg.getHeight())
    lg.setBlendMode('alpha')
end

local function drawGrid()
    lg.setColor(THEME.gridDot)
    for x = 1, gameState.gridWidth do
        for y = 1, gameState.gridHeight do
            local sx, sy = gridToScreen(x, y)
            lg.circle('fill', sx, sy, 2)
        end
    end
end

local function detectHover()
    local mx, my = love.mouse.getPosition()
    hoverPoint = nil
    for rIndex, rope in ipairs(gameState.ropes) do
        for pIndex, point in ipairs(rope.points) do
            local sx, sy = gridToScreen(point.x, point.y)
            local d = math_sqrt((mx - sx) ^ 2 + (my - sy) ^ 2)
            if d < gameState.cellSize * 0.32 then
                hoverPoint = { rope = rIndex, point = pIndex }
            end
        end
    end
end

local function drawRopes()
    detectHover()
    for i, rope in ipairs(gameState.ropes) do
        local alpha = (gameState.draggingRope == i or not gameState.draggingRope) and 1 or 0.45
        local r, g, b = unpack(rope.color)

        -- smooth rope path
        local sm = smoothPath(rope.points, 6)

        -- glow layer
        lg.setLineWidth(CONFIG.ropeWidth * 1.8)
        lg.setBlendMode('add')
        lg.setColor(r, g, b, 0.14 * alpha)
        for j = 1, #sm - 1 do
            lg.line(sm[j].x, sm[j].y, sm[j + 1].x, sm[j + 1].y)
        end
        lg.setBlendMode('alpha')

        -- rope core
        lg.setLineWidth(CONFIG.ropeCore)
        lg.setColor(r, g, b, 0.98 * alpha)
        for j = 1, #sm - 1 do
            lg.line(sm[j].x, sm[j].y, sm[j + 1].x, sm[j + 1].y)
        end

        -- highlight line
        lg.setLineWidth(2)
        lg.setColor(1, 1, 1, 0.12 * alpha)
        for j = 1, #sm - 1 do
            lg.line(sm[j].x, sm[j].y, sm[j + 1].x, sm[j + 1].y)
        end

        -- draw rope points
        for j, point in ipairs(rope.points) do
            local sx, sy = gridToScreen(point.x, point.y)
            local isEnd = (j == rope.startPoint or j == rope.endPoint)
            local baseSize = gameState.cellSize * 0.13
            local size = isEnd and baseSize * 1.15 or baseSize

            -- subtle endpoint indicator (thin ring, no fill halo)
            if isEnd then
                lg.setLineWidth(3)
                lg.setColor(1, 1, 1, 0.25)
                lg.circle('line', sx, sy, size * 1.25)
            end

            -- hover highlight
            if hoverPoint and hoverPoint.rope == i and hoverPoint.point == j then
                lg.setColor(1, 1, 1, 0.9)
                lg.circle('fill', sx, sy, size * 1.25)
            end

            -- solid white core
            lg.setColor(1, 1, 1)
            lg.circle('fill', sx, sy, size)

            -- colored outline
            lg.setColor(r, g, b)
            lg.circle('line', sx, sy, size)
        end
    end

    -- dragging preview line
    if gameState.draggingRope and gameState.draggingPoint then
        local mx, my = love.mouse.getPosition()
        local rope = gameState.ropes[gameState.draggingRope]
        local tp = rope.targetPoints[gameState.draggingPoint]
        local sx, sy = gridToScreen(tp.x, tp.y)
        lg.setLineWidth(2)
        lg.setColor(1, 1, 1, 0.18)
        lg.line(sx, sy, mx, my)
    end
end

local function drawUI()
    local w, h = lg.getDimensions()

    -- top panel
    lg.setColor(THEME.uiPanel)
    lg.rectangle('fill', 0, 0, w, 110, 6, 6)
    -- subtle top stroke
    lg.setColor(THEME.panelAccent)
    lg.rectangle('line', 6, 6, w - 12, 98, 6, 6)

    lg.setColor(1, 1, 1)
    lg.printf('Knot Again!', 20, 16, w, 'left')
    lg.setFont(lg.newFont(14))
    lg.printf(
        'Level ' ..
        gameState.currentLevel ..
        '  •  Grid: ' .. gameState.gridWidth .. 'x' .. gameState.gridHeight .. '  •  Ropes: ' .. #gameState.ropes, 20, 40,
        w,
        'left')

    lg.setFont(lg.newFont(12))
    lg.setColor(1, 1, 1, 0.8)
    lg.printf('Drag points to untangle. Press R to reshuffle. Press SPACE to continue on win.', 20, 64, w - 40, 'left')

    if gameState.win then
        lg.setColor(0.06, 0.63, 0.14)
        lg.printf('LEVEL COMPLETE!', 0, h - 90, w, 'center')

        -- progress CTA
        lg.setColor(1, 1, 1)
        lg.printf('Press SPACE for next level', 0, h - 56, w, 'center')
    end

    -- footer small helper
    lg.setFont(lg.newFont(10))
    lg.setColor(1, 1, 1, 0.18)
    lg.printf('Tip: Endpoints cannot be moved. Use interior nodes to untangle.', 10, h - 22, w - 20, 'left')
end

local function drawGame()
    drawBackground()
    drawGrid()
    drawRopes()
    drawParticles()
    drawUI()
end

-- =============================================
-- Input
-- =============================================
local function findClickedPoint(x, y)
    local candidates = {}

    -- Collect all points under cursor
    for rIndex, rope in ipairs(gameState.ropes) do
        for pIndex, point in ipairs(rope.points) do
            local sx, sy = gridToScreen(point.x, point.y)
            local dist = math_sqrt((x - sx) ^ 2 + (y - sy) ^ 2)
            if dist <= gameState.cellSize * 0.32 then
                table_insert(candidates, {
                    rope = rIndex,
                    point = pIndex,
                    dist = dist
                })
            end
        end
    end

    if #candidates == 0 then
        return nil, nil
    end

    -- Sort by distance (nearest wins)
    table_sort(candidates, function(a, b)
        return a.dist < b.dist
    end)

    local best = candidates[1]
    return best.rope, best.point
end

local function handleMousePressed(x, y, button)
    if button == 1 and not gameState.win then
        local ropeIndex, pointIndex = findClickedPoint(x, y)
        if ropeIndex and pointIndex then
            gameState.draggingRope = ropeIndex
            gameState.draggingPoint = pointIndex
        end
    end
end

local function handleMouseMoved(x, y)
    if gameState.draggingRope and gameState.draggingPoint then
        local rope = gameState.ropes[gameState.draggingRope]
        local gridXf = (x - gameState.gridStartX) / gameState.cellSize + 1
        local gridYf = (y - gameState.gridStartY) / gameState.cellSize + 1

        -- snap to nearest grid point but allow fractional target for smoothing
        local gx = math_max(1, math_min(gameState.gridWidth, gridXf))
        local gy = math_max(1, math_min(gameState.gridHeight, gridYf))

        local target = rope.targetPoints[gameState.draggingPoint]
        target.x = gx
        target.y = gy

        gameState.win = checkWinCondition()
    end
end

local function handleMouseReleased(_, _, button)
    if button == 1 then
        if gameState.draggingRope and gameState.draggingPoint then
            -- snap final to integer grid
            local rope = gameState.ropes[gameState.draggingRope]
            local tp = rope.targetPoints[gameState.draggingPoint]
            tp.x = math_floor(tp.x + 0.5)
            tp.y = math_floor(tp.y + 0.5)
        end
        gameState.draggingRope = nil
        gameState.draggingPoint = nil
    end
end

local function handleKeyPressed(key)
    if key == 'space' and gameState.win then
        gameState.currentLevel = gameState.currentLevel + 1
        generateLevel(gameState.currentLevel)
        calculateGridPosition()
    elseif key == 'r' then
        generateLevel(gameState.currentLevel)
        calculateGridPosition()
    end
end

-- =============================================
-- LÖVE callbacks
-- =============================================
function love.load()
    generateLevel(1)
    calculateGridPosition()

    -- set a default font sizes cached
    love.graphics.setFont(love.graphics.newFont(14))
end

function love.resize()
    calculateGridPosition()
end

function love.mousepressed(x, y, button)
    handleMousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
    handleMouseReleased(x, y, button)
end

function love.mousemoved(x, y)
    handleMouseMoved(x, y)
end

function love.keypressed(key)
    handleKeyPressed(key)
end

function love.update(dt)
    -- smooth rope points toward targetPoints
    for _, rope in ipairs(gameState.ropes) do
        for i, target in ipairs(rope.targetPoints) do
            rope.points[i].x = lerp(rope.points[i].x, target.x, dt * CONFIG.smoothSpeed)
            rope.points[i].y = lerp(rope.points[i].y, target.y, dt * CONFIG.smoothSpeed)
        end
    end

    -- particles and win timer
    updateParticles(dt)
    if gameState.win then
        gameState.timeSinceWin = gameState.timeSinceWin + dt
        -- spawn gentle particles for celebration
        if gameState.timeSinceWin < 1.2 then
            for _ = 1, 8 do
                local c = CONFIG.ropeColors[love.math.random(#CONFIG.ropeColors)]
                spawnParticle(love.graphics.getWidth() * 0.5 + love.math.random(-140, 140),
                    love.graphics.getHeight() * 0.4 + love.math.random(-24, 24), c)
            end
        end
    end
end

function love.draw()
    drawGame()
end
