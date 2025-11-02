-- Knot Again! - Love2D
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

-- =============================================
-- Configuration Constants
-- =============================================
local CONFIG = {
    ropeWidth = 8,
    ropeColors = {
        {0.9, 0.2, 0.2}, -- Red
        {0.2, 0.7, 0.2}, -- Green
        {0.2, 0.4, 0.9}, -- Blue
        {0.9, 0.7, 0.1}, -- Yellow
        {0.7, 0.2, 0.9}, -- Purple
        {0.2, 0.8, 0.8}, -- Cyan
        {0.8, 0.5, 0.2}, -- Orange
    },

    -- Optional smoothing for rope point movement
    smoothMovement = true,
    smoothSpeed = 10, -- higher = faster catch-up
}

-- =============================================
-- Game State
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
    cellSize = 60
}

local THEME = {
    background = {0.08, 0.09, 0.12},
    gridDot = {0.25, 0.25, 0.3},
    uiPanel = {0, 0, 0, 0.5},
    highlight = {1, 1, 1, 0.6},
}

local hoverPoint = nil

-- =============================================
-- Utility Functions
-- =============================================
local function setRandomSeed()
    love.math.random(love.timer.getTime() * 1000)
end

local function lerp(a, b, t)
    return a + (b - a) * math.min(t, 1)
end

local function calculateGridPosition()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local maxCellWidth = (windowWidth - 100) / gameState.gridWidth
    local maxCellHeight = (windowHeight - 150) / gameState.gridHeight
    gameState.cellSize = math.min(maxCellWidth, maxCellHeight, 80)
    gameState.cellSize = math.max(gameState.cellSize, 30)
    local totalGridWidth = gameState.gridWidth * gameState.cellSize
    local totalGridHeight = gameState.gridHeight * gameState.cellSize
    gameState.gridStartX = (windowWidth - totalGridWidth) / 2
    gameState.gridStartY = (windowHeight - totalGridHeight) / 2
end

local function gridToScreen(gridX, gridY)
    return gameState.gridStartX + (gridX - 1) * gameState.cellSize,
           gameState.gridStartY + (gridY - 1) * gameState.cellSize
end

local function screenToGrid(screenX, screenY)
    local gridX = math.floor((screenX - gameState.gridStartX) / gameState.cellSize) + 1
    local gridY = math.floor((screenY - gameState.gridStartY) / gameState.cellSize) + 1
    return gridX, gridY
end

local function isValidGridPoint(x, y)
    return x >= 1 and x <= gameState.gridWidth and y >= 1 and y <= gameState.gridHeight
end

-- =============================================
-- Geometry and Intersection Functions
-- =============================================
local function cross(x1, y1, x2, y2)
    return x1 * y2 - y1 * x2
end

local function segmentsIntersect(a1x, a1y, a2x, a2y, b1x, b1y, b2x, b2y)
    local r_x, r_y = a2x - a1x, a2y - a1y
    local s_x, s_y = b2x - b1x, b2y - b1y
    local d = cross(r_x, r_y, s_x, s_y)
    if math.abs(d) < 0.0001 then return false end
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
                        local a2x, a2y = gridToScreen(rope1.points[k+1].x, rope1.points[k+1].y)
                        local b1x, b1y = gridToScreen(rope2.points[l].x, rope2.points[l].y)
                        local b2x, b2y = gridToScreen(rope2.points[l+1].x, rope2.points[l+1].y)
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
-- Level Generation (unchanged core)
-- =============================================
local function generateRopePath(gridSize, startSide)
    local startX, startY
    if startSide == 1 then startX, startY = love.math.random(1, gridSize), 1
    elseif startSide == 2 then startX, startY = gridSize, love.math.random(1, gridSize)
    elseif startSide == 3 then startX, startY = love.math.random(1, gridSize), gridSize
    else startX, startY = 1, love.math.random(1, gridSize) end

    local points = {{x = startX, y = startY}}
    local currentX, currentY = startX, startY
    local numPoints = love.math.random(2, 4)

    for j = 1, numPoints do
        local dirs = {}
        if currentX > 1 then table.insert(dirs, {dx = -1, dy = 0}) end
        if currentX < gridSize then table.insert(dirs, {dx = 1, dy = 0}) end
        if currentY > 1 then table.insert(dirs, {dx = 0, dy = -1}) end
        if currentY < gridSize then table.insert(dirs, {dx = 0, dy = 1}) end
        local dir = dirs[love.math.random(#dirs)]
        currentX, currentY = currentX + dir.dx, currentY + dir.dy
        table.insert(points, {x = currentX, y = currentY})
    end
    return points, currentX, currentY
end

local function addRopeEndPoint(points, side, gridSize)
    local x, y
    if side == 1 then x, y = love.math.random(1, gridSize), 1
    elseif side == 2 then x, y = gridSize, love.math.random(1, gridSize)
    elseif side == 3 then x, y = love.math.random(1, gridSize), gridSize
    else x, y = 1, love.math.random(1, gridSize) end
    table.insert(points, {x = x, y = y})
    return #points
end

local function createTangles()
    local tangles = 0
    local maxTangles = math.min(gameState.currentLevel * 2, #gameState.ropes * 3)
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
    local gridSize = math.min(baseSize + math.floor((level - 1) / 3), 12)
    local numRopes = love.math.random(2, math.min(2 + math.floor(level / 2), 7))
    gameState.gridWidth, gameState.gridHeight = gridSize, gridSize
    gameState.ropes, gameState.win = {}, false

    for i = 1, numRopes do
        local startSide = love.math.random(4)
        local points = generateRopePath(gridSize, startSide)
        local endSide repeat endSide = love.math.random(4) until endSide ~= startSide
        local endIndex = addRopeEndPoint(points, endSide, gridSize)
        local rope = {
            points = points,
            targetPoints = {}, -- for smoothing
            color = CONFIG.ropeColors[((i - 1) % #CONFIG.ropeColors) + 1],
            startPoint = 1,
            endPoint = endIndex
        }
        for j, pt in ipairs(points) do
            rope.targetPoints[j] = {x = pt.x, y = pt.y}
        end
        table.insert(gameState.ropes, rope)
    end

    createTangles()
    if not checkIntersections() then
        for _, rope in ipairs(gameState.ropes) do
            for j = 2, #rope.points - 1 do
                rope.points[j].x = math.max(1, math.min(gridSize, rope.points[j].x + love.math.random(-1, 1)))
                rope.points[j].y = math.max(1, math.min(gridSize, rope.points[j].y + love.math.random(-1, 1)))
            end
        end
    end

    gameState.win = checkWinCondition()
    if gameState.win then generateLevel(level) end
end

-- =============================================
-- Rendering
-- =============================================
local function drawGrid()
    love.graphics.setColor(THEME.gridDot)
    for x = 1, gameState.gridWidth do
        for y = 1, gameState.gridHeight do
            local sx, sy = gridToScreen(x, y)
            love.graphics.circle("fill", sx, sy, 2)
        end
    end
end

local function drawRopes()
    local mx, my = love.mouse.getPosition()
    hoverPoint = nil
    for rIndex, rope in ipairs(gameState.ropes) do
        for pIndex, point in ipairs(rope.points) do
            local sx, sy = gridToScreen(point.x, point.y)
            local d = math.sqrt((mx - sx)^2 + (my - sy)^2)
            if d < gameState.cellSize * 0.3 then
                hoverPoint = {rope = rIndex, point = pIndex}
            end
        end
    end

    for i, rope in ipairs(gameState.ropes) do
        local alpha = (gameState.draggingRope == i or not gameState.draggingRope) and 1 or 0.4
        local r, g, b = unpack(rope.color)

        love.graphics.setLineWidth(CONFIG.ropeWidth * 1.6)
        love.graphics.setColor(r, g, b, 0.25 * alpha)
        for j = 1, #rope.points - 1 do
            local x1, y1 = gridToScreen(rope.points[j].x, rope.points[j].y)
            local x2, y2 = gridToScreen(rope.points[j+1].x, rope.points[j+1].y)
            love.graphics.line(x1, y1, x2, y2)
        end

        love.graphics.setLineWidth(CONFIG.ropeWidth)
        love.graphics.setColor(r, g, b, 0.9 * alpha)
        for j = 1, #rope.points - 1 do
            local x1, y1 = gridToScreen(rope.points[j].x, rope.points[j].y)
            local x2, y2 = gridToScreen(rope.points[j+1].x, rope.points[j+1].y)
            love.graphics.line(x1, y1, x2, y2)
        end

        for j, point in ipairs(rope.points) do
            local sx, sy = gridToScreen(point.x, point.y)
            local isEnd = (j == rope.startPoint or j == rope.endPoint)
            local size = isEnd and gameState.cellSize * 0.2 or gameState.cellSize * 0.15
            if hoverPoint and hoverPoint.rope == i and hoverPoint.point == j then
                love.graphics.setColor(THEME.highlight)
                love.graphics.circle("fill", sx, sy, size * 1.3)
            end
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", sx, sy, size)
            love.graphics.setColor(r, g, b)
            love.graphics.circle("line", sx, sy, size)
        end
    end
end

local function drawUI()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(THEME.uiPanel)
    love.graphics.rectangle("fill", 0, 0, w, 110)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Knot Again! - Level " .. gameState.currentLevel, 10, 10)
    love.graphics.print("Grid: " .. gameState.gridWidth .. "x" .. gameState.gridHeight ..
        " | Ropes: " .. #gameState.ropes, 10, 30)
    love.graphics.print("Drag points to untangle ropes", 10, 50)
    if gameState.win then
        love.graphics.setColor(0, 1, 0)
        love.graphics.printf("Level Complete! Press SPACE for next level",
            0, h - 60, w, "center")
    end
end

local function drawGame()
    love.graphics.clear(THEME.background)
    drawGrid()
    drawRopes()
    drawUI()
end

-- =============================================
-- Input & Core
-- =============================================
local function findClickedPoint(x, y)
    for rIndex, rope in ipairs(gameState.ropes) do
        for pIndex, point in ipairs(rope.points) do
            local sx, sy = gridToScreen(point.x, point.y)
            local dist = math.sqrt((x - sx)^2 + (y - sy)^2)
            if dist <= gameState.cellSize * 0.3 then
                return rIndex, pIndex
            end
        end
    end
    return nil, nil
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
        local gridX, gridY = screenToGrid(x, y)
        if isValidGridPoint(gridX, gridY) then
            rope.targetPoints[gameState.draggingPoint].x = gridX
            rope.targetPoints[gameState.draggingPoint].y = gridY
            gameState.win = checkWinCondition()
        end
    end
end

local function handleMouseReleased(_, _, button)
    if button == 1 then
        gameState.draggingRope = nil
        gameState.draggingPoint = nil
    end
end

local function handleKeyPressed(key)
    if key == "space" and gameState.win then
        gameState.currentLevel = gameState.currentLevel + 1
        generateLevel(gameState.currentLevel)
        calculateGridPosition()
    elseif key == "r" then
        generateLevel(gameState.currentLevel)
        calculateGridPosition()
    end
end

-- =============================================
-- LÖVE Callbacks
-- =============================================
function love.load()
    love.window.setTitle("Knot Again! - Beautified Edition")
    love.window.setMode(900, 700, {resizable = true})
    generateLevel(1)
    calculateGridPosition()
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
    if CONFIG.smoothMovement then
        for _, rope in ipairs(gameState.ropes) do
            for i, target in ipairs(rope.targetPoints) do
                rope.points[i].x = lerp(rope.points[i].x, target.x, dt * CONFIG.smoothSpeed)
                rope.points[i].y = lerp(rope.points[i].y, target.y, dt * CONFIG.smoothSpeed)
            end
        end
    else
        for _, rope in ipairs(gameState.ropes) do
            for i, target in ipairs(rope.targetPoints) do
                rope.points[i].x, rope.points[i].y = target.x, target.y
            end
        end
    end
end

function love.draw()
    drawGame()
end
