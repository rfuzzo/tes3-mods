-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\ Audiobooks
local read_menu = tes3ui.registerID("audiobooks:readmenu")
local read_menu_ok = tes3ui.registerID("audiobooks:readmenu_ok")
local read_menu_stop = tes3ui.registerID("audiobooks:readmenu_stop")
local read_menu_cancel = tes3ui.registerID("audiobooks:readmenu_cancel")

local last_played_sound_id = nil
local temp_book_id = nil

local ADD_BUTTONS = true

-- todo fill in
local sound_map = {
	BookSkill_Speechcraft3 = "Vo\\abmw\\2920_05_Second_Seed.mp3",
	BookSkill_Heavy_Armor2 = "Vo\\abmw\\2920_6_MidYear.mp3", -- BookSkill_Heavy Armor2
	BookSkill_Mercantile3 = "Vo\\abmw\\2920_7_Suns_Height.mp3",
	BookSkill_Sneak2 = "Vo\\abmw\\2920_8_Last_Seed.mp3",
	BookSkill_Conjuration3 = "Vo\\abmw\\2920_9_Hearth_Fire.mp3",
	BookSkill_Conjuration4 = "Vo\\abmw\\2920_10_FrostFall.mp3",
	BookSkill_Short_Blade2 = "Vo\\abmw\\2920_11_Suns_Dusk.mp3", -- BookSkill_Short Blade2
	BookSkill_Short_Blade3 = "Vo\\abmw\\2920_vol_12.mp3", -- BookSkill_Short Blade3
	BookSkill_Acrobatics2 = "Vo\\abmw\\A_Dance_in_Fire_book_1.mp3",
	BookSkill_Block3 = "Vo\\abmw\\A_Dance_in_Fire_Book_2.mp3",
	BookSkill_Athletics2 = "Vo\\abmw\\A_Dance_in_Fire_Book_3.mp3",
	BookSkill_Acrobatics3 = "Vo\\abmw\\A_Dance_in_Fire_Book_4.mp3",
	BookSkill_Marksman2 = "Vo\\abmw\\A_Dance_In_Fire_Book_5.mp3",
	bookskill_mercantile4 = "Vo\\abmw\\A_Dance_in_Fire_Book_6.mp3",
	bookskill_mercantile5 = "Vo\\abmw\\A_Dance_In_Fire_Book_7.mp3",
	BookSkill_Alchemy1 = "Vo\\abmw\\A_Game_At_Dinner.mp3",
	bk_istunondescosmology = "Vo\\abmw\\A_Less_Rude_Song.mp3",
	bk_ABCs = "Vo\\abmw\\ABCs_for_Barbarians.mp3",
	bk_AedraAndDaedra = "Vo\\abmw\\AedraDaedra.mp3",
	bk_AncestorsAndTheDunmer = "Vo\\abmw\\Ancestors_and_the_Dunmer.mp3",
	bk_AntecedantsDwemerLaw = "Vo\\abmw\\Antecedents_Dwemer.mp3",
	bk_ArcanaRestored = "Vo\\abmw\\Arcana_Restored.mp3",
	bk_ArkayTheEnemy = "Vo\\abmw\\Arkay_the_Enemy.mp3",
	bk_Ashland_Hymns = "Vo\\abmw\\AshHymns.mp3",
	BookSkill_Sneak3 = "Vo\\abmw\\Azura_and_the_Box.mp3",
	bk_BiographyBarenziah1 = "Vo\\abmw\\BioBarenziah1.mp3",
	bk_BiographyBarenziah2 = "Vo\\abmw\\BioBarenziah2.mp3",
	bk_BiographyBarenziah3 = "Vo\\abmw\\BioBarenziah3.mp3",
	BookSkill_Speechcraft1 = "Vo\\abmw\\Biography_Wolf_Queen.mp3",
	bk_BriefHistoryEmpire1 = "Vo\\abmw\\Biref_History_Empire_1.mp3",
	bk_BriefHistoryEmpire2 = "Vo\\abmw\\Biref_History_Empire_2.mp3",
	bk_BriefHistoryEmpire3 = "Vo\\abmw\\Biref_History_Empire_3.mp3",
	bk_BriefHistoryEmpire4 = "Vo\\abmw\\Biref_History_Empire_4.mp3",
	bk_BlasphemousRevenants = "Vo\\abmw\\Blasphemous_Revenants.mp3",
	bk_BoethiahPillowBook = "Vo\\abmw\\Boethiah_Pillow_Book.mp3",
	bk_Boethiahs_Glory_unique = "Vo\\abmw\\Boethiahs_Glory.mp3", -- bk_Boethiah's Glory_unique
	bk_ChildrenOfTheSky = "Vo\\abmw\\Children_Of_Sky.mp3",
	bk_ChroniclesNchuleft = "Vo\\abmw\\Chronicles_of_Nchuleft.mp3",
	bk_Confessions = "Vo\\abmw\\Confessions_Skooma_Eater.mp3",
	bk_corpsepreperation1_c = "Vo\\abmw\\Corpse_Preparation_1.mp3",
	bk_corpsepreperation2_c = "Vo\\abmw\\Corpse_Preparation_2.mp3",
	bk_corpsepreperation3_c = "Vo\\abmw\\Corpse_Preparation_3.mp3",
	bk_darkestdarkness = "Vo\\abmw\\Darkest_Darkness.mp3",
	bk_charterFG = "Vo\\abmw\\Fighters_Guild_Charter.mp3",
	bk_formygodsandemperor = "Vo\\abmw\\For_God_Emperor.mp3",
	bk_frontierconquestaccommodat = "Vo\\abmw\\Frontier_Conquest.mp3",
	bk_galur_ritharis_papers = "Vo\\abmw\\Galur_Rithari_Papers.mp3", -- bk_galur_ritharis_papers
	bk_graspingfortune = "Vo\\abmw\\Grasping_Fortune.mp3",
	bk_great_houses = "Vo\\abmw\\Great_Houses_Morrowind.mp3",
	bk_guide_to_ald_ruhn = "Vo\\abmw\\Guide_To_Aldruhn.mp3",
	bk_guide_to_sadrithmora = "Vo\\abmw\\Guide_To_Sadrith_Mora.mp3",
	bk_guide_to_vivec = "Vo\\abmw\\Guide_To_Vivec.mp3",
	bk_guide_to_balmora = "Vo\\abmw\\GuidetoBalmora.mp3",
	bk_HomiliesOfBlessedAlmalexia = "Vo\\abmw\\Homilies_Blessed_Amalexia.mp3",
	bk_InvocationOfAzura = "Vo\\abmw\\Invocation_of_Azura.mp3",
	bk_legionsofthedead = "Vo\\abmw\\Legions_Of_The_Dead.mp3",
	bk_LivesOfTheSaints = "Vo\\abmw\\Lives_of_the_saints.mp3",
	bk_lustyargonianmaid = "Vo\\abmw\\Lusty_Argonian_Maid.mp3",
	bk_charterMG = "Vo\\abmw\\Mages_Guild_Charter.mp3",
	bk_MixedUnitTactics = "Vo\\abmw\\Mixed_Unit_Tactics.mp3",
	bk_MysteriousAkavir = "Vo\\abmw\\Mysterious_Akavir.mp3",
	bk_Mysticism = "Vo\\abmw\\Mysticism_Unfath_Voyage.mp3",
	bk_NerevarMoonandStar = "Vo\\abmw\\Nerevar_MoonStar.mp3",
	bk_NGastaKvataKvakis_c = "Vo\\abmw\\NGasta_Kvata_Kvakis.mp3",
	bk_onoblivion = "Vo\\abmw\\On_Oblivion.mp3",
	bk_OriginOfTheMagesGuild = "Vo\\abmw\\Origin_Mages_Guild.mp3",
	bk_OverviewOfGodsAndWorship = "Vo\\abmw\\Overview_Gods_Worship.mp3",
	bk_BriefHistoryofWood = "Vo\\abmw\\Picture_Book_of_Wood.mp3",
	bk_poisonsong5 = "Vo\\abmw\\Poison_Song_5.mp3",
	bk_poisonsong6 = "Vo\\abmw\\Poison_Song_6.mp3",
	bk_poisonsong7 = "Vo\\abmw\\Poison_Song_7.mp3",
	bk_poisonsong1 = "Vo\\abmw\\Poison_Song_Book_1.mp3",
	bk_poisonsong2 = "Vo\\abmw\\Poison_Song_Book_2.mp3",
	bk_poisonsong3 = "Vo\\abmw\\Poison_Song_Book_3.mp3",
	bk_poisonsong4 = "Vo\\abmw\\Poison_Song_Book_4.mp3",
	bk_reflectionsoncultworship = "Vo\\abmw\\Reflections_on_Cult_Worship.mp3",
	bk_tamrielicreligions = "Vo\\abmw\\Ruins_of_Kemel_Ze.mp3",
	bk_SaryonisSermons = "Vo\\abmw\\Saryonis_Sermons.mp3",
	bk_ShortHistoryMorrowind = "Vo\\abmw\\Short_History_Morrowind.mp3",
	bk_specialfloraoftamriel = "Vo\\abmw\\Special_Flora_Tamriel.mp3",
	bk_AffairsOfWizards = "Vo\\abmw\\The_Affairs_of_Wizards.mp3",
	bk_AnnotatedAnuad = "Vo\\abmw\\The_Annotated_Anuad.mp3",
	bk_Anticipations = "Vo\\abmw\\The_Anticipations.mp3",
	bk_ArcturianHeresy = "Vo\\abmw\\The_Arcturian_Heresy.mp3",
	BookSkill_Acrobatics4 = "Vo\\abmw\\The_Black_Arrow_1.mp3",
	bookskill_marksman5 = "Vo\\abmw\\The_Black_Arrow_2.mp3",
	bk_BlueBookOfRiddles = "Vo\\abmw\\The_Blue_Book_Riddles.mp3",
	bk_BookOfDaedra = "Vo\\abmw\\The_Book_of_Daedra.mp3",
	bk_BookDawnAndDusk = "Vo\\abmw\\The_Book_of_Dawn_and_Dusk.mp3",
	bk_CantatasOfVivec = "Vo\\abmw\\The_Cantatas_of_Vivec.mp3",
	bk_ChangedOnes = "Vo\\abmw\\The_Changed_Ones.mp3",
	bk_ConsolationsOfPrayer = "Vo\\abmw\\The_Consolations_of_Prayer.mp3",
	bk_DoorsOfTheSpirit = "Vo\\abmw\\The_Doors_Of_Spirit.mp3",
	bk_easternprovincesimpartial = "Vo\\abmw\\The_Eastern_Provinces.mp3",
	bk_firmament = "Vo\\abmw\\The_Firmament.mp3",
	bk_HouseOfTroubles_o = "Vo\\abmw\\The_House_of_Troubles.mp3",
	bk_PilgrimsPath = "Vo\\abmw\\The_Pilgrims_Path.mp3",
	bk_realbarenziah3 = "Vo\\abmw\\the_real_barenziah_v3.mp3",
	bk_realbarenziah4 = "Vo\\abmw\\the_real_barenziah_v4.mp3",
	bk_RealBarenziah5 = "Vo\\abmw\\The_real_barenziah_v5.mp3",
	bk_RealBarenziah1 = "Vo\\abmw\\The_Real_Barenziah_Volume1.mp3",
	bk_realbarenziah2 = "Vo\\abmw\\The_Real_Barenziah_Volume2.mp3",
	bk_RealNerevar = "Vo\\abmw\\The_Real_Nerevar.mp3",
	bk_redbookofriddles = "Vo\\abmw\\The_Red_Book_Riddles.mp3",
	bk_truenatureoforcs = "Vo\\abmw\\The_True_Nature_Orcs.mp3",
	bk_truenoblescode = "Vo\\abmw\\The_True_Nobles_Code.mp3",
	bk_vampiresofvvardenfell1 = "Vo\\abmw\\Vampires_Vvardenfell_I.mp3",
	bk_vampiresofvvardenfell2 = "Vo\\abmw\\Vampires_Vvardenfell_II.mp3",
	bk_varietiesoffaithintheempire = "Vo\\abmw\\Varieties_of_Faith.mp3",
	bk_vivecandmephala = "Vo\\abmw\\Vivec_and_Mephala.mp3",
	BookSkill_Athletics3 = "Vo\\abmw\\VivecSermon1.mp3",
	BookSkill_Alchemy4 = "Vo\\abmw\\VivecSermon2.mp3",
	BookSkill_Blunt_Weapon4 = "Vo\\abmw\\VivecSermon3.mp3",
	BookSkill_Mysticism3 = "Vo\\abmw\\VivecSermon4.mp3",
	BookSkill_Axe4 = "Vo\\abmw\\VivecSermon5.mp3",
	BookSkill_Armorer3 = "Vo\\abmw\\VivecSermon6.mp3",
	BookSkill_Block4 = "Vo\\abmw\\VivecSermon7.mp3",
	BookSkill_Athletics4 = "Vo\\abmw\\VivecSermon8.mp3",
	BookSkill_Blunt_Weapon5 = "Vo\\abmw\\VivecSermon9.mp3",
	BookSkill_Short_Blade4 = "Vo\\abmw\\VivecSermon10.mp3",
	bookskill_unarmored3 = "Vo\\abmw\\VivecSermon11.mp3",
	bookskill_heavy_armor5 = "Vo\\abmw\\VivecSermon12.mp3",
	BookSkill_Alteration4 = "Vo\\abmw\\VivecSermon13.mp3",
	bookskill_spear3 = "Vo\\abmw\\VivecSermon14.mp3",
	bookskill_unarmored4 = "Vo\\abmw\\VivecSermon15.mp3",
	BookSkill_Axe5 = "Vo\\abmw\\VivecSermon16.mp3",
	bookskill_long_blade3 = "Vo\\abmw\\VivecSermon17.mp3",
	BookSkill_Alchemy5 = "Vo\\abmw\\VivecSermon18.mp3",
	bookskill_enchant4 = "Vo\\abmw\\VivecSermon19.mp3",
	bookskill_long_blade4 = "Vo\\abmw\\VivecSermon20.mp3",
	bookskill_light_armor4 = "Vo\\abmw\\VivecSermon21.mp3",
	bookskill_medium_armor4 = "Vo\\abmw\\VivecSermon22.mp3",
	bookskill_long_blade5 = "Vo\\abmw\\VivecSermon23.mp3",
	bookskill_spear4 = "Vo\\abmw\\VivecSermon24.mp3",
	BookSkill_Armorer4 = "Vo\\abmw\\VivecSermon25.mp3",
	bookskill_sneak5 = "Vo\\abmw\\VivecSermon26.mp3",
	bookskill_speechcraft5 = "Vo\\abmw\\VivecSermon27.mp3",
	bookskill_light_armor5 = "Vo\\abmw\\VivecSermon28.mp3",
	BookSkill_Armorer5 = "Vo\\abmw\\VivecSermon29.mp3",
	BookSkill_Short_Blade5 = "Vo\\abmw\\VivecSermon30.mp3",
	BookSkill_Athletics5 = "Vo\\abmw\\VivecSermon31.mp3",
	BookSkill_Block5 = "Vo\\abmw\\VivecSermon32.mp3",
	bookskill_medium_armor5 = "Vo\\abmw\\VivecSermon33.mp3",
	bookskill_unarmored5 = "Vo\\abmw\\VivecSermon34.mp3",
	bookskill_spear5 = "Vo\\abmw\\VivecSermon35.mp3",
	BookSkill_Mysticism4 = "Vo\\abmw\\VivecSermon36.mp3",
	BookSkill_Long_Blade2 = "Vo\\abmw\\2920_01_Morning_Star.mp3",
	BookSkill_Mysticism2 = "Vo\\abmw\\2920_02_Suns_Dawn.mp3",
	BookSkill_Spear2 = "Vo\\abmw\\2920_03_First_Seed.mp3",
	BookSkill_Restoration4 = "Vo\\abmw\\2920_04_Rains_Hand.mp3",

}

--- @param book_id string
local function getSoundId(book_id)
	return book_id .. "_"
end

local re = require("re")
--- @param dirty_id string
--- replace spaces with _, replace . and ' with none
local function sanitize_id(dirty_id)
	local result = string.gsub(dirty_id, "%s+", "_")
	result = re.gsub(result, "[.,]", "")
	return result
end

------------------------------------------------------------------------------------

local function removeSoundInternal()
	if last_played_sound_id ~= nil then
		-- tes3.removeSound({ sound = last_played_sound_id, reference = tes3.player })
		tes3.removeSound({ reference = tes3.player })
	end
end

local function playSoundInternal()
	if temp_book_id ~= nil then
		local sound_path = sound_map[temp_book_id]
		if sound_path ~= nil then
			local sound_id = getSoundId(temp_book_id)

			removeSoundInternal()

			-- play new sound
			-- local sound_obj = tes3.createObject { id = sound_id, objectType = tes3.objectType.sound, filename = sound_path }
			-- local success = tes3.playSound({ sound = sound_obj, reference = tes3.player })

			tes3.say({ reference = tes3.player, soundPath = sound_path })

			-- if success then
			last_played_sound_id = sound_id
			-- end
		end
	end
end

------------------------------------------------------------------------------------

-- OK button callback.
local function onPromptRead(e)
	local menu = tes3ui.findMenu(read_menu)

	if (menu) then
		playSoundInternal()

		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Stop button callback.
local function onPromptStop(e)
	local menu = tes3ui.findMenu(read_menu)

	if (menu) then
		removeSoundInternal()

		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Cancel button callback.
local function onPromptCancel(e)
	local menu = tes3ui.findMenu(read_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

local function createReadWindow()
	-- Return if window is already open
	if (tes3ui.findMenu(read_menu) ~= nil) then
		return
	end

	-- Create window and frame
	local menu = tes3ui.createMenu { id = read_menu, fixedFrame = true }

	-- To avoid low contrast, text input windows should not use menu transparency settings
	menu.alpha = 1.0

	-- Create layout
	local input_label = menu:createLabel{ text = "Would you like to read this book out loud?" }
	input_label.borderBottom = 5

	local input_block = menu:createBlock{}
	input_block.autoHeight = true
	input_block.childAlignX = 0.5 -- centre content alignment

	local button_block = menu:createBlock{}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 0.5 -- centre content alignment
	local button_ok = button_block:createButton{ id = read_menu_ok, text = "Yes" }
	local button_stop = button_block:createButton{ id = read_menu_stop, text = "Read silently" }
	local button_cancel = button_block:createButton{ id = read_menu_cancel, text = "Cancel" }

	-- Events
	button_ok:register(tes3.uiEvent.mouseClick, onPromptRead)
	button_stop:register(tes3.uiEvent.mouseClick, onPromptStop)
	button_cancel:register(tes3.uiEvent.mouseClick, onPromptCancel)

	-- Final setup
	menu:updateLayout()
	tes3ui.enterMenuMode(read_menu)
end

--- @param e equipEventData
local function equipCallback(e)
	if (e.item.objectType ~= tes3.objectType.book) then
		return
	end

	local sanitized_id = sanitize_id(e.item.id)
	local sound_path = sound_map[sanitized_id]

	-- debug.log(e.item.id)
	-- debug.log(sanitized_id)
	-- debug.log(sound_path)

	if sound_path ~= nil then
		temp_book_id = sanitized_id
	end

end
event.register(tes3.event.equip, equipCallback, { priority = 100 })

------------------------------------------------------------------------------------

-- OK button callback.
local function onMenuBookRead(e)
	playSoundInternal()
end

-- Stop button callback.
local function onMenuBookStop(e)
	removeSoundInternal()
end

------------------------------------------------------------------------------------

--- @param e uiActivatedEventData
local function uiActivatedCallback(e)

	if (e.element.name ~= "MenuBook") then
		return
	end
	if temp_book_id == nil then
		return
	end

	createReadWindow()

	-- add buttons
	if ADD_BUTTONS then
		local bookMenu = e.element

		-- name = "MenuBook_buttons_left"
		-- name = "MenuBook_button_take"
		-- name = "MenuBook_page_number_1"
		-- name = "MenuBook_button_prev"
		-- name = "MenuBook_buttons_right"
		-- name = "MenuBook_button_next"
		-- name = "MenuBook_page_number_2"
		-- name = "MenuBook_button_close"
		local buttons_left = bookMenu:findChild('MenuBook_buttons_right')

		local button_block = buttons_left:createBlock{}
		button_block.widthProportional = 1.0 -- width is 100% parent width
		-- button_block.width = 300 -- width is 100% parent width
		button_block.autoHeight = true

		local button_read = button_block:createButton{ id = "rf_bookmenu_btn_read.mp3", text = "Read" }
		local button_stop = button_block:createButton{ id = "rf_bookmenu_btn_stop.mp3", text = "Stop" }

		button_read:register(tes3.uiEvent.mouseClick, onMenuBookRead)
		button_stop:register(tes3.uiEvent.mouseClick, onMenuBookStop)

		bookMenu:updateLayout()
	end

end
event.register(tes3.event.uiActivated, uiActivatedCallback)

