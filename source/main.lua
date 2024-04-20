import "../toyboxes/toyboxes"
import "CoreLibs/graphics"
import "CoreLibs/timer"
import "CoreLibs/object"
import "CoreLibs/math"

local gfx <const> = playdate.graphics
local tmr <const> = playdate.timer

local book = import("danger")

local fontHeight
local middle

local story
local gamesave


local continuing <const> = 1
local choosing <const> = 2
local scrolling <const> = 3

local state = continuing -- choosing
local currentSelectedChoice = 0

local image
local imagePosition
local nextImagePosition = 0
local imageHeight
local choiceImages
local choiceHeight

SCREEN_HEIGHT = 240
SCREEN_WIDTH = 400

-- initialization
function setupGame()
    local fontPaths = {
		[gfx.font.kVariantNormal] = "fonts/Asheville Ayu",
		[gfx.font.kVariantBold] = "fonts/Asheville Ayu Bold",
	}
    local fontFamily = gfx.font.newFamily(fontPaths)
    gfx.setFontFamily(fontFamily)
	fontHeight = fontFamily[gfx.font.kVariantNormal]:getHeight()
    middle = SCREEN_HEIGHT / 2 - fontHeight / 2

    gfx.clear(gfx.kColorWhite)
    gfx.drawText("_Loading story..._", 5, middle)
    playdate.display.flush()
    
    story = Story(book)

    gamesave = playdate.datastore.read("gamesave")
    if gamesave then       
        story.state:load(gamesave)
    end
    gfx.clear(gfx.kColorWhite)
    imagePosition = 0
    imageHeight = 0
    choiceHeight = 0
end

local c = 0
function continueStory()
    if story == nil then
        print("Story not ready yet")
        return
    end
    local i = 0
    repeat
        i = i + 1
        if not story:canContinue() then
            break
        end
        story:ContinueAsync(20)
        if story:asyncContinueComplete() then
            local currentText = story:currentText()
            local currentTags = story:currentTags()
            drawText(currentText, currentTags)
            image:draw(0, imagePosition)
        end
        c = (i * 30) % 360
        coroutine.yield()
    until not story:canContinue()

    local choices = story:currentChoices()

    drawChoices(choices)
    coroutine.yield()
    
end

function playdate.update()
    tmr.updateTimers()

    if state == continuing then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(SCREEN_WIDTH - 20, SCREEN_HEIGHT - 20, 10)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawArc(SCREEN_WIDTH - 20, SCREEN_HEIGHT - 20, 8, 0, c)
        gfx.setColor(gfx.kColorBlack)

        local previousHeight = imageHeight
        
        continueStory()
        gfx.clear()
        renderDraws()

        local positionOfNewContent = imagePosition + previousHeight
        local absScroll = positionOfNewContent

        local heightOfNewContent = (imageHeight + choiceHeight) - previousHeight

        nextImagePosition = imagePosition - positionOfNewContent

        local maxTop = SCREEN_HEIGHT - imageHeight - choiceHeight
        if nextImagePosition < maxTop  then
            nextImagePosition = maxTop
        end

        state = scrolling
    elseif state == scrolling then
        if nextImagePosition < imagePosition then
            -- print("scrolling from ",imagePosition, "to",  nextImagePosition)
            imagePosition = math.max(nextImagePosition, imagePosition - 3)
            renderDraws()
            return
        end
        if currentSelectedChoice == 0 and #choiceImages > 0 then
            currentSelectedChoice = 1
        end
        renderDraws()
        state = choosing
    elseif state == choosing then
        -- do nothing actually
    end

end


function drawText(text, tags)
    local width, height = gfx.getTextSizeForMaxWidth(text, 390)
    height = height - 10
    local enlargedHeight = imageHeight + height
    local enlargedImage = gfx.image.new(SCREEN_WIDTH, enlargedHeight, gfx.kColorWhite)
    gfx.pushContext(enlargedImage)
        if image ~= nil then
            image:draw(0, 0)
        end
        local topPadding = imageHeight == 0 and 5 or 0
        local newParagraph = gfx.image.new(SCREEN_WIDTH, height + topPadding*2, gfx.kColorWhite)
        gfx.pushContext(newParagraph)
            gfx.drawTextInRect(text, 5, topPadding, width, height + topPadding)
            -- gfx.drawRect(1, 1, 398, height-2)
        gfx.popContext()
        newParagraph:draw(0, imageHeight)
    gfx.popContext()
    image = enlargedImage
    imageHeight = enlargedHeight
end

function drawChoices(choices)
    choiceImages = {}
    choiceHeight = 0
    for i,c in ipairs(choices) do
        local width, height = gfx.getTextSizeForMaxWidth(c.text, 370)
        local cimage = gfx.image.new(SCREEN_WIDTH, height+8, gfx.kColorWhite)
        gfx.pushContext(cimage)
        gfx.drawTextInRect(c.text, 20, 5, width, height)
        gfx.fillCircleAtPoint(10, fontHeight /2 + 3, 3)
        gfx.popContext()
        table.insert(choiceImages, {
            ["image"] = cimage,
            ["height"] = height+8
        })
        choiceHeight = choiceHeight + height+8
    
    end
end

function renderDraws()
    image:draw(0, imagePosition)
    local choicePosition = imagePosition + imageHeight
    for i, c in ipairs(choiceImages) do
        if i == currentSelectedChoice then
            c.image:invertedImage():draw(0, choicePosition)
        else
            c.image:draw(0, choicePosition)
        end
        choicePosition = choicePosition + c.height
    end
end

function scroll(change)
	if imageHeight + choiceHeight < SCREEN_HEIGHT then
		return
	end
	imagePosition = imagePosition - change

    local maxTop = SCREEN_HEIGHT - imageHeight - choiceHeight
	if imagePosition > 0 then
		imagePosition = 0
	elseif imagePosition < maxTop  then
		imagePosition = maxTop
	end
    renderDraws()
end

function playdate.cranked(change)
	if state == choosing then
		scroll(change * 2)
    elseif state == scrolling then
        if currentSelectedChoice == 0 and #choiceImages > 0 then
            currentSelectedChoice = 1
        end
        state = choosing
	end
end

function playdate.AButtonUp()
    if state == choosing and currentSelectedChoice > 0 then
        story:ChooseChoiceIndex(currentSelectedChoice)
        choiceImages = {}
        currentSelectedChoice = 0
        gfx.clear()
        renderDraws()
        state = continuing
    elseif state == scrolling then
        imagePosition = nextImagePosition
        if currentSelectedChoice == 0 and #choiceImages > 0 then
            currentSelectedChoice = 1
        end
        state = choosing
    else
        print("Still continuing !")
    end
end

function playdate.downButtonDown()
    if currentSelectedChoice > 0 then
        if currentSelectedChoice == #choiceImages then
            currentSelectedChoice = 1
        else
            currentSelectedChoice = currentSelectedChoice + 1
        end
    end
    renderDraws()
end

function playdate.upButtonUp()
    if currentSelectedChoice > 0 then
        if currentSelectedChoice == 1 then
            currentSelectedChoice = #choiceImages
        else
            currentSelectedChoice = currentSelectedChoice - 1
        end
    end
    renderDraws()
end

function saveGame()
	if state == choosing then
		local savegame = story.state:save()
		playdate.datastore.write(savegame, "savegame")
	end
end

function playdate.gameWillTerminate()
	saveGame()
end

function playdate.deviceWillLock()
	saveGame()
end

function playdate.gameWillPause()
	saveGame()
end

setupGame()