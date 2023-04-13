local lastMouseX
local lastMouseY
local width
local height
local current_map
local main_map_menu

-- MAP SELECTED EVENTS
-- /////////////////////////////////////////////////////////////////

--- @param e bookGetTextEventData
local function bookGetTextCallback(e)
	local book = e.book
	local name = book.name
	local text = e.text

	-- get the first texture from the book
	-- or switch on 
	-- current_map = "Splash/splash_test.tga"
	current_map = "MWSE/mods/Map and Compass/mapsWagner/vvardenfellMapWagner.tga"
	-- current_map = "bookart/aldruhnregion_377_253.tga"
	-- tes3.messageBox("registered a new map")

	-- display new map
	if main_map_menu == nil then
		return
	end

	local mapPane = main_map_menu:findChild("PartDragMenu_main")
	mapPane:findChild("MenuMap_world").visible = false
	mapPane:findChild("MenuMap_local").visible = false
	mapPane:findChild("MenuMap_switch").visible = false

	-- destroy old map
	local existing_map = mapPane:findChild("rf_map_image")
	if existing_map ~= nil then
		existing_map:destroy()
	end

	-- create new map
	-- local scroll_bg = "textures/scroll.dds"
	-- local bg = main_map_menu:createImage{ id = "rf_map_bg", path = scroll_bg }
	-- local rect = mapPane:findChild("rf_rect")
	local map = main_map_menu:createImage{ id = "rf_map_image", path = current_map }
	map.imageScaleX = 1
	map.imageScaleY = 1
	width = map.width
	height = map.height
	-- rect.width = width
	-- rect.height = height

	main_map_menu:updateLayout()

end
event.register(tes3.event.bookGetText, bookGetTextCallback)

-- NEW MAP LOGIC
-- /////////////////////////////////////////////////////////////////

local function zoomIn(e)

	if current_map == nil then
		return
	end

	local map_menu = e.source
	local map_image = map_menu:findChild("rf_map_image")

	local unscaledWidth = map_image.width / map_image.imageScaleX
	local unscaledHeight = map_image.height / map_image.imageScaleY
	local unscaledOffsetX = (map_image.parent.childOffsetX - 0.5 * map_image.parent.width) / map_image.imageScaleX
	local unscaledOffsetY = (map_image.parent.childOffsetY + 0.5 * map_image.parent.height) / map_image.imageScaleY

	map_image.imageScaleX = math.min(map_image.imageScaleX + 0.1, 3)
	map_image.imageScaleY = math.min(map_image.imageScaleY + 0.1, 3)
	map_image.width = unscaledWidth * map_image.imageScaleX
	map_image.height = unscaledHeight * map_image.imageScaleY

	width = map_image.width
	height = map_image.height

	map_image.parent.childOffsetX = math.min((unscaledOffsetX * map_image.imageScaleX) + 0.5 * map_image.parent.width, 0)
	map_image.parent.childOffsetY = math.max((unscaledOffsetY * map_image.imageScaleY) - 0.5 * map_image.parent.height, 0)

	map_menu:updateLayout()
end

local function zoomOut(e)

	if current_map == nil then
		return
	end

	local map_menu = e.source
	local map_image = map_menu:findChild("rf_map_image")

	local unscaledWidth = map_image.width / map_image.imageScaleX
	local unscaledHeight = map_image.height / map_image.imageScaleY
	if (unscaledWidth * (map_image.imageScaleX - 0.1) < map_menu.width) then
		return
	elseif (unscaledHeight * (map_image.imageScaleY - 0.1) < map_menu.height) then
		return
	end
	local unscaledOffsetX = (map_image.parent.childOffsetX - 0.5 * map_image.parent.width) / map_image.imageScaleX
	local unscaledOffsetY = (map_image.parent.childOffsetY + 0.5 * map_image.parent.height) / map_image.imageScaleY

	map_image.imageScaleX = math.max(0.1, map_image.imageScaleX - 0.1)
	map_image.imageScaleY = math.max(0.1, map_image.imageScaleY - 0.1)
	map_image.width = unscaledWidth * map_image.imageScaleX
	map_image.height = unscaledHeight * map_image.imageScaleY

	width = map_image.width
	height = map_image.height

	map_image.parent.childOffsetX = math.min((unscaledOffsetX * map_image.imageScaleX) + 0.5 * map_image.parent.width, 0)
	map_image.parent.childOffsetY = math.max((unscaledOffsetY * map_image.imageScaleY) - 0.5 * map_image.parent.height, 0)

	if (map_image.parent.childOffsetX < -1 * (map_image.width - map_image.parent.width)) then
		map_image.parent.childOffsetX = -1 * (map_image.width - map_image.parent.width)
	end
	if (map_image.parent.childOffsetY > map_image.height - map_image.parent.height) then
		map_image.parent.childOffsetY = map_image.height - map_image.parent.height
	end

	map_menu:updateLayout()
end

local function startDrag(e)

	if current_map == nil then
		return
	end

	tes3ui.captureMouseDrag(true)
	lastMouseX = e.data0
	lastMouseY = e.data1
end

local function releaseDrag()

	if current_map == nil then
		return
	end

	tes3ui.captureMouseDrag(false)
end

local function dragController(e)

	if current_map == nil then
		return
	end

	local changeX = lastMouseX - e.data0
	local changeY = lastMouseY - e.data1

	local main_map_menu = tes3ui.findMenu("MenuMap") -- name = "PartDragMenu_main"
	if main_map_menu == nil then
		return
	end
	local mapPane = main_map_menu:findChild("PartDragMenu_main")

	mapPane.childOffsetX = math.min(0, mapPane.childOffsetX - changeX)
	mapPane.childOffsetY = math.max(0, mapPane.childOffsetY - changeY)

	if (mapPane.childOffsetX < -1 * (width - mapPane.width)) then
		mapPane.childOffsetX = -1 * (width - mapPane.width)
	end
	if (mapPane.childOffsetY > height - mapPane.height) then
		mapPane.childOffsetY = height - mapPane.height
	end

	lastMouseX = e.data0
	lastMouseY = e.data1

	main_map_menu:updateLayout()
end

-- MAP MENU CREATE EVENTS
-- /////////////////////////////////////////////////////////////////

--- @param e uiActivatedEventData
local function onMenuMapActivated(e)
	local mapmenu = e.element
	mapmenu:register("mouseScrollUp", zoomIn)
	mapmenu:register("mouseScrollDown", zoomOut)
	mapmenu:register("mouseDown", startDrag)
	mapmenu:register("mouseRelease", releaseDrag)
	mapmenu:register("mouseStillPressed", dragController)

	-- disable original map 
	-- name = "MenuMap_world"
	-- name = "MenuMap_local"
	-- name = "MenuMap_switch"
	local mapPane = mapmenu:findChild("PartDragMenu_main")
	mapPane.childOffsetX = 0
	mapPane.childOffsetY = 0

	local rect = mapmenu:createRect({ id = "rf_rect", randomizeColor = true })
	rect.widthProportional = 1.0
	rect.heightProportional = 1.0
	rect.childOffsetX = 0
	rect.childOffsetY = 0
	local bg = rect:createImage{ id = "rf_map_bg", path = "textures/scroll.dds" }
	bg.widthProportional = 1.0
	bg.heightProportional = 1.0
	bg.imageScaleX = 1.0
	bg.imageScaleY = 1.0

	debug.log("original map disabled")

	main_map_menu = mapmenu

	mapmenu:updateLayout()
end
event.register(tes3.event.uiActivated, onMenuMapActivated, { filter = "MenuMap" })

--- @param e menuEnterEventData
local function menuEnterCallback(e)
	if main_map_menu ~= nil then
		local mapPane = main_map_menu:findChild("PartDragMenu_main")
		mapPane:findChild("MenuMap_world").visible = false
		mapPane:findChild("MenuMap_local").visible = false
		mapPane:findChild("MenuMap_switch").visible = false
	end

end
event.register(tes3.event.menuEnter, menuEnterCallback)

-- INIT MOD
-- /////////////////////////////////////////////////////////////////

local function onInitialized()
	mwse.log("Immersive Maps initialized")
end
event.register("initialized", onInitialized)
