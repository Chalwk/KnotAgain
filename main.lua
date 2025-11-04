-- KnotAgain!
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Game = require("classes.Game")
local Menu = require("classes.Menu")
local BackgroundManager = require("classes.BackgroundManager")

local game, menu, background
local screenWidth, screenHeight
local gameState = "menu"
local stateTransition = { alpha = 0, duration = 0.5, timer = 0, active = false }

local function updateScreenSize()
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()
end

local function startStateTransition(newState)
    stateTransition = {
        alpha = 0,
        duration = 0.3,
        timer = 0,
        active = true,
        targetState = newState
    }
end

function love.load()
    love.window.setTitle("Rope Untangler")
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("smooth")

    game = Game.new()
    menu = Menu.new()
    background = BackgroundManager.new()

    updateScreenSize()
    menu:setScreenSize(screenWidth, screenHeight)
    game:setScreenSize(screenWidth, screenHeight)
end

function love.update(dt)
    updateScreenSize()

    -- Handle state transitions
    if stateTransition.active then
        stateTransition.timer = stateTransition.timer + dt
        stateTransition.alpha = math.min(stateTransition.timer / stateTransition.duration, 1)

        if stateTransition.timer >= stateTransition.duration then
            gameState = stateTransition.targetState
            stateTransition.active = false
            stateTransition.alpha = 0
        end
    end

    if gameState == "menu" then
        menu:update(dt, screenWidth, screenHeight)
    elseif gameState == "playing" then
        game:update(dt)
    elseif gameState == "options" then
        menu:update(dt, screenWidth, screenHeight)
    end

    background:update(dt)
end

function love.draw()
    local time = love.timer.getTime()

    -- Draw background based on state
    if gameState == "menu" or gameState == "options" then
        background:drawMenuBackground(screenWidth, screenHeight, time)
    elseif gameState == "playing" then
        background:drawGameBackground(screenWidth, screenHeight, time)
    end

    -- Draw game content
    if gameState == "menu" or gameState == "options" then
        menu:draw(screenWidth, screenHeight, gameState)
    elseif gameState == "playing" then
        game:draw()
    end

    -- Draw transition overlay
    if stateTransition.active then
        love.graphics.setColor(0, 0, 0, stateTransition.alpha)
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then
        if gameState == "menu" then
            local action = menu:handleClick(x, y, "menu")
            if action == "start" then
                startStateTransition("playing")
                game:startNewGame(menu:getDifficulty(), menu:getCategory())
            elseif action == "options" then
                startStateTransition("options")
            elseif action == "quit" then
                love.event.quit()
            end
        elseif gameState == "options" then
            local action = menu:handleClick(x, y, "options")
            if not action then return end
            if action == "back" then
                startStateTransition("menu")
            elseif action:sub(1, 4) == "diff" then
                local difficulty = action:sub(6)
                menu:setDifficulty(difficulty)
            elseif action:sub(1, 4) == "cate" then
                local category = action:sub(6)
                menu:setCategory(category)
            end
        elseif gameState == "playing" then
            if game:isGameOver() then
                startStateTransition("menu")
            else
                game:handleClick(x, y)
            end
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if gameState == "playing" then
        game:handleMouseMove(x, y, dx, dy)
    end
end

function love.mousereleased(x, y, button)
    if gameState == "playing" and button == 1 then
        game:handleMouseRelease(x, y)
    end
end

function love.keypressed(key)
    if key == "escape" then
        if gameState == "playing" or gameState == "options" then
            startStateTransition("menu")
        else
            love.event.quit()
        end
    elseif key == "f11" then
        local fullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not fullscreen)
    elseif gameState == "playing" then
        game:handleKeypress(key)
    end
end

function love.resize(w, h)
    updateScreenSize()
    menu:setScreenSize(screenWidth, screenHeight)
    game:setScreenSize(screenWidth, screenHeight)
end
