-- Bundled by luabundle {"version":"1.7.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
require("importer")

end)
__bundle_register("importer", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Original "Importer" script by Amuzet (https://github.com/Amuzet/Tabletop-Simulator-Scripts/blob/master/Magic/Importer.lua)
-- Significant overhaul by Vivi and rubic (https://github.com/jordanpg/tts-mtg/tree/main/packages/tts-mtg-importer)
-- Additional help from Oops-I-baked-a-pie (denoted as "pieHere")

--[[ Constants ]]

MOD_NAME = 'Card Importer'
version = 2.002 -- this property has to remain in lowercase as "version" to maintain compatibility with scripts like the Encoder
WORKSHOP_ID = 'https://steamcommunity.com/sharedfiles/filedetails/?id=1838051922'
GIT_URL = 'https://raw.githubusercontent.com/jordanpg/Tabletop-Simulator-Scripts/master/Magic/Importer.lua'
LANG = 'en'
self.setName('[854FD9]' .. MOD_NAME .. ' [49D54F]' .. version)

_G.MOD_NAME = MOD_NAME

--[[ Imports ]]

local utils = require("utils")
local ttsUtils = require("tts_utils")
local encoderIntegration = require("encoder_integration")

--[[ Classes ]]

-- metatable for special object functionality
local TBL = {
    __call = function(this, arg)
        if arg then
            return this[arg]
        end
        return this.___
    end,
    __index = function(this, key)
        if type(this.___) == 'table' then
            rawset(this, key, this.___())
        else
            rawset(this, key, this.___)
        end
        return this[key]
    end
}

-- creates a special object which holds a default value
function TBL.new(default, table)
    if table then
        table.___ = default
        return setmetatable(table, TBL)
    else
        return setmetatable(default, TBL)
    end
end

-- [[ Text Item Manager ]]

textItems = {}
--- newText can be called to spawn a 3D text object in the scene at a specific position.
newText = setmetatable({
    type = '3DText',
    position = {0, 2, 0},
    rotation = {90, 0, 0}
}, {
    __call = function(this, pos, text, fontSize)
        this.position = pos
        local thisObj = spawnObject(this)
        table.insert(textItems, thisObj)
        thisObj.TextTool.setValue(text)
        thisObj.TextTool.setFontSize(fontSize or 50)

        --[[
        ttsUtils.testLog('Creating new '.. this.type .. ' text item:', nil, 'debug')
        ttsUtils.testLog(text, nil, 'trace')
        --]]

        return function(t)
            if t then
                thisObj.TextTool.setValue(t)
            else
                for i, obj in ipairs(textItems) do
                    if obj == thisObj then
                        table.remove(textItems, i)
                    end
                end
                thisObj.destruct()
            end
        end
    end
})

--[[ Variables ]]

local Deck = 1
local Tick = 0.2    -- time to wait between webrequests, to prevent Too Many Requests
local Test = true  -- set to true when performing tests with this script
local Quality = TBL.new('normal', {})
local Back = TBL.new('https://i.stack.imgur.com/787gj.png', {})
_G.Test = Test

--- Block comment describing how to use the Importer
local Usage = [[[b]%s
[-][-][0077ff]Scryfall[/b] [i]cardname[/i] [-][Spawns that card]
[b][0077ff]Scryfall[/b] [i]URL cardname[/i] [-][Spawns [i]cardname[/i] with [i]URL[/i] as its face]
[b][0077ff]Scryfall[/b] [i]URL[/i]  [-][Spawns that deck list or Image]
[b]Supported:[/b] [i]archidekt cubecobra deckstats deckbox moxfield mtggoldfish scryfall tappedout pastebin[/i]
[b][0077ff]Scryfall help[/b] [-][Displays all possible commands]

[b][ff7700]deck[/b] [-][Spawn deck from newest Notebook tab]
[b][ff7700]back[/b] [i]URL[/i] [-][Makes card back URL]
[b][ff7700]text[/b] [i]name[/i] [-][Prints Oracle text of name]
[b][ff7700]print[/b] [i]name[/i] [-][Spawns various printings of name]
[b][ff7700]legal[/b] [i]name[/i] [-][Prints Legalities of name]
[b][ff7700]rules[/b] [i]name[/i] [-][Prints Rulings of name ]
[b][ff7700]random[/b] [i]isecalpwubrg<>=# quantity[/i] [-]['[i]ri=2[/i]' Spawns a Red Instant of CMC Two]
[b][ff7700]search[/b] [i]syntax[/i] [-][Spawns all cards matching that search (be careful)]
[b][ff7700]random[/b] [i]?q=syntax quantity[/i] [-][Advanced Random using search syntax (go crazy!)]
[b][ff7700]clear[/b] [i]queue[/i] [-][Clears all requests in the queue]
[b][ff7700]clear[/b] [i]back[/i] [-][Resets cardbacks to default]
[b][ff7700]quality[/b] [i]mode[/i] [-][Changes the quality of the image]
[i]small,normal,large,art_crop,border_crop[/i] ]]

local DefaultBackState = [[{
"76561198015252567":"https://static.wikia.nocookie.net/mtgsalvation_gamepedia/images/5/5c/Cardback_reimagined.png",
"76561198237455552":"https://i.imgur.com/FhwK9CX.jpg",
"76561198041801580":"https://earthsky.org/upl/2015/01/pillars-of-creation-2151.jpg",
"76561198052971595":"https://steamusercontent-a.akamaihd.net/ugc/1653343413892121432/2F5D3759EEB5109D019E2C318819DEF399CD69F9/",
"76561198053151808":"https://steamusercontent-a.akamaihd.net/ugc/1289668517476690629/0D8EB10F5D7351435C31352F013538B4701668D5/",
"76561197984192849":"https://i.imgur.com/JygQFRA.png",
"76561197975480678":"https://steamusercontent-a.akamaihd.net/ugc/772861785996967901/6E85CE1D18660E60849EF5CEE08E818F7400A63D/",
"76561198000043097":"https://i.imgur.com/rfQsgTL.png",
"76561198025014348":"https://i.imgur.com/pPnIKhy.png",
"76561198045241564":"http://i.imgur.com/P7qYTcI.png",
"76561198045776458":"https://cdnb.artstation.com/p/assets/images/images/009/160/199/medium/gui-ramalho-air-compass.jpg",
"76561198069287630":"http://i.imgur.com/OCOGzLH.jpg",
"76561198005479600":"https://images-na.ssl-images-amazon.com/images/I/61AGZ37D7eL._SL1039_.jpg",
"76561198317076000":"https://i.imgur.com/vh8IeEn.jpeg"}]]

-- Image URI Handler

--[[ Card Spawning Class ]]

--- This class represents a single card to be spawned in the TTS environment.
local Card = setmetatable({
    n = 1,
    customImage = false
}, {
    __call = function(this, scryfallCard, qTbl)
        success, errorMSG = pcall(function()
            -- needed fields in scryfallCard: name, type_line, cmc, card_faces, oracle_text, power, toughness, loyalty, layout
            scryfallCard.face, scryfallCard.oracle, scryfallCard.back = '', '', Back[qTbl.player] or Back.___
            local n, state, qual, imgSuffix = this.n, false, Quality[qTbl.player], ''
            this.n = n + 1

            -- Check for card's spoiler image quality
            if scryfallCard.image_status ~= 'highres_scan' then
                imgSuffix = '?' .. tostring(os.date('%x')):gsub('/', '')
            end

            local orientation = {false} -- Tabletop Card Sideways

            -- Oracle text Handling for Split, then DFC, then Normal
            if scryfallCard.card_faces and scryfallCard.image_uris then -- Adventure/Split
                -- local instantSorcery = 0
                for i, f in ipairs(scryfallCard.card_faces) do
                    f.name = f.name:gsub('"', '') .. '\n' .. f.type_line .. '\n' .. scryfallCard.cmc .. 'CMC'
                    if i == 1 then
                        scryfallCard.name = f.name
                    end
                    scryfallCard.oracle = scryfallCard.oracle .. f.name .. '\n' .. setOracle(f) .. (i == #scryfallCard.card_faces and '' or '\n')

                    -- Count nonPermanent text boxes, exclude Aftermath
                    -- if not scryfallCard.oracle:find('Aftermath') and ('InstantSorcery'):find(f.type_line) then
                    --     instantSorcery = 1 + instantSorcery
                    -- end
                end
                if not scryfallCard.oracle:find('Aftermath') and scryfallCard.layout == 'split' then -- Split/Fuse
                    orientation[1] = true
                end

            elseif scryfallCard.card_faces then -- DFC
                local f = scryfallCard.card_faces[1]
                local cmc = scryfallCard.cmc or f.cmc or 0
                scryfallCard.name = f.name:gsub('"', '') .. '\n' .. f.type_line .. '\n' .. cmc .. 'CMC DFC'
                scryfallCard.oracle = setOracle(f)
                for i, face in ipairs(scryfallCard.card_faces) do
                    if face.type_line:find('Battle') then
                        orientation[i] = true
                    else
                        orientation[i] = false
                    end
                end
            else -- NORMAL
                scryfallCard.name = scryfallCard.name:gsub('"', '') .. '\n' .. scryfallCard.type_line .. '\n' .. scryfallCard.cmc .. 'CMC'
                scryfallCard.oracle = setOracle(scryfallCard)
                if ('planar'):find(scryfallCard.layout) then
                    orientation[1] = true
                end
            end

            local backDat = nil
            -- Image Handling
            if qTbl.deck and qTbl.image and qTbl.image[n] then
                scryfallCard.face = qTbl.image[n]
            elseif scryfallCard.card_faces and not scryfallCard.image_uris then -- DFC REWORKED for STATES!
                local faceAddress = utils.truncateURI(scryfallCard.card_faces[1].image_uris.normal, qual, imgSuffix)
                local backAddress = utils.truncateURI(scryfallCard.card_faces[2].image_uris.normal, qual, imgSuffix)
                if faceAddress:find('/back/') and backAddress:find('/front/') then
                    local temp = faceAddress;
                    faceAddress = backAddress;
                    backAddress = temp
                end
                if this.customImage then
                    faceAddress, backAddress = this.customImage, this.customImage
                end
                scryfallCard.face = faceAddress
                local f = scryfallCard.card_faces[2]
                local cmc = scryfallCard.cmc or f.cmc or 0
                local name = f.name:gsub('"', '') .. '\n' .. f.type_line .. '\n' .. cmc .. 'CMC DFC'
                local oracle = setOracle(f)
                local b = n

                if qTbl.deck then
                    b = qTbl.deck + n
                end
                backDat = {
                    Transform = {
                        posX = 0,
                        posY = 0,
                        posZ = 0,
                        rotX = 0,
                        rotY = 0,
                        rotZ = 0,
                        scaleX = 1,
                        scaleY = 1,
                        scaleZ = 1
                    },
                    Name = "Card",
                    Nickname = name,
                    Description = oracle,
                    Memo = scryfallCard.oracle_id,
                    CardID = b * 100,
                    CustomDeck = {
                        [b] = {
                            FaceURL = backAddress,
                            BackURL = scryfallCard.back,
                            NumWidth = 1,
                            NumHeight = 1,
                            Type = 0,
                            BackIsHidden = true,
                            UniqueBack = false
                        }
                    }
                }
            elseif this.customImage then -- Custom Image
                scryfallCard.face = this.customImage
                this.customImage = false
            elseif scryfallCard.image_uris then
                scryfallCard.face = utils.truncateURI(scryfallCard.image_uris.normal, qual, imgSuffix)
            end

            -- prepare cardDat
            local cardDat = {
                Transform = {
                    posX = 0,
                    posY = 0,
                    posZ = 0,
                    rotX = 0,
                    rotY = 0,
                    rotZ = 0,
                    scaleX = 1,
                    scaleY = 1,
                    scaleZ = 1
                },
                Name = "Card",
                Nickname = scryfallCard.name,
                Description = scryfallCard.oracle,
                Memo = scryfallCard.oracle_id,
                CardID = n * 100,
                CustomDeck = {
                    [n] = {
                        FaceURL = scryfallCard.face,
                        BackURL = scryfallCard.back,
                        NumWidth = 1,
                        NumHeight = 1,
                        Type = 0,
                        BackIsHidden = true,
                        UniqueBack = false
                    }
                }
            }

            if backDat then -- backface is state#2
                cardDat.States = {
                    [2] = backDat
                }
            end

            local landscapeView = {0, 180, 270}
            -- AltView
            if orientation[1] then
                cardDat.AltLookAngle = landscapeView
            end
            if orientation[2] then
                cardDat.States[2].AltLookAngle = landscapeView
            end

            -- Spawn
            if not (qTbl.deck) or qTbl.deck == 1 then -- Spawn solo card
                local spawnDat = {
                    data = cardDat,
                    position = qTbl.position or {0, 2, 0},
                    rotation = Vector(0, Player[qTbl.color].getPointerRotation(), 0)
                }
                spawnObjectData(spawnDat)
                ttsUtils.testLog(qTbl.color .. ' spawned "' .. scryfallCard.name:gsub('\n.*', '') .. '".', nil, 'info')
                endLoop()
            else -- Spawn deck
                if Deck == 1 then -- initialize deckDat
                    deckDat = {}
                    deckDat = {
                        Transform = {
                            posX = 0,
                            posY = 0,
                            posZ = 0,
                            rotX = 0,
                            rotY = 0,
                            rotZ = 0,
                            scaleX = 1,
                            scaleY = 1,
                            scaleZ = 1
                        },
                        Name = "Deck",
                        Nickname = Player[qTbl.color].steam_name or "Deck",
                        Description = qTbl.full or "Deck",
                        DeckIDs = {},
                        CustomDeck = {},
                        ContainedObjects = {}
                    }
                end
                deckDat.DeckIDs[Deck] = cardDat.CardID -- add card info into deckDat
                deckDat.CustomDeck[n] = cardDat.CustomDeck[n]
                deckDat.ContainedObjects[Deck] = cardDat
                if Deck < qTbl.deck then
                    qTbl.text('Spawning here\n' .. Deck .. ' cards loaded')
                    Deck = Deck + 1
                elseif Deck == qTbl.deck then
                    local spawnDat = {
                        data = deckDat,
                        position = qTbl.position or {0, 2, 0},
                        rotation = Vector(0, Player[qTbl.color].getPointerRotation(), 180)
                    }
                    spawnObjectData(spawnDat)
                    Player[qTbl.color].broadcast('All ' .. Deck .. ' cards loaded!', {0.5, 0.5, 0.5})
                    ttsUtils.testLog(qTbl.color .. ' loaded ' .. Deck .. ' cards.', nil, 'info')
                    Deck = 1
                    endLoop()
                end
            end
        end)
        local cardMetadataStr = 'n: ' .. tostring(this.n) .. ', customImage: ' .. tostring(this.customImage)
        -- if the call to Card fails, print error and reload
        if not success then
            --[[
                ttsUtils.testLog(errorMSG, 'Card() returned an error!', 'error')
                ttsUtils.testLog(cardMetadataStr, nil, 'trace')
            --]]
            printToAll('Something went wrong and the importer crashed, giving the error:', {1, 0, 0})
            printToAll(errorMSG, {0.8, 0, 0})
            printToAll(
                "If you were doing everything you were supposed to, please let Amuzet know on discord or the workshop page (please remember what you typed to get the error, and the error message itself).",
                {0, 1, 1})
            printToAll('Restarting Importer...', {0, 0.5, 1})
            -- destroy all created text items
            for i, o in ipairs(textItems) do
                if o ~= nil then
                    o.destruct()
                end
            end
            self.reload()
        else
            --[[
                ttsUtils.testLog('Card() performed successfully.', nil, 'debug')
                ttsUtils.testLog(cardMetadataStr, nil, 'trace')
            --]]
        end
    end
})

--- Takes a Card object and generates a description that Tabletop Simulator can use.
--- @return string
--- A valid TTS object description that describes this card.
function setOracle(card)
    local str = '\n[b]'
    if card.power then
        str = str .. card.power .. '/' .. card.toughness
    elseif card.loyalty then
        str = str .. tostring(card.loyalty)
    else
        str = false
    end
    return card.oracle_text:gsub('\"', "'") .. (str and str .. '[/b]' or '')
end

--- This function is for performing a batched fetch to Scryfall's /cards/collections API endpoint.
--- If a card is not successfully found by Scryfall, the order of the results will likely be changed.
--- 
---@param batches table
--- A table that is an array of arrays of identifiers. The structure of the object looks roughly like:
--- [ [{id="bcd",name="Arcane Signet"},{id="bcd",name="Arcane Signet"},{id="xyz",name="Gamble"}], [{id="xyz",name="Gamble"},{id="fgh",name="Arcane Signet"}] ]
--- Each batch of Scryfall IDs must have no more than 75 IDs.
---@param callback function
--- A function that is run as soon as the fetch is completed. This function should accept a single table
--- parameter which is an array of tables, each table being a Scryfall card object.
function fetchBatchedScryfallCollection(batches, qTbl, callback, isFallbackBatches)
    if isFallbackBatches == null then isFallbackBatches = false end

    local scryfallCards = {}
    local wrWaits = {}      -- stores WebRequest results, waiting for all to finish
    -- we go through each batch, performing a single WebRequest for each one
    for i, batch in ipairs(batches) do
        local wrWait = { done = false }
        table.insert(wrWaits, wrWait)
        local waitPos = #wrWaits
        Wait.time(function()
            -- perform custom application/json POST request
            qTbl.text('Spawning here\nFetching ' .. (isFallbackBatches and 'fallback ' or '') .. 'batch ' .. i .. '/' .. #batches .. '...')
            local wr = WebRequest.custom('https://api.scryfall.com/cards/collection/', 'POST', true, JSON.encode({identifiers = batch}), { ["Content-Type"] = "application/json", Accept = "application/json" }, function(res)
                -- local text = res.text
                -- ttsUtils.writeNotebook("Scryfall text", text)
                -- print("Received " .. #text .. " characters from Scryfall.")
                local resCards = JSON.decode(res.text)

                if resCards.not_found ~= nil and #resCards.not_found > 0 then
                    local fuzzyList = {}
                    for j, notFoundCard in ipairs(resCards.not_found) do
                        Player[qTbl.color].broadcast(
                            "Scryfall errored trying to find " .. notFoundCard.name .. " (" .. notFoundCard.set:upper() .. ") " .. notFoundCard.collector_number:upper() .. (notFoundCard.foil and " *F*" or "") .. '!' ..
                            "\nWill batch a fallback print...",
                            {1, 0, 0}
                        )
                        table.insert(fuzzyList, notFoundCard)
                    end

                    local fuzzyBatches = utils.batchFromList(fuzzyList, 20, function(item)
                        return { name = item.name }
                    end)

                    local wrWait = { done = false }
                    table.insert(wrWaits, wrWait)
                    local waitPos = #wrWaits
                    fetchBatchedScryfallCollection(fuzzyBatches, qTbl, function(fuzzyScryfallCards)
                        for j, card in ipairs(fuzzyScryfallCards) do
                            -- insert the fuzzy cards at the front of the card list
                            -- so that it spawns at the top, and doesn't block a commander
                            table.insert(scryfallCards, 1, card)
                        end
                        wrWait.done = true
                    end, true)
                end

                -- insert all cards that returned successfully
                for j, resCard in ipairs(resCards.data) do
                    table.insert(scryfallCards, resCard)
                end

                wrWait.done = true
            end)
        end, waitPos * Tick * 2)
    end

    local waitId = nil
    local co = coroutine.create(function()
        -- this coroutine yields over and over again until all wrWaits announce that they're done
        local wrWaitsDone = false
        while not wrWaitsDone do
            wrWaitsDone = true
            for i, wrWait in ipairs(wrWaits) do
                if not wrWait.done then wrWaitsDone = false end
            end
            coroutine.yield()
        end
        Wait.stop(waitId)

        if callback ~= nil then callback(scryfallCards) end
    end)
    -- this Wait will run over and over again until it is abruptly stopped by the end of the coroutine
    waitId = Wait.time(function() coroutine.resume(co) end, 0.01, -1)
end

-- use this function if you have a WebRequest result with Scryfall card data in it
function setCardWr(wr, qTbl, originalData)
    if wr.text then
        local json = JSON.decode(wr.text)
        setCard(json, qTbl, originalData)
    else
        error('No Data Returned Contact Amuzet. setCardWr')
    end
    endLoop()
end

-- use this function if you have decoded JSON Scryfall card data already
function setCard(json, qTbl, originalData)
    if json.object == 'card' then
        -- Fancy Art Series
        if originalData and originalData.layout == 'art_series' then
            for k in ('mana_cost type_line oracle_text colors power toughness loyalty'):gmatch('%S+') do
                for i = 1, 2 do
                    if json.card_faces and json.card_faces[i][k] then
                        originalData.card_faces[i][k] = json.card_faces[i][k]
                    elseif json[k] then
                        originalData.card_faces[i][k] = json[k]
                    end
                end
            end
            for k in ('cmc type_line color_identity layout'):gmatch('%S+') do
                if json[k] then
                    originalData[k] = json[k]
                end
            end
            if json.image_uris then
                originalData.card_faces[2].image_uris = json.image_uris
            else
                originalData.card_faces[2].image_uris = json.card_faces[2].image_uris
            end
        elseif json.layout == 'art_series' then
            WebRequest.get('http://api.scryfall.com/cards/named?fuzzy=' .. json.card_faces[1].name,
                function(request)
                    local locale_json = JSON.decode(request.text)
                    if locale_json.object == 'error' then
                        Card(json, qTbl)
                    else
                        setCardWr(request, qTbl, json)
                    end
                end
            )
        else
            Card(json, qTbl)
        end
        return
    elseif originalData and originalData.name then
        -- decoded card data was not a card, but does have fallback data!
        if json.object == 'error' then
            Player[qTbl.color].broadcast(
                "Scryfall errored trying to find " .. originalData.name .. " (" .. originalData.set:upper() .. ") " .. originalData.cn:upper() .. (originalData.foil and " *F*" or "") .. '!' ..
                "\nNow finding an alternative...",
                {1, 0, 0}
            )
        end
        WebRequest.get('https://api.scryfall.com/cards/named?fuzzy=' .. originalData.name:gsub('%W', ''),
            function(a)
                setCardWr(a, qTbl)
            end)
        return
    elseif json.object == 'error' then
        -- decoded card data is an error object with no fallback data to work with!
        Player[qTbl.color].broadcast(json.details, {1, 0, 0})
        endLoop()
        return
    end
end

function parseForToken(oracle, qTbl)
    endLoop()
end
--[[  if oracle:find('token')and oracle:find('[Cc]reate')then
    --My first attempt to parse oracle text for token info
    local ptcolorType,abilities=oracle:match('[Cc]reate(.+)(token[^\n]*)')
    --Check for power and toughness
    local power,toughness='_','_'
    if ptColorType:find('%d/%d')then
      power,toughness=ptColorType:match('(%d+)/(%d+)')end
    --It wouldn't be able to find treasure or clues
    local colors=''
    for k,v in pairs({w='white',u='blue',b='black',r='red',g='green',c='colorless'})do
     if ptColorType:find(v)then colors=colors..k end end
    --How the heck am I going to do abilities
    if abilities:find('tokens? with ')then
      local abTbl={}
      abilities=abilities:gsub('"([^"]+)"',function(a)
        table.insert(abTbl,a)return''end)
      for _,v in pairs({'haste','first strike','double strike','reach','flying'})do
        if abilities:find(v)then table.insert(abTbl,v)end end
    end
  end
end]]

function spawnList(wr, qTbl)
    ttsUtils.testLog(wr.url)
    local txt = wr.text
    if txt then -- PIE's Rework
        local jsonType = txt:sub(1, 20):match('{"object":"(%w+)"')
        if jsonType == 'list' then
            local nCards = txt:match('"total_cards":(%d+)')
            if nCards ~= nil then
                nCards = tonumber(nCards)
            else
                -- a jsonlist but couldn't find total_cards ? shouldn't happen, but just in case
                textItems[#textItems].destruct()
                table.remove(textItems, #textItems)
                endLoop() -- pieHere, I missed this one too
                return
            end
            if tonumber(nCards) > 100 then
                Player[qTbl.color].broadcast('This search query gives too many results (>100)', {1, 0, 0})
                textItems[#textItems].destruct()
                table.remove(textItems, #textItems)
                endLoop() -- pieHere, I missed this one too
                return
            end
            qTbl.deck = nCards
            local last = 0
            local cards = {}
            for i = 1, nCards do
                start = string.find(txt, '{"object":"card"', last + 1)
                last = findClosingBracket(txt, start)
                local card = JSON.decode(txt:sub(start, last))
                Wait.time(function()
                    Card(card, qTbl)
                end, i * Tick)
            end
            return

        elseif jsonType == 'card' then
            local n, json = 1, JSON.decode(txt)
            Card(json, qTbl)
            return

        elseif jsonType == 'error' then
            local n, json = 1, JSON.decode(txt)
            Player[qTbl.color].broadcast(json.details, {1, 0, 0})
        end
    end
    endLoop()
end

--[[ DeckFormatHandle ]]

local sOver = {
    ['10ED'] = '10E',
    DAR = 'DOM',
    MPS_AKH = 'MP2',
    MPS_KLD = 'MPS',
    FRF_UGIN = 'UGIN'
}
local dFile = {
    uidCheck = ',%w+-%w+-%w+-%w+-%w+',
    uid = function(line)
        local num, uid = string.match('__' .. line .. '__', '__%a+,(%d+).+,([%w%-]+)__')
        return num, 'https://api.scryfall.com/cards/' .. uid
    end,

    dckCheck = '%[[%w_]+:%w+%]',
    dck = function(line)
        local num, set, col, name = line:match('(%d+).%W+([%w_]+):(%w+)%W+(%w.*)')
        local alter = name:match(' #(http%S+)') or false
        name = name:gsub(' #.+', '')
        if set:find('DD3_') then
            set = set:gsub('DD3_', '')
        elseif sOver[set] then
            set = sOver[set]
        end
        set = set:gsub('_.*', ''):lower()
        return num, 'https://api.scryfall.com/cards/' .. set .. '/' .. col, alter
    end,

    decCheck = '%[[%w_]+%]',
    dec = function(line)
        local num, set, name = line:match('(%d+).%W+([%w_]+)%W+(%w.*)')
        if num == nil or name == nil then -- pieHere, avoids that one edge-case error with deckstats decks
            return 0, '', ''
        end
        local num, set, name = line:match('(%d+).%W+([%w_]+)%W+(%w.*)')
        local alter = name:match(' #(http%S+)') or false
        name = name:gsub(' #.+', '')
        if set:find('DD3_') then
            set = set:gsub('DD3_', '')
        elseif sOver[set] then
            set = sOver[set]
        end
        set = set:gsub('_.*', ''):lower()
        return num, 'https://api.scryfall.com/cards/named?fuzzy=' .. name .. '&set=' .. set, alter
    end,

    defCheck = '%d+.%w+',
    def = function(line)
        local num, name = line:match('(%d+).(.*)')
        local alter = name:match(' #(http%S+)') or false
        name = name:gsub(' #.+', '')
        return num, 'https://api.scryfall.com/cards/named?fuzzy=' .. name, alter
    end
}

--[[ Deck Spawning ]]

function spawnDeck(wr, qTbl)
    if wr.text:find('!DOCTYPE') then
        ttsUtils.testLog(wr.url, 'Mal Formated Deck ' .. qTbl.color, 'error')
        ttsUtils.writeNotebook('D' .. qTbl.color, wr.url)
        Player[qTbl.color].broadcast('Your Deck list could not be found\nMake sure the Deck is set to PUBLIC',
            {1, 0.5, 0})
        textItems[#textItems].destruct()
        table.remove(textItems, #textItems)
    else
        ttsUtils.testLog(wr.url, 'Deck Spawned by ' .. qTbl.color, 'debug')
        local sideboard = ''
        qTbl.image = {}
        local deck, list = {}, wr.text:gsub('\n%S*Sideboard(.*)', function(a)
            sideboard = a
            return ''
        end)
        if sideboard ~= '' then
            Player[qTbl.color].broadcast(
                'Extraboards Found and pasted into Notebook\n"Scryfall deck" to spawn most recent Notebook Tab')
            ttsUtils.writeNotebook(qTbl.url, sideboard)
        end

        for b in list:gmatch('([^\r\n]+)') do
            for k, v in pairs(dFile) do
                if type(v) == 'string' and b:find(v) then
                    local n, a, r = dFile[k:sub(1, 3)](b)
                    for i = 1, n do
                        table.insert(deck, a)
                        -- table.insert(qTbl.image,r)
                    end
                    break
                end
            end
        end
        qTbl.deck = #deck

        for i, url in ipairs(deck) do
            Wait.time(function()
                WebRequest.get(url, function(c)
                    setCardWr(c, qTbl)
                end)
            end, i * Tick)
        end
    end
end

function spawnDeckFromScryfall(wr, qTbl)
    local side, deck, list = '', {}, wr.text

    for line in list:gmatch('[^\r\n]+') do
        if ('SideboardMaybeboard'):find(line:match('%w+')) then
            side = side .. convertQuotedValues(line):match('%d+,[^,]+'):gsub(',', ' ') .. '\n'
        elseif line:find(',(%d+),') then
            for i = 1, line:match(',(%d+),') do
                table.insert(deck, line:match('https://scryfall.com/card/([^/]+/[^/]+)'))
            end
        end
    end

    if side ~= '' then
        Player[qTbl.color].broadcast(
            'Sideboard Found and pasted into Notebook\n"Scryfall deck" to spawn most recent Notebook Tab')
        ttsUtils.writeNotebook(qTbl.url, side)
    end

    qTbl.deck = #deck
    for i, u in ipairs(deck) do
        Wait.time(function()
            WebRequest.get('https://api.scryfall.com/cards/' .. u, function(c)

                local t = JSON.decode(c.text)
                if t.object ~= 'card' then
                    WebRequest.get('https://api.scryfall.com/cards/named?fuzzy=blankcard', function(c)
                        setCardWr(c, qTbl)
                    end)
                else
                    setCardWr(c, qTbl)
                end
            end)
        end, i * Tick)
    end

end

setCSV = 4
function spawnCSV(wr, qTbl)
    local side, deck, list = '', {}, wr.text
    for line in list:gmatch('([^\r\n]+)') do
        local tbl, l = {}, ',' .. line:gsub(',("[^"]+"),', function(g)
            return ',' .. g:gsub(',', '') .. ','
        end)
        l = l:gsub(',', ', ')
        for csv in l:gmatch(',([^,]+)') do
            if csv:len() == 1 then
                break
            else
                table.insert(tbl, csv:sub(2))
            end
        end
        if #tbl < setCSV - 1 then
            ttsUtils.testLog(tbl)
            printToAll('Tell Amuzet that an Error occored in spawnCSV:\n' .. qTbl.full)
            endLoop()
            return
        elseif not tbl[2]:find('%d+') then -- FirstCSVLine
        elseif (setCSV == 3) or (setCSV == 4 and tbl[1]:find('main')) or (setCSV == 7 and not tbl[1]:find('board')) then
            local b = 'https://api.scryfall.com/cards/named?fuzzy=' .. tbl[3]
            if tbl[setCSV] and tbl[setCSV] ~= '000' then
                b = b .. '&set=' .. tbl[setCSV]
            end
            for i = 1, tbl[2] do
                table.insert(deck, b)
            end
        else -- Side/Maybe
            side = side .. tbl[2] .. ' ' .. tbl[3] .. '\n'
            ttsUtils.testLog(side)
        end
    end
    if side ~= '' then
        Player[qTbl.color].broadcast(
            'Sideboard Found and pasted into Notebook\n"Scryfall deck" to spawn most recent Notebook Tab')
        ttsUtils.writeNotebook(qTbl.url, side)
    end
    qTbl.deck = #deck
    for i, u in ipairs(deck) do
        Wait.time(function()
            WebRequest.get(u, function(c)
                local t = JSON.decode(c.text)
                if t.object ~= 'card' then
                    if u:find('&') then
                        WebRequest.get(u:gsub('&.+', ''), function(c)
                            setCardWr(c, qTbl)
                        end)
                    else
                        WebRequest.get('https://api.scryfall.com/cards/named?fuzzy=blankcard', function(c)
                            setCardWr(c, qTbl)
                        end)
                    end
                else
                    setCardWr(c, qTbl)
                end
            end)
        end, i * Tick)
    end
end

local DeckHandlers = {
    moxfield = function(a)
        local urlSuffix = a:match("moxfield%.com/decks/(.*)")
        local deckID = urlSuffix:match("([^%s%?/$]*)")
        -- local url = "https://api.moxfield.com/v2/decks/all/" .. deckID .. "/"
        -- TODO: This is a temporary proxy address for Moxfield calls until we create a better, TTS-oriented system
        local url = "https://us-central1-fresh-entity-248003.cloudfunctions.net/moxfield-proxy?q=/v2/decks/all/" .. deckID .. "/"
        return url, function(wr, qTbl)

            qTbl.text('Spawning here\nFetching list from Moxfield...')
            ttsUtils.writeNotebook("wr.text", wr.text)
            local deckName = wr.text:match('"name":"(.-)","description"'):gsub('(\\u....)', ''):gsub('%W', '')
            local startInd = 1
            local endInd
            local keepGoing = true
            local moxfieldCards = {}
            n = 0
            while keepGoing do
                n = n + 1
                startInd = wr.text:find('{"quantity":', startInd)
                if startInd == nil then
                    keepGoing = false
                    break
                end
                endInd = findClosingBracket(wr.text, startInd)
                if endInd == nil then
                    keepGoing = false
                    break
                end
                local cardSnip = wr.text:sub(startInd, endInd)
                local scryfallCard = JSON.decode(cardSnip)
                if scryfallCard.printingData then
                    for i, printingDat in ipairs(scryfallCard.printingData) do
                        card = {
                            quantity = printingDat.quantity,
                            boardType = scryfallCard.boardType,
                            scryfall_id = printingDat.card.scryfall_id,
                            name = printingDat.card.name:gsub('(\\u....)', ''),
                            set = printingDat.card.set,
                            cn = printingDat.card.cn,
                            foil = printingDat.card.foil
                        }
                        table.insert(moxfieldCards, card)
                    end
                else
                    card = {
                        quantity = scryfallCard.quantity,
                        boardType = scryfallCard.boardType,
                        scryfall_id = scryfallCard.card.scryfall_id,
                        name = scryfallCard.card.name:gsub('(\\u....)', ''),
                        set = scryfallCard.card.set,
                        cn = scryfallCard.card.cn,
                        foil = scryfallCard.card.foil
                    }
                    table.insert(moxfieldCards, card)
                end
                startInd = endInd + 1
            end

            qTbl.text('Spawning here\nListing Moxfield results...')
            local sideboard = ''
            qTbl.deck = 0
            local list = {}
            local mapIdToOriginalData = {}
            for i, card in ipairs(moxfieldCards) do
                if card.boardType == 'sideboard' or card.boardType == 'maybeboard' then
                    -- set aside sideboard and maybeboard cards
                    sideboard = sideboard .. card.quantity .. ' ' .. card.name .. '\n'
                elseif card.boardType == 'mainboard' or card.boardType == 'commanders' or card.boardType == 'companions' then
                    for i = 1, card.quantity do
                        table.insert(list, card)
                        -- hold on to a map of Scryfall IDs to Moxfield results for later
                        mapIdToOriginalData[card.scryfall_id] = card
                        qTbl.deck = qTbl.deck + 1
                    end
                end
            end

            qTbl.text('Spawning here\nBatching Moxfield results...')
            local batches = utils.batchFromList(list, 20, function(item)
                return {
                    id = item.scryfall_id,
                    name = item.name,
                    set = item.set,
                    collector_number = item.cn,
                    foil = item.foil
                }
            end)

            qTbl.text('Spawning here\nFetching cards from Scryfall...')
            -- fetch the complete scryfall collection using the batches of ids
            fetchBatchedScryfallCollection(batches, qTbl, function(scryfallCards)
                local waitId = nil
                local done = false
                local co = coroutine.create(function()
                    -- load each scryfall card into the game, yielding for each card
                    for i, card in ipairs(scryfallCards) do
                        setCard(card, qTbl, mapIdToOriginalData[card.id])
                        coroutine.yield()
                    end
                    Wait.stop(waitId)
                    done = true
                end)
                waitId = Wait.time(function() coroutine.resume(co) end, 0.01, -1)
            end)

            if sideboard ~= '' then
                Player[qTbl.color].broadcast(deckName .. ' Sideboard and Maybeboard in notebook.\nType "Scryfall deck" to spawn it now.')
                ttsUtils.writeNotebook(deckName .. " SBs and Maybes", sideboard)
            end
        end
    end,
    deckstats = function(a)
        return a:gsub('%?cb=%d.+', '') .. '?include_comments=1&export_txt=1', spawnDeck
    end,
    pastebin = function(a)
        return a:gsub('com/', 'com/raw/'), spawnDeck
    end,
    mtgdecks = function(a)
        return a .. '/dec', spawnDeck
    end,
    deckbox = function(a)
        return a .. '/export', function(r, qTbl)
            local wr = {
                url = r.url
            }
            wr.text = r.text:match('%Wbody%W(.+)%W%Wbody%W'):gsub('<br.?>', '\n')
            spawnDeck(wr, qTbl)
        end
    end,
    -- scryfall=function(a)return'https://api.scryfall.com'..a:match('(/decks/.*)')..'/export/text',spawnDeck end,
    scryfall = function(a)
        -- TODO: something breaks all the way inside of the Card() call when attempting to load decks through Scryfall directly...
        setCSV = 7
        return 'https://api.scryfall.com' .. a:match('(/decks/.*)') .. '/export/csv', spawnDeckFromScryfall
    end,
    -- https://tappedout.net/users/i_am_moonman/lists/15-11-20-temp-cube/?cat=type&sort=&fmt=csv
    tappedout = function(a)
        if a:find('/lists/') then
            setCSV = 3
        else
            setCSV = 4
        end
        return a:gsub('.cb=%d+', '') .. '?fmt=csv', spawnCSV
    end,
    -- A function which returns a url and function which handels that url's output
    mtggoldfish = function(a)
        if a:find('/archetype/') then
            return a, function(wr, qTbl)
                Player[qTbl.color].broadcast('This is an Archtype!\nPlease spawn a User made Deck.', {0.9, 0.1, 0.1})
                endLoop()
            end
        elseif a:find('/deck/') then
            return a:gsub('/deck/', '/deck/download/'):gsub('#.+', ''), spawnDeck
        else
            return a, function(wr, qTbl)
                Player[qTbl.color].broadcast('This MTGgoldfish url is malformated.\nOr unsupported contact Amuzet.')
            end
        end
    end,
    archidekt = function(a)
        return 'https://archidekt.com/api/decks/' .. a:match('/(%d+)') .. '/small/?format=json', function(wr, qTbl)
            qTbl.deck = 0
            local json = wr.text
            json = JSON.decode(json)
            local board = ''
            for _, v in pairs(json.cards) do
                for i = 1, v.quantity do
                    qTbl.deck = qTbl.deck + 1
                    Wait.time(function()
                        WebRequest.get('https://api.scryfall.com/cards/' .. v.card.uid, function(c)
                            setCardWr(c, qTbl)
                        end)
                    end, qTbl.deck * Tick * 2)
                end
            end
            if board ~= '' then
                Player[qTbl.color].broadcast(json.name ..
                                                 ' Sideboard and Maybeboard in notebook.\nType "Scryfall deck" to spawn it now.')
                ttsUtils.writeNotebook(json.name, board)
            end
        end
    end,
    cubecobra = function(a)
        return a:gsub('list', 'download/csv') .. '?showother=false', function(wr, qTbl)
            local cube, list = {}, wr.text:gsub('[^\r\n]+', '', 1)
            if not qTbl.image or type(qTbl.image) ~= 'table' then
                qTbl.image = {}
            end
            local c = 0
            for line in list:gmatch('([^\r\n]+)') do
                local tbl, n, l = {}, 0, line:gsub('.-"', '', 2)
                -- Grab all non-empty strings surrounded by quotes, will include set and cn
                for obj in line:gmatch('([^"]+)') do
                    table.insert(tbl, obj)
                end
                -- Only include cards that aren't on the maybeboard
                if line:match(',false,') then
                    local b = 'https://api.scryfall.com/cards/' .. tbl[5] .. '/' .. tbl[7]
                    c = c + 1
                    if tbl[9]:match('http') then
                        qTbl.image[c] = tbl[9]
                    end
                    Wait.time(function()
                        WebRequest.get(b, function(c)
                            setCardWr(c, qTbl)
                        end)
                    end, c * Tick)
                end
            end
            qTbl.deck = c
        end
    end
}

-- [[ Boosters / Pack Spawning ]]

local apiRnd = 'http://api.scryfall.com/cards/random?q='
local apiSet = apiRnd .. 'is:booster+s:'
function rarity(m, r, u)
    if math.random(1, m or 36) == 1 then
        return 'r:mythic'
    elseif math.random(1, r or 8) == 1 then
        return 'r:rare'
    elseif math.random(1, u or 4) == 1 then
        return 'r:uncommon'
    else
        return 'r:common'
    end
end
function typeCo(p, t)
    local n = math.random(#p - 1, #p)
    for i = 13, #p do
        if n == i then
            p[i] = p[i] .. '+' .. t
        else
            p[i] = p[i] .. '+-(' .. t .. ')'
        end
    end
    return p
end
local Booster = setmetatable({
    dom = function(p)
        return typeCo(p, 't:legendary')
    end,
    war = function(p)
        return typeCo(p, 't:planeswalker')
    end,
    znr = function(p)
        return typeCo(p, 't:land+is:mdfc')
    end,
    tsp = 'tsb',
    mb1 = 'fmb1',
    mh2 = 'h1r',
    stx = 'sta', -- Garenteed
    bfz = 'exp',
    ogw = 'exp',
    kld = 'mps',
    aer = 'mps',
    akh = 'mp2',
    hou = 'mp2',
    bro = 'brr' -- Masterpiece
}, {
    __call = function(t, set, n)
        local pack, u = {}, apiSet .. set .. '+'
        u = u:gsub('%+s:%(', '+(')
        if not n and t[set] and type(t[set]) == 'function' then
            return t[set](t(set, true))
        else
            for c in ('wubrg'):gmatch('.') do
                table.insert(pack, u .. 'r:common+c>=' .. c)
            end
            for i = 1, 6 do
                table.insert(pack, u .. 'r:common+-t:basic')
            end
            -- masterpiece math replaces 11th Common
            if not n and ((t[set] and math.random(1, 144) == 1) or ('tsp mb1 mh2 sta'):find(set)) then
                pack[#pack] = apiSet .. t[set]
            end
            for i = 1, 3 do
                table.insert(pack, u .. 'r:uncommon')
            end
            table.insert(pack, u .. rarity(8, 1))
            return pack
        end
    end
})
-- ReplacementSlot
function rSlot(p, s, a, b)
    for i, v in pairs(p) do
        if i ~= 6 then
            p[i] = v .. a
        else
            p[i] = apiSet .. s .. '+' .. rarity() .. b
        end
    end
    return p
end
-- Weird Boosters
Booster['tsr'] = function(p)
    p[11] = p[9]:gsub('is:booster+r:common', 'r:special')
    return p
end
Booster['unf'] = function(p)
    local j = rSlot(p, 'unf', '+-t:Attraction', '+t:Attraction')
    table.insert(j, j[6])
    return j
end
Booster['ust'] = function(p)
    local j = rSlot(p, 'ust', '+-t:Contraption', '+t:Contraption')
    table.insert(j, j[6])
    return j
end
for s in ('clb cmr'):gmatch('%S+') do
    Booster[s] = function(p) -- wubrg CCCCC CCUUU URLLF
        local u = apiSet .. s .. '+t:legendary+' -- L
        p[#p] = p[#p] .. '+-t:legendary'
        table.insert(p, 12, p[12])
        table.insert(p, 6, p[6])
        table.insert(p, u .. rarity(8, 1))
        table.insert(p, u .. rarity(8, 1))
        table.insert(p, apiSet .. s .. '+is:etched')
        printToAll('20 Card Booster, draft two each pick')
        return p
    end
end
for s in ('2xm 2x2'):gmatch('%S+') do
    Booster[s] = function(p)
        p[11] = p[12];
        table.insert(p, apiSet .. s .. '+' .. rarity(8, 1))
        return p
    end
end
-- Booster['2xm']=function(p)p[11]=p[#p]for i=9,10 do p[i]=apiSet..'2xm'..'+'..rarity()end return p end
for s in ('isd dka soi emn'):gmatch('%S+') do
    Booster[s] = function(p)
        return rSlot(p, s, '+-is:transform', '+is:transform')
    end
end
for s in ('mid vow'):gmatch('%S+') do -- Crimson Moon
    Booster[s] = function(p)
        local n = math.random(#p - 1, #p)
        for i, v in pairs(p) do
            if i == 6 or i == n then
                p[i] = p[i] .. '+is:transform'
            else
                p[i] = p[i] .. '+-is:transform'
            end
        end
        return p
    end
end
for s in ('cns cn2'):gmatch('%S+') do
    Booster[s] = function(p)
        return rSlot(p, s, '+-wm:conspiracy', '+wm:conspiracy')
    end
end
for s in ('rav gpt dis rtr gtc dgm grn rna'):gmatch('%S+') do
    Booster[s] = function(p)
        return rSlot(p, s, '+-t:land', '+t:land+-t:basic')
    end
end
for s in ('ice all csp mh1 khm'):gmatch('%S+') do
    Booster[s] = function(p)
        p[6] = apiSet .. s .. '+t:basic+t:snow'
        return p
    end
end
-- wubrg CCCCC CUUUR LLYUF
Booster['cmm'] = function(p)
    for i = 12, 15 do
        p[i] = p[i] .. '+-t:legendary'
    end
    local sL = apiSet .. 'cmm+t:legendary'
    -- 2 Legendaries
    table.insert(p, sL)
    table.insert(p, sL)
    -- 1 Rare+ Legendary
    table.insert(p, sL .. '+' .. rarity(8, 1))
    -- 1 more Uncommon
    table.insert(p, apiSet .. 'cmm+r:uncommon+-t:legendary')
    -- 1 any Foil
    table.insert(p, apiSet .. 'cmm+' .. rarity())
    -- 20 Total
    return p
end

-- Custom Booster Packs
Booster.CMMDRAFT = function(qTbl)
    return Booster('cmm', true)
end
Booster.ADAMS = function(qTbl)
    local pack, u = {}, 'http://api.scryfall.com/cards/random?q=f:standard+'
    for c in ('wubrg'):gmatch('.') do
        table.insert(pack, u .. 'r:common+c:' .. c)
    end
    for i = 1, 5 do
        table.insert(pack, u .. 'r:common+-t:basic')
    end
    for i = 1, 3 do
        table.insert(pack, u .. 'r:uncommon')
    end
    table.insert(pack, u .. rarity(8, 1))
    table.insert(pack, u .. 't:basic')
    table.insert(pack, u:sub(1, 39) .. '(border:borderless+or+frame:showcase+or+set:plist)')
    if math.random(1, 2) == 1 then
        pack[#pack - 1] = pack[#pack]
    end
    return pack
end
Booster.STANDARD = function(qTbl)
    local pack, u = {}, 'http://api.scryfall.com/cards/random?q=f:standard+'
    for c in ('wubrg'):gmatch('.') do
        table.insert(pack, u .. 'r:common+c:' .. c)
    end
    for i = 1, 5 do
        table.insert(pack, u .. 'r:common+-t:basic')
    end
    for i = 1, 3 do
        table.insert(pack, u .. 'r:uncommon')
    end
    table.insert(pack, u .. rarity(8, 1))
    table.insert(pack, u .. 't:basic')
    table.insert(pack, u:sub(1, 39) .. '(border:borderless+or+frame:showcase+or+set:plist)')
    if math.random(1, 2) == 1 then
        pack[#pack - 1] = pack[#pack]
    end
    return pack
end
Booster.MANAMARKET = function(qTbl)
    local pack, u = {}, 'http://api.scryfall.com/cards/random?q=f:standard+'
    for c in ('wubrg'):gmatch('.') do
        table.insert(pack, u .. 'r:common+c:' .. c)
    end
    for i = 1, 5 do
        table.insert(pack, u .. 'r:common+-t:basic')
    end
    for i = 1, 3 do
        table.insert(pack, u .. 'r:uncommon')
    end
    table.insert(pack, u .. rarity(8, 1))
    table.insert(pack, u .. 't:basic')
    table.insert(pack, u:sub(1, 39) ..
        '(set:tafr+or+set:tstx+or+set:tkhm+or+set:tznr+or+set:sznr+or+set:tm21+or+set:tiko+or+set:tthb+or+set:teld)')
    for i = #pack - 1, #pack do
        if math.random(1, 2) == 1 then
            pack[i] = u .. '(border:borderless+or+frame:showcase+or+frame:extendedart+or+set:plist+or+set:sta)'
        end
    end
    return pack
end
Booster.PLANAR = function(qTbl)
    -- ((t:plane or t:phenomenon) o:planeswalk) or
    local u = 'http://api.scryfall.com/cards/random?q='
    local additional = "+or+o:'planar+di'+or+o:'will+of+the+planeswalker'"

    local pack = {u .. 'frame:2015+c=w', u .. 'frame:2015+c=u', u .. 'frame:2015+c=b', u .. 'frame:2015+c=r',
                  u .. 'frame:2015+c=g', u .. 'frame:2015+c=c', u .. 'frame:2015+c>1', u .. 'frame:2015+c<2+id>1',
                  u .. 'frame:2015+-is:permanent', u .. 'frame:2015+-t:creature' .. additional,
    -- u..'frame:2015+is:french_vanilla',
    -- u..'is:vanilla',
                  u .. 't:planeswalker', u .. '(t:plane+or+t:phenomenon)' .. additional,
                  u .. '((t:plane+or+t:phenomenon)+o:planeswalk)', u .. '((t:plane+or+t:phenomenon)+-o:planeswalk)',
                  u .. '(t:plane+or+t:phenomenon)', u .. 'frame:2015'}

    return pack
end
-- PLANES
Booster.CONSPIRACY = function(qTbl) -- wubrgCCCCCTUUURT
    local p = Booster('(s:cns+or+s:cn2)')
    local z = p[#p]:gsub('r:%S+', rarity(9, 6, 3))
    table.insert(p, z)
    p[6] = p[math.random(10, 12)]
    for i, s in pairs(p) do
        if i == 6 or i == #p then
            p[i] = p[i] .. '+wm:conspiracy'
        else
            p[i] = p[i] .. '+-wm:conspiracy'
        end
    end
    return p
end
Booster.INNISTRAD = function(qTbl) -- wubrgDCCCCDUUURD
    local p = Booster('(s:isd+or+s:dka+or+s:avr+or+s:soi+or+s:emn+or+s:mid+s:vow)')
    local z = p[#p]:gsub('r:%S+', rarity(8, 1))
    table.insert(p, z)
    p[11] = p[12]
    for i, s in pairs(p) do
        if i == 6 or i == 11 or i == #p then
            p[i] = p[i] .. '+is:transform'
        else
            p[i] = p[i] .. '+-is:transform'
        end
    end
    return p
end
Booster.RAVNICA = function(qTbl) -- wubrgmmm???UUURL
    local l, p = 't:land+-t:basic', Booster('(s:rav+or+s:gpt+or+s:dis+or+s:rtr+or+s:gtc+or+s:dgm+or+s:grn+or+s:rna)')
    table.insert(p, p[#p])
    for i = 6, 8 do
        p[i] = p[8] .. '+id>=2'
    end
    for i = 9, math.random(9, 11) do
        p[i] = p[11] .. '+id<=1'
    end
    for i, s in pairs(p) do
        if i == #p then
            p[i] = p[i]:gsub('r:%S+', rarity(9, 6, 3)) .. '+' .. l
        else
            p[i] = p[i] .. '+-' .. l
        end
    end
    return p
end
Booster.KAMIGAWA = function(qTbl) -- wubrgCCCCCCUUURN
    local p = Booster('(s:chk+or+s:bok+or+s:sok+or+s:neo)')
    local z = p[#p]:gsub('r:%S+', rarity(8, 4, 1) .. '+t:legendary')
    table.insert(p, z)
    -- {'t:creature','t:creature','-t:creature','t:equipment','t:artifact -t:equipment','(t:saga or t:shrine or t:aura)','t:enchantment -(t:saga or t:shrine or t:aura)'}
    return p
end
Booster.MIRRODIN = function(qTbl)
    local p = Booster('(s:mrd+or+s:dst+or+s:5dn+or+s:som+or+s:mbs+or+s:nph)')
    return p
end
Booster.PHYREXIA = function(qTbl)
    local p = Booster.MIRRODIN(qTbl)
    table.insert(p, p[#p])
    p[11] = p[12]
    local s =
        '(wm:phyrexian+or+ft:phyrex+or+phyrex+or+yawgmoth+or+is:phyrexian+or+ft:yawgmoth+or+art:phyrexian)+(is:spell+or+t:land)'
    for _, i in pairs({6, 11, #p}) do
        p[i] = p[i]:gsub('%b()', s)
    end
    return p
end
Booster.ZENDIKAR = function(qTbl)
    local p = Booster('(s:zen+or+s:wwk+or+s:roe+or+s:bfz+or+s:ogw+or+s:znr)')
    -- Masterpiece
    local mSlot = '(s:exp+or+s:zne)'
    if math.random(144) ~= 1 then
        p[6] = p[6]:gsub('%(.+', mSlot)
    end
    return p
end
Booster.HELP = function(qTbl)
    local s = ''
    for k, _ in pairs(Booster) do
        if k == k:upper() then
            s = s .. '[i][ff7700]' .. k .. '[/i] , '
        end
    end
    -- NotWorking[b][0077ff]Scryfall booster[/b] [i](t:artifact)[/i]  [-][Spawn a Booster with all cards matching that search querry, in this case only Artifacts]
    Player[qTbl.color].broadcast([[
[b][0077ff]Scryfall booster[/b] [i]xln[/i]  [-][Spawns Ixalan Booster]
[b][0077ff]Scryfall booster[/b] [i]SET[/i]  [-][Spawns a Booster with that [i]SET[/i] code as defined by Scryfall.com]

[b]Custom Masters Packs[/b] [The following list are Double Master like packs made by Amuzet and friends]
 > ]] .. s)
    return Booster('plist')
end

function spawnPack(qTbl, pack)
    qTbl.deck = #pack
    qTbl.mode = 'Deck'
    log(pack)
    -- TODO: prevent dups, divert to a seperate function before setCardWr()
    for i, u in pairs(pack) do
        Wait.time(function()
            WebRequest.get(u, function(wr)
                if wr.text:find('object:"error"') then
                    log(u)
                end
                -- Divert here
                setCardWr(wr, qTbl)
            end)
        end, i * Tick)
    end
    -- Store the returned pack check for dups
    -- Rerun pack if dups 3 of same or more than a pair
    -- Exclude Multiverse ID
end

--[[ Importer Data Structure ]]

--- The Importer is an object that represents card import actions being performed.
--- Importer can be called to perform an import task according to one of its various available functions.
Importer = setmetatable({
    -- Variables
    request = {},

    -- Functions
    Search = function(qTbl)
        WebRequest.get('https://api.scryfall.com/cards/search?q=' .. qTbl.name, function(wr)
            spawnList(wr, qTbl)
        end)
    end,

    Back = function(qTbl)
        if qTbl.target then
            qTbl.url = qTbl.target.getJSON():match('BackURL": "([^"]*)"')
        end
        Back[qTbl.player] = qTbl.url
        Player[qTbl.color].broadcast('Card Backs set to\n' .. qTbl.url, {0.9, 0.9, 0.9})
        endLoop()
    end,

    Spawn = function(qTbl)
        WebRequest.get('https://api.scryfall.com/cards/named?fuzzy=' .. qTbl.name, function(wr)
            local obj = JSON.decode(wr.text)
            if obj.object == 'card' and obj.type_line:match('Token') then
                WebRequest.get('https://api.scryfall.com/cards/search?unique=card&q=t%3Atoken+' ..
                                   qTbl.name:gsub(' ', '%%20'), function(wr)
                    spawnList(wr, qTbl)
                end)
                return false
            else
                setCardWr(wr, qTbl)
            end
        end)
    end,

    Token = function(qTbl)
        WebRequest.get('https://api.scryfall.com/cards/named?fuzzy=' .. qTbl.name, function(wr)
            local json = JSON.decode(wr.text)
            if json.all_parts then
                qTbl.deck = #json.all_parts - 1
                for _, v in ipairs(json.all_parts) do
                    if json.name ~= v.name then
                        WebRequest.get(v.uri, function(wr)
                            setCardWr(wr, qTbl)
                        end)
                    end
                end
                -- What is this elseif json.oracle
            elseif json.object == 'card' then
                local oracle = json.oracle_text
                if json.card_faces then
                    for _, f in ipairs(json.card_faces) do
                        oracle = oracle .. json.name:gsub('"', '\'') .. '\n' .. setOracle(f)
                    end
                end
                parseForToken(oracle, qTbl)
            elseif qTbl.target then
                local o = qTbl.target.getDescription()
                if o:find('[Cc]reate') or o:find('emblem') then
                    parseForToken(o, qTbl)
                else
                    Player[qTbl.color].broadcast('Card not found in Scryfall\nAnd did not have oracle text to parse.',
                        {0.9, 0.9, 0.9})
                    endLoop()
                end
            else
                Player[qTbl.color].broadcast('No Tokens Found', {0.9, 0.9, 0.9})
                endLoop()
            end
        end)
    end,

    Print = function(qTbl)
        local url, n = 'https://api.scryfall.com/cards/search?unique=prints&q=',
            qTbl.name:lower():gsub('%s', ''):gsub('%%20', '') -- pieHere, making search with spaces possible
        if ('plains island swamp mountain forest'):find(n) then
            -- url=url:gsub('prints','art')end
            broadcastToAll(
                'Please Do NOT print Basics\nIf you would like a specific Basic specify that in your decklist\nor Spawn it using "Scryfall island&set=kld" the corresponding setcode',
                {0.9, 0.9, 0.9})
            endLoop()
        else
            if qTbl.oracleid ~= nil then
                WebRequest.get(url .. qTbl.oracleid, function(wr)
                    spawnList(wr, qTbl)
                end)
            else
                WebRequest.get(url .. qTbl.name, function(wr)
                    spawnList(wr, qTbl)
                end)
            end
        end
    end,

    Legalities = function(qTbl)
        WebRequest.get('http://api.scryfall.com/cards/named?fuzzy=' .. qTbl.name, function(wr)
            for f, l in pairs(JSON.decode(wr.text:match('"legalities":({[^}]+})'))) do
                printToAll(l .. ' in ' .. f)
            end
            endLoop()
        end)
    end,

    Legal = function(qTbl)
        WebRequest.get('http://api.scryfall.com/cards/named?fuzzy=' .. qTbl.name, function(wr)
            local n, s, t = '', '', JSON.decode(wr.text:match('"legalities":({[^}]+})'))
            for f, l in pairs(t) do
                if l == 'legal' and s == '' then
                    s = '[11ff11]' .. f:sub(1, 1):upper() .. f:sub(2) .. ' Legal'
                elseif l == 'not_legal' and s ~= '' then
                    if n == '' then
                        n = 'Not Legal in:'
                    end
                    n = n .. ' ' .. f
                end
            end

            if s == '' then
                s = '[ff1111]Banned'
            else
                local b = ''
                for f, l in pairs(t) do
                    if l == 'banned' then
                        b = b .. ' ' .. f
                    end
                end
                if b ~= '' then
                    s = s .. '[-]\n[ff1111]Banned in:' .. b
                end
            end

            local r = ''
            for f, l in pairs(t) do
                if l == 'restricted' then
                    r = r .. ' ' .. f
                end
            end
            if r ~= '' then
                s = s .. '[-]\n[ffff11]Restricted in:' .. r
            end
            printToAll('Legalities:' .. qTbl.full:match('%s.*') .. '\n' .. s, {1, 1, 1})
            endLoop()
        end)
    end,

    Text = function(qTbl)
        WebRequest.get('https://api.scryfall.com/cards/named?format=text&fuzzy=' .. qTbl.name, function(wr)
            if qTbl.target then
                qTbl.target.setDescription(wr.text)
            else
                Player[qTbl.color].broadcast(wr.text)
            end
            endLoop()
        end)
    end,

    Rules = function(qTbl)
        WebRequest.get('https://api.scryfall.com/cards/named?fuzzy=' .. qTbl.name, function(wr)
            local cardDat = JSON.decode(wr.text)
            if cardDat.object == "error" then
                broadcastToAll(cardDat.details, {0.9, 0.9, 0.9})
                endLoop()
            elseif cardDat.object == "card" then
                WebRequest.get(cardDat.rulings_uri, function(wr)
                    local data, text = JSON.decode(wr.text), '[00cc88]'
                    if data.object == 'list' then
                        data = data.data
                    end
                    if data ~= nil and data[1] then
                        for _, v in pairs(data) do
                            text = text .. v.published_at .. '[-]\n[ff7700]' .. v.comment .. '[-][00cc88]\n'
                        end
                    else
                        text = 'No Rulings'
                    end
                    if text:len() > 1000 then
                        ttsUtils.writeNotebook(cardDat.name, text)
                        broadcastToAll('Rulings are too long!\nFull rulings can be found in the Notebook',
                            {0.9, 0.9, 0.9})
                    elseif qTbl.target then
                        qTbl.target.setDescription(text)
                    else
                        broadcastToAll(text, {0.9, 0.9, 0.9})
                    end
                    endLoop()
                end)
            end
        end)
    end,

    Mystery = function(qTbl)
        local t, url = {}, 'http://api.scryfall.com/cards/random?q=set:mb1+'
        for _, r in pairs({'common', 'uncommon'}) do
            for _, c in pairs({'w', 'u', 'b', 'r', 'g'}) do
                table.insert(t, url .. ('r:%s+c:%s+id:%s'):format(r, c, c))
            end
        end
        table.insert(t, url .. 'c:c+-r:rare+-r:mythic')
        table.insert(t, url .. 'c:m+-r:rare+-r:mythic')
        table.insert(t, url .. '(r:rare+or+r:mythic)+frame:2015')
        table.insert(t, url .. '(r:rare+or+r:mythic)+-frame:2015')
        local fSlot = {'http://api.scryfall.com/cards/random?q=set:cmb1',
                       'http://api.scryfall.com/cards/random?q=set:fmb1'}

        qTbl.url = 'Mystery Booster'
        if qTbl.name:find('playtest') then
            qTbl.url = 'Playtest Booster'
            table.insert(t, fSlot[1])
        elseif qTbl.name:find('both') then
            table.insert(t, fSlot[math.random(1, 2)])
        else
            table.insert(t, fSlot[2])
        end

        qTbl.deck = #t
        qTbl.mode = 'Deck'
        for i, u in pairs(t) do
            Wait.time(function()
                WebRequest.get(u, function(wr)
                    setCardWr(wr, qTbl)
                end)
            end, i * Tick)
        end
    end,

    Booster = function(qTbl)
        qTbl.url = 'Booster ' .. qTbl.name
        if Booster[qTbl.name:upper()] then
            spawnPack(qTbl, Booster[qTbl.name:upper()](qTbl))

        elseif #qTbl.name < 5 then
            if qTbl.name == '' then
                qTbl.name = 'ori'
            end
            WebRequest.get('https://api.scryfall.com/sets/' .. qTbl.name, function(w)
                local j = JSON.decode(w.text)
                if j.object == 'set' then
                    qTbl.url = 'Booster ' .. j.name
                    spawnPack(qTbl, Booster(qTbl.name))
                else
                    Player[qTbl.color].broadcast(j.details, {1, 0, 0})
                    endLoop()
                end
            end)

        elseif qTbl.name:find('%W') then
            Player[qTbl.color].broadcast('Attempting custom Booster:\n ' .. qTbl.name)
            if qTbl.name:find('^%(') then
            else
                qTbl.name = '(' .. qTbl.name .. ')'
            end
            spawnPack(qTbl, Booster(qTbl.name))
        else
            Player[qTbl.color].broadcast('No Booster found to make')
            endLoop()
        end
    end,

    Random = function(qTbl)
        local url, q1 = 'https://api.scryfall.com/cards/random', '?q=is:hires'
        if qTbl.name:find('q=') then
            url = url .. qTbl.full:match('%s(%S+)')
        else
            for _, tbl in ipairs({{
                w = 'c%3Aw',
                u = 'c%3Au',
                b = 'c%3Ab',
                r = 'c%3Ar',
                g = 'c%3Ag'
            }, {
                i = 't%3Ainstant',
                s = 't%3Asorcery',
                e = 't%3Aenchantment',
                c = 't%3Acreature',
                a = 't%3Aartifact',
                l = 't%3Aland',
                p = 't%Aplaneswalker'
            }}) do
                local t, q2 = 0, ''
                for k, m in pairs(tbl) do
                    if string.match(qTbl.name:lower(), k) then
                        if t == 1 then
                            q2 = '(' .. q2
                        end
                        if t > 0 then
                            q2 = q2 .. 'or+'
                        end
                        t, q2 = t + 1, q2 .. m .. '+'
                    end
                end
                if t > 1 then
                    q2 = q2 .. ')+'
                end
                q1 = q1 .. q2
            end
            local tst, cmc = qTbl.full:match('([=<>]+)(%d+)')
            if tst then
                q1 = q1 .. 'cmc' .. tst .. cmc
            end
            if q1 ~= '?q=' then
                url = url .. (q1 .. ' '):gsub('%+ ', ''):gsub(' ', '')
            end
        end
        ttsUtils.testLog(url, qTbl.color .. ' Importer ' .. qTbl.full)
        local n = tonumber(qTbl.full:match('%s(%d+)'))
        if n then
            qTbl.deck = n
            for i = 1, n do
                Wait.time(function()
                    WebRequest.get(url, function(wr)
                        setCardWr(wr, qTbl)
                    end)
                end, i * Tick)
            end
        else
            WebRequest.get(url, function(wr)
                setCardWr(wr, qTbl)
            end)
        end
    end,

    Quality = function(qTbl)
        if ('small normal large art_crop border_crop'):find(qTbl.name) then
            Quality[qTbl.player] = qTbl.name
        end
        endLoop()
    end,

    Lang = function(qTbl)
        LANG = qTbl.name
        if LANG and LANG ~= '' then
            p.print('Change the language to ' .. LANG, {0.9, 0.9, 0.9})
            return false
        else
            p.print('Please type specific language', {0.9, 0.9, 0.9})
            return false
        end
        endLoop()
    end,

    Deck = function(qTbl)
        if qTbl.url then
            for k, v in pairs(DeckHandlers) do
                if qTbl.url:find(k) then
                    qTbl.mode = 'Deck'
                    local url, deckFunction = v(qTbl.url)
                    WebRequest.get(url, function(wr)
                        deckFunction(wr, qTbl)
                    end)
                    return true
                end
            end
        elseif qTbl.mode == 'Deck' then
            ttsUtils.testLog('1/4 raw deck is being spawned')
            local d = getNotebookTabs();
            ttsUtils.testLog('2/4 got notebook tabs')
            d = d[#d]
            ttsUtils.testLog('3/4 set d or whatever')
            spawnDeck({
                text = d.body,
                url = 'Notebook ' .. d.title .. d.color
            }, qTbl)
            ttsUtils.testLog('4/4 spawned deck!')
        end
        return false
    end,

    Rawdeck = function(qTbl)
        if qTbl.target then
            local dec = qTbl.target.getDescription()

            spawnDeck({
                text = dec,
                url = 'Description ' .. qTbl.target.getName()
            }, qTbl)
        end
    end

}, {
    __call = function(this, qTbl)
        if qTbl then
            log('Importer Request from ' .. qTbl.color .. ':', nil, 'debug')
            log(qTbl, nil, 'trace')
            qTbl.text = newText(qTbl.position, Player[qTbl.color].steam_name .. '\n' .. qTbl.full)
            table.insert(this.request, qTbl)
        end
        -- Main Logic
        if this.request[13] and qTbl then
            Player[qTbl.color].broadcast('Clearing Previous requests yours added and being processed.')
            endLoop()
        elseif qTbl and this.request[2] then
            local msg = 'Queueing request ' .. #this.request
            if this.request[4] then
                msg = msg .. '. Queue auto clears after the 13th request!'
            elseif this.request[3] then
                msg = msg .. '. Type `Scryfall clear queue` to force reload the queue!'
            end
            Player[qTbl.color].broadcast(msg)
        elseif this.request[1] then
            local tbl = this.request[1]
            -- If URL is not Deck list then
            -- Custom Image Replace
            if tbl.url and tbl.mode ~= 'Back' then
                if not this.Deck(tbl) then
                    Card.customImage = tbl.url
                    this.Spawn(tbl)
                end
            elseif this[tbl.mode] then
                this[tbl.mode](tbl)
            else
                this.Spawn(tbl)
            end -- Attempt to Spawn
        elseif qTbl then
            broadcastToAll('Something went wrong.\nImporter did not get a mode.')
            log('Importer() fatal error, query wasn\'t possible to parse correctly:', nil, 'error')
            log(qTbl, nil, 'trace')
        end
    end
})
MODES = ''
for k, v in pairs(Importer) do
    if not ('request'):find(k) then
        MODES = MODES .. ' ' .. k
    end
end

--[[ Utility Functions ]]

--- Forces a global loop in the Importer to end.
function endLoop()
    if Importer.request[1] then
        Importer.request[1].text()
        table.remove(Importer.request, 1)
    end
    Importer()
end

function delay(fN, tbl)
    local timerParams = {
        function_name = fN,
        identifier = fN .. 'Timer'
    }
    if type(tbl) == 'table' then
        timerParams.parameters = tbl
    end
    if type(tbl) == 'number' then
        timerParams.delay = tbl * Tick
    else
        timerParams.delay = 1.5
    end
    Timer.destroy(timerParams.identifier)
    Timer.create(timerParams)
end

local SMG, SMC = '[b]Scryfall: [/b]', {0.5, 1, 0.8}

--- A test function for printing messages to all players.
function AP(p, s)
    printToAll(SMG .. s:format(p.steam_name), SMC)
end

--- Reports information to the server about this script's version.
--- If the version of this script falls behind the one described in the wr parameter, 
--- this script will automatically load the one in the wr parameter and reload itself.
function enforceVersion(wr)
    local v = wr.text:match('mod_name,version=\'Card Importer\',(%d+%p%d+)')
    log(MOD_NAME .. ' GitHub version is: ' .. v, nil, 'info')
    if v then
        v = tonumber(v)
    else
        v = version
    end
    local report = '\nLatest Version ' .. self.getName()
    -- if the version of this script is somehow ahead of the one online, we're in an experimental version.
    -- if the version of this script is behind, we will attempt to update this script to the latest automatically.
    if version > v or Test then
        Test, report = true, '\n[fff600]Experimental Version of Importer Module'
    elseif version < v then
        report = '\n[77ff00]Update Ready:' .. v .. ' Attempting Update[-]\n' .. wr.url
    end

    Usage = Usage .. report
    broadcastToAll(report, {1, 0, 1})

    if report:find(' Attempting Update') then
        self.setLuaScript(wr.text)
        self.reload()
    else
        encoderIntegration.registerModule()
    end
end

-- find paired {} and []
function findClosingBracket(txt, st) -- find paired {} or []
    local ob, cb = '{', '}'
    local pattern = '[{}]'
    if txt:sub(st, st) == '[' then
        ob, cb = '[', ']'
        pattern = '[%[%]]'
    end
    local txti = st
    local nopen = 1
    while nopen > 0 do
        txti = string.find(txt, pattern, txti + 1)
        if txt:sub(txti, txti) == ob then
            nopen = nopen + 1
        elseif txt:sub(txti, txti) == cb then
            nopen = nopen - 1
        end
    end
    return txti
end

function convertQuotedValues(str)
    local a, b = str:gsub('%b""', function(g)
        return g:gsub(',', ''):gsub('"', '')
    end)
    return a
end

--[[ Tabletop Simulator Events ]]

--- Fires whenever the TTS scene is saved. (or checkpointed for a rewind)
--- NOTE: Does NOT fire when the script is forced to reload.
function onSave()
    self.script_state = JSON.encode(Back)
end

--- Fires whenever the TTS scene is loaded.
function onLoad(data)
    -- Force singleton instance of this script, but always keep the one with the higher version
    for _, o in pairs(getObjects()) do
        if o.getName():find(MOD_NAME) and o ~= self then
            if version < o.getVar('version') then
                self.destruct()
            else
                o.destruct()
            end
            break
        end
    end

    WebRequest.get(GIT_URL, self, 'enforceVersion')

    -- Back stores the script's state
    if data ~= '' then
        Back = JSON.decode(data)
    end
    Back = TBL.new(Back)

    self.createButton({
        label = "+",
        click_function = 'registerModule',
        function_owner = encoderIntegration,
        position = {0, 0.2, -0.5},
        height = 100,
        width = 100,
        font_size = 100,
        tooltip = "Adds Oracle Look Up"
    })

    -- send usage details to notebook
    Usage = Usage:format(self.getName())
    local usageNotebookTitle = MOD_NAME .. ' ' .. version .. ' Usage'
    ttsUtils.writeNotebook(usageNotebookTitle, Usage)
    --[[
    ttsUtils.writeNotebook('Importer onLoad() script_state',self.script_state)
    --]]

    -- send shortened usage details to description and print to all
    local u = Usage:gsub('\n\n.*', '\nFull capabilities listed in Notebook: ' .. usageNotebookTitle)
    u = u .. '\nWhats New: Now actually spawns Time Spiral Remastered Cards.'
    self.setDescription(u:gsub('[^\n]*\n', '', 1):gsub('%]  %[', ']\n['))
    printToAll(u, {0.9, 0.9, 0.9})

    -- script forces its own "clear back" command before loading is done
    onChat('Scryfall clear back')
end

-- Fires whenever the object owning this script is about to be destroyed.
function onDestroy()
    -- clear all text items before being destroyed
    for _, o in pairs(textItems) do
        if o ~= nil then
            o.destruct()
        end
    end
end

local chatToggle = false
--- Fires whenever a player types a chat message.
function onChat(msg, player)
    if msg:find('!?[Ss]cryfall ') then
        local cmd = msg:match('!?[Ss]cryfall (.*)') or false
        if cmd == 'hide' and player.admin then
            -- toggle putting this script in an active / silent mode
            chatToggle = not chatToggle
            if chatToggle then
                msg = 'ignoring'
            else
                msg = 'reading'
            end
            broadcastToAll('Importer is now ' .. msg ..
                               ' chat messages with "Scryfall" in them.\nToggle this with "Scryfall hide"', SMC)
        elseif cmd == 'help' then
            -- display a help message to the player that typed it
            player.print(Usage, {0.9, 0.9, 0.9})
            return false
        elseif cmd == 'clear queue' then
            -- reload the entire script
            version = version - 1
            printToAll(SMG .. 'Reloading the Card Importer!', SMC)
            self.reload()
        elseif cmd == 'clear back' then
            -- reload the Back object, which is effectively this script's current state
            self.script_state = string.gsub(DefaultBackState, '\n', '')
            Back = TBL.new('https://gamepedia.cursecdn.com/mtgsalvation_gamepedia/f/f8/Magic_card_back.jpg', JSON.decode(self.script_state))
        elseif cmd then
            -- this is the catch-all statement for chat commands that rely on the card importer's deeper functionality!

            -- pieHere, allow using spaces instead of + when doing search syntax, also allow ( ) grouping
            local tbl = {
                position = player.getPointerPosition(),
                player = player.steam_id,
                color = player.color,
                url = cmd:match('(http%S+)'),                         -- the URL, if any, that the player wants the action to use
                mode = cmd:gsub('(http%S+)', ''):match('(%S+)'),      -- the first complete non-url word after "Scryfall", if any (eg. "deck", "legal", "search")
                name = cmd:gsub('(http%S+)', ''),                     -- everything that isn't a url in the command (if a legal mode was given, it will be stripped out of this name later)
                full = cmd                                            -- the complete command (will never include the initial "Scryfall")
            }
            -- handle the case where the player importing is a spectator
            if tbl.color == 'Grey' then
                tbl.position = {0, 2, 0}
            end

            -- if a mode exists, make it match the name of the key as specified in the importer (eg. "dECk is changed to Deck"),
            -- then strip the mode out of the name property so that name is just the name of a card the user wants
            if tbl.mode then
                for k, v in pairs(Importer) do
                    if tbl.mode:lower() == k:lower() and type(v) == 'function' then
                        tbl.mode, tbl.name = k, tbl.name:lower():gsub(k:lower(), '', 1)
                        break
                    end
                end
            end

            if tbl.name:len() < 1 then
                -- handle case where no card name was given
                tbl.name = 'blank card'
            else
                -- otherwise, remove extra starting space and encode name to make scryfall searching work correctly
                if tbl.name:sub(1, 1) == ' ' then
                    tbl.name = tbl.name:sub(2, -1)
                end

                -- TODO: Consider using a better encoding method that we don't have to writea list of specific symbols for
                charEncoder = {
                    [' '] = '%%20',
                    ['>'] = '%%3E',
                    ['<'] = '%%3C',
                    [':'] = '%%3A',
                    ['%('] = '%%28',
                    ['%)'] = '%%29',
                    ['%{'] = '%%7B',
                    ['%}'] = '%%7D',
                    ['%['] = '%%5B',
                    ['%]'] = '%%5D',
                    ['%|'] = '%%7C',
                    ['%/'] = '%%2F',
                    ['\\'] = '%%5C',
                    ['%^'] = '%%5E',
                    ['%$'] = '%%24',
                    ['%?'] = '%%3F',
                    ['%!'] = '%%3F'
                }
                for char, replacement in pairs(charEncoder) do
                    tbl.name = tbl.name:gsub(char, replacement)
                end

                -- -- pieHere, this would be the smarter way to do it, but for some reason it doesn't quite work?
                -- -- it's just the ^ sybmol? can't get that one to encode..
                -- chars2encode={' ','>','<',':','%(','%)','%{','%}','%[','%]','%|','%/','\\','%^','%$','%?','%!'}
                -- for _,char in pairs(chars2encode) do
                --   tbl.name=tblname:gsub(char,'%%'..string.format("%X",string.unicode(char)))
                -- end

            end

            -- create Importer instance to handle everything
            Importer(tbl)

            -- console log message if necessary
            if chatToggle then
                ttsUtils.testLog(msg, player.steam_name)
                return false
            end
        end
    end
end

-- EOF

end)
__bundle_register("encoder_integration", function(require, _LOADED, __bundle_register, __bundle_modules)
-- This adds support for the Encoder module to the card importer.

local ttsUtils = require("tts_utils")

local M = {}

function M.registerModule()
    local pID = _G.MOD_NAME
    local enc = Global.getVar('Encoder')
    if enc then
        local prop = {
            name = pID,
            funcOwner = self,
            activateFunc = 'toggleMenu'
        }
        local v = enc.getVar('version')
        M.buttons = {'Respawn', 'Oracle', 'Rulings', 'Emblem\nAnd Tokens', 'Printings', 'Set Sleeve', 'Reverse Card'}
        if v and (type(v) == 'string' and tonumber(v:match('%d+%.%d+')) or v) < 4.4 then
            prop.toolID = pID
            prop.display = true
            enc.call('APIregisterTool', prop)
        else
            prop.values = {}
            prop.visible = true
            prop.propID = pID
            prop.tags = 'tool,cardImporter'
            enc.call('APIregisterProperty', prop)
        end
        function M.eEmblemAndTokens(o, p)
            M.ENC(o, p, 'Token')
        end
        function M.eOracle(o, p)
            M.ENC(o, p, 'Text')
        end
        function M.eRulings(o, p)
            M.ENC(o, p, 'Rules')
        end
        function M.ePrintings(o, p)
            M.ENC(o, p, 'Print')
        end
        function M.eRespawn(o, p)
            M.ENC(o, p, 'Spawn')
        end
        function M.eSetSleeve(o, p)
            M.ENC(o, p, 'Back')
        end
        function M.eReverseCard(o, p)
            M.ENC(o, p)
            spawnObjectJSON({
                json = o.getJSON():gsub('BackURL', 'FaceURL'):gsub('FaceURL', 'BackURL', 1)
            })
        end
    end
end

function M.ENC(o, p, m)
    M.enc.call('APIrebuildButtons', {
        obj = o
    })
    if m then
        if o.getName() == '' and m ~= 'Back' then
            Player[p].broadcast('Card has no name!', {1, 0, 1})
        else
            local oracleid = nil
            if o.memo ~= nil and o.memo ~= '' then
                oracleid = 'oracleid:' .. o.memo
            end
            Importer({
                position = o.getPosition() + Vector(0, 1, 0) + o.getTransformRight():scale(-2.4),
                target = o,
                player = Player[p].steam_id,
                color = p,
                oracleid = oracleid,
                name = o.getName():gsub('\n.*', '') or 'Energy Reserve',
                mode = m,
                full = 'Card Encoder'
            })
        end
    end
end

function M.toggleMenu(o)
    local enc = Global.getVar('Encoder')
    if enc then
        local flip = enc.call("APIgetFlip", {
            obj = o
        })
        for i, v in ipairs(M.buttons) do
            M.Button(o, v, flip)
        end
        M.Button:reset()
    end
end

M.Button = setmetatable({
    label = 'UNDEFINED',
    click_function = 'eOracle',
    function_owner = M,
    height = 400,
    width = 2100,
    font_size = 360,
    scale = {0.4, 0.4, 0.4},
    position = {0, 0.28, -1.35},
    rotation = {0, 0, 90},
    reset = function(t)
        t.label = 'UNDEFINED';
        t.position = {0, 0.28, -1.35}
    end
}, {
    __call = function(t, o, l, f)
        local inc, i = 0.325, 0
        l:gsub('\n', function()
            t.height, inc, i = t.height + 400, inc + 0.1625, i + 1
        end)
        t.label, t.click_function, t.position, t.rotation[3] = l, 'e' .. l:gsub('%s', ''),
            {0, 0.28 * f, t.position[3] + inc}, 90 - 90 * f
        o.createButton(t)
        t.height = 400
        if i % 2 == 1 then
            t.position[3] = t.position[3] + 0.1625
        end
    end
})

return M
end)
__bundle_register("tts_utils", function(require, _LOADED, __bundle_register, __bundle_modules)
local M = {}

-- specify log styles
local showLogPrefix = false
logStyle('info', {1, 1, 1}, showLogPrefix and '[INFO]' or '', '')
logStyle('warn', {1, 1, 0}, showLogPrefix and '[WARN]' or '', '')
logStyle('error', {1, 0.1, 0.1}, showLogPrefix and '[ERROR]' or '', '')
logStyle('debug', {0, 1, 1}, showLogPrefix and '[DEBUG]' or '', '')
logStyle('trace', {0.5, 0.5, 0.5}, showLogPrefix and '[TRACE]' or '', '')

--- Performs a log to the TTS console, but only in test environments!
function M.testLog(value, label, tags)
    -- refers to the global variable for the test environment
    if _G.Test then
        log(value, label, tags)
    end
end

--- Creates a new Notebook entry with the given title and body text, and with the given color.
--- If another entry already shares the same title, the content is replaced instead of making a new notebook entry.
--- If no color is supplied, the color of the entry will be grey.
--- @return number
--- The index of the notebook that was affected by this call.
function M.writeNotebook(title, body, color)
    local p = {
        index = -1,
        title = title,
        body = body or '',
        color = color or 'Grey'
    }
    for i, v in ipairs(getNotebookTabs()) do
        if v.title == p.title then
            p.index = i
        end
    end
    if p.index < 0 then
        addNotebookTab(p)
    else
        editNotebookTab(p)
    end
    return p.index
end

return M
end)
__bundle_register("utils", function(require, _LOADED, __bundle_register, __bundle_modules)
local M = {}

--- This function converts a list of the following structure:
--- [{}, {}, {}, {}, {}]
--- Into batches of the given size with the following example structure (batch size of 3):
--- [[{}, {}, {}], [{}, {}]]
--- The itemMapper parameter can also be used to map an item's structure before batching.
function M.batchFromList(list, batchSize, itemMapper)
    if batchSize == nil then batchSize = 1 end
    if itemMapper == nil then
        itemMapper = function(item) return item end
    end
    local batches = {}
    local currentBatch = {}
    for i, item in ipairs(list) do
        if #currentBatch == batchSize then
            -- this batch is full, move onto the next batch
            table.insert(batches, currentBatch)
            currentBatch = {}
        end

        if #currentBatch < batchSize then
            -- insert the mapped item into the current batch as long as there's room
            table.insert(currentBatch, itemMapper(item))
        end
    end
    -- insert final batch
    table.insert(batches, currentBatch)
    return batches
end

--- Converts a URI (usually a Scryfall image link) to a specific quality and removes unneeded query data.
function M.truncateURI(uri, quality, suffix)
    if quality == 'png' then
        uri = uri:gsub('.jpg', '.png')
    end
    return uri:gsub('%?.*', ''):gsub('normal', quality) .. suffix
end

return M
end)
return __bundle_require("__root")