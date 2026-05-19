local this = {};

local quest_status = require("MHR_Overlay.Game_Handler.quest_status");
local player_info = require("MHR_Overlay.Misc.player_info");
local players = require("MHR_Overlay.Damage_Meter.players");
local large_monster = require("MHR_Overlay.Monsters.large_monster");
local small_monster = require("MHR_Overlay.Monsters.small_monster");
local env_creature = require("MHR_Overlay.Endemic_Life.env_creature");
local env_creature_hook = require("MHR_Overlay.Endemic_Life.env_creature_hook");
local small_monster = require("MHR_Overlay.Monsters.small_monster");
local monster_hook = require("MHR_Overlay.Monsters.monster_hook");
local time = require("MHR_Overlay.Game_Handler.time");
local buffs = require("MHR_Overlay.Buffs.buffs");
local ailments = require("MHR_Overlay.Monsters.ailments");
local ailment_buildup = require("MHR_Overlay.Monsters.ailment_buildup");
local singletons = require("MHR_Overlay.Game_Handler.singletons");
local config = require("MHR_Overlay.Misc.config");
local endemic_life_buffs = require("MHR_Overlay.Buffs.endemic_life_buffs");
local item_buffs = require("MHR_Overlay.Buffs.item_buffs");
local misc_buffs = require("MHR_Overlay.Buffs.misc_buffs");

local sdk = sdk;
local re = re;
local json = json;
local pairs = pairs;
local ipairs = ipairs;
local table = table;
local math = math;
local tostring = tostring;

local enemy_manager_type_def = sdk.find_type_definition("snow.enemy.EnemyManager");
local get_boss_enemy_count_method = enemy_manager_type_def:get_method("getBossEnemyCount");
local get_boss_enemy_method = enemy_manager_type_def:get_method("getBossEnemy");
local get_enemy_count_method = enemy_manager_type_def:get_method("getEnemyCount");
local get_enemy_method = enemy_manager_type_def:get_method("getEnemy");

local player_manager_type_def = sdk.find_type_definition("snow.player.PlayerManager");
local find_master_player_method = player_manager_type_def:get_method("findMasterPlayer");
local get_player_data_method = player_manager_type_def:get_method("get_PlayerData");
local player_data_type_def = get_player_data_method:get_return_type();
local stamina_cap_timer_field = player_data_type_def:get_field("_StaminaUpBuffSecondTimer");

local get_UpTimeSecond = sdk.find_type_definition("via.Application"):get_method("get_UpTimeSecond")
local os = os
local io = io
local interval = 1
local lastTime = 0.0
local log_file = nil
local was_in_quest = false

function this.init_module()
	if config.current_config then
		config.current_config.stats_UI.enabled = true;
		config.current_config.buff_UI.enabled = true;
		config.current_config.endemic_life_UI.enabled = true;
		config.current_config.small_monster_UI.enabled = true;
		if config.current_config.large_monster_UI then
			config.current_config.large_monster_UI.dynamic.enabled = true;
			config.current_config.large_monster_UI.static.enabled = true;
		end
	end

	quest_status.init_module();
	player_info.init_module();
	players.init_module();
	large_monster.init_module();
	small_monster.init_module();
	monster_hook.init_module();
	env_creature_hook.init_module();

	players.init();

	re.on_frame(function()
		this.main();
	end);
end

function this.main()
	local current_flow_state = quest_status.flow_state;
	local is_in_quest = current_flow_state >= quest_status.flow_states.PLAYING_QUEST and current_flow_state <= quest_status.flow_states.WYVERN_RIDING_START_ANIMATION;

	if current_flow_state == quest_status.flow_states.NONE then
		return;
	end

	if config.current_config then
		config.current_config.stats_UI.enabled = true;
		config.current_config.buff_UI.enabled = true;
		config.current_config.endemic_life_UI.enabled = true;
		config.current_config.small_monster_UI.enabled = true;
		if config.current_config.large_monster_UI then
			config.current_config.large_monster_UI.dynamic.enabled = true;
			config.current_config.large_monster_UI.static.enabled = true;
		end
	end

	if is_in_quest then
		if not was_in_quest then
			local timestamp = os.date("%Y%m%d_%H%M%S");
			local filename = "logs\\world_log_" .. timestamp .. ".json";
			log_file = io.open(filename, "w");
			if log_file then
				log_file:write("[\n");
				print("World logging started: " .. filename);
			end
			was_in_quest = true;
		end
	else
		if was_in_quest then
			if log_file then
				log_file:write("]\n");
				log_file:close();
				log_file = nil;
				print("World logging ended. Check reframework/data/logs/ for the file.");
			end
			was_in_quest = false;
		end
	end

	players.update_myself_position();
	player_info.update();
	buffs.update();

	if is_in_quest then
		local newTime = get_UpTimeSecond:call(nil)
		if (newTime - lastTime) > interval then
			lastTime = newTime

			local world_state = this.extract_world_state();
			local json_str = json.dump_string(world_state);

			this.print_player_status();
			this.print_monster_status();
			-- this.print_small_monster_status();
			-- this.print_endemic_life_status();

			if log_file then
				log_file:write(json_str .. ",\n");
				log_file:flush();
			end
		end
	end
end

function this.print_player_status()
	local pos = players.myself_position;
	local p = players.myself;
	local pi = player_info.list;

	print("--- Player ---");
	print("Name: " .. tostring(p and p.name or "N/A"));
	print("Position: " .. string.format("x=%.2f, y=%.2f, z=%.2f", pos.x, pos.y, pos.z));
	print("HP: " .. pi.health .. " / " .. pi.max_health);
	print("Stamina: " .. pi.stamina .. " / " .. pi.max_stamina);
	print("Attack: " .. pi.attack);
	print("Defense: " .. pi.defense);
	print("Affinity: " .. pi.affinity .. "%");
	print("Element: " .. pi.element_type .. " (" .. pi.element_attack .. ")");
	print("Element2: " .. pi.element_type_2 .. " (" .. pi.element_attack_2 .. ")");
	print("Resistances - Fire: " .. pi.fire_resistance .. ", Water: " .. pi.water_resistance .. ", Thunder: " .. pi.thunder_resistance .. ", Ice: " .. pi.ice_resistance .. ", Dragon: " .. pi.dragon_resistance);
	if p and p.display then
		print("Damage: " .. p.display.total_damage);
		print("DPS: " .. string.format("%.1f", p.dps));
	end
	print("Cart Count: " .. (p and p.cart_count or 0));

	-- local world_ec = this.get_world_endemic_life_counts();
	-- local active_ec = this.get_active_endemic_life();
	-- local consumed = this.get_consumed_items();
	-- print("World Endemic - wirebugs=" .. world_ec.wirebugs .. " flies=" .. world_ec.flies .. " lampreys=" .. world_ec.lampreys .. " others=" .. world_ec.others);
	-- print("Player Active - wirebug=" .. active_ec.wirebug .. " atk=" .. active_ec.attack_up .. " def=" .. active_ec.defense_up .. " crit=" .. active_ec.crit_up);
	-- print("Consumed - might=" .. consumed.might_seeds .. " adamant=" .. consumed.defense_seeds .. " demon=" .. consumed.demon_drugs .. " armor=" .. consumed.armor_skin .. " stamina_bird=" .. consumed.stamina_birds);
end

function this.print_monster_status()
	if singletons.enemy_manager == nil then
		return;
	end

	local enemy_manager = singletons.enemy_manager;
	local enemy_count = get_boss_enemy_count_method:call(enemy_manager);

	print("--- Monsters (" .. enemy_count .. ") ---");

	for i = 0, enemy_count - 1 do
		local enemy = get_boss_enemy_method:call(enemy_manager, i);
		if enemy == nil then
			goto continue;
		end

		local monster = large_monster.list[enemy];
		if monster == nil then
			goto continue;
		end

		local pos = monster.position;
		local status = monster.dead_or_captured and "DEAD" or "ALIVE";

		print(string.format("[%d] %s - %s", i + 1, monster.name, status));
		print(string.format("    Position: x=%.2f, y=%.2f, z=%.2f", pos.x, pos.y, pos.z));
		print(string.format("    HP: %.0f / %.0f (%.1f%%)", monster.health, monster.max_health, monster.health_percentage * 100));
		print(string.format("    Stamina: %.0f / %.0f (%.1f%%)", monster.stamina, monster.max_stamina, monster.stamina_percentage * 100));
		print(string.format("    Tired: %s", monster.is_tired and "Yes" or "No"));
		print(string.format("    Rage: %s (%.0f / %.0f)", monster.is_in_rage and "Active" or "Idle", monster.rage_point, monster.rage_limit));
		print(string.format("    Stealth: %s", monster.is_stealth and "Yes" or "No"));

		local part_count = 0;
		if monster.parts then
			for _ in pairs(monster.parts) do part_count = part_count + 1 end
		end
		print(string.format("    Parts: %d", part_count));

		local ailment_count = 0;
		if monster.ailments and monster.ailments.list then
			for _ in pairs(monster.ailments.list) do ailment_count = ailment_count + 1 end
		end
		print(string.format("    Ailments: %d", ailment_count));

		::continue::
	end
end

function this.print_endemic_life_status()
	local count = 0;
	if env_creature.list then
		for _ in pairs(env_creature.list) do count = count + 1 end
	end

	print("--- Endemic Life (" .. count .. ") ---");

	if count > 0 and env_creature.list then
		for _, creature in pairs(env_creature.list) do
			print(creature.name .. ": x=" .. creature.position.x .. ", y=" .. creature.position.y .. ", z=" .. creature.position.z);
		end
	end
end

function this.print_small_monster_status()
	local count = 0;
	if small_monster.list then
		for _ in pairs(small_monster.list) do count = count + 1 end
	end

	print("--- Small Monsters (" .. count .. ") ---");

	if count > 0 and small_monster.list then
		for _, monster in pairs(small_monster.list) do
			if not monster.is_large then
				print(monster.name .. ": x=" .. monster.position.x .. ", y=" .. monster.position.y .. ", z=" .. monster.position.z .. " HP=" .. monster.health .. "/" .. monster.max_health);
			end
		end
	end
end

function this.extract_world_state()
	local current_time = os.date("!%Y-%m-%dT%H:%M:%S") .. "Z"
	local game_time = get_UpTimeSecond:call(nil)

	local world_state = {
		timestamp = current_time,
		game_time = game_time,
		quest = this.extract_quest_info(),
		player = this.extract_player_info(),
		large_monsters = this.extract_large_monsters(),
		small_monsters = this.extract_small_monsters(),
		-- endemic_life = this.extract_endemic_life(),
		time = this.extract_time_info()
	};

	return world_state;
end

-- function this.get_stamina_cap()
-- 	local result = 100;

-- 	local success, val = pcall(function()
-- 		if singletons.player_manager == nil then
-- 			return 100;
-- 		end

-- 		local master_player = find_master_player_method:call(singletons.player_manager);
-- 		if master_player == nil then
-- 			return 100;
-- 		end

-- 		local player_data = get_player_data_method:call(master_player);
-- 		if player_data == nil or not sdk.to_managed_object(player_data) then
-- 			return 100;
-- 		end

-- 		local stamina_timer = stamina_cap_timer_field:get_data(player_data);

-- 		if stamina_timer and stamina_timer > 0 then
-- 			return 200;
-- 		end

-- 		return 100;
-- 	end);

-- 	if success then
-- 		result = val;
-- 	end

-- 	return result;
-- end

-- function this.get_active_endemic_life()
-- 	local counts = {
-- 		wirebug = 0,
-- 		attack_up = 0,
-- 		defense_up = 0,
-- 		crit_up = 0,
-- 		other = 0
-- 	};

-- 	local success, result = pcall(function()
-- 		if endemic_life_buffs.list then
-- 			for key, buff in pairs(endemic_life_buffs.list) do
-- 				if buff and buff.timer and buff.timer > 0 then
-- 					if key == "ruby_wirebug" or key == "gold_wirebug" then
-- 						counts.wirebug = counts.wirebug + 1;
-- 					elseif key == "butterflame" or key == "red_lampsquid" then
-- 						counts.attack_up = counts.attack_up + 1;
-- 					elseif key == "clothfly" or key == "yellow_lampsquid" then
-- 						counts.defense_up = counts.defense_up + 1;
-- 					elseif key == "cutterfly" then
-- 						counts.crit_up = counts.crit_up + 1;
-- 					else
-- 						counts.other = counts.other + 1;
-- 					end
-- 				end
-- 			end
-- 		end

-- 		return counts;
-- 	end)

-- 	return success and result or counts;
-- end

-- function this.get_consumed_items()
-- 	local consumed = {
-- 		might_seeds = 0,
-- 		defense_seeds = 0,
-- 		demon_drugs = 0,
-- 		armor_skin = 0,
-- 		powders = 0,
-- 		gourmet_fish = 0,
-- 		stamina_birds = 0,
-- 		other = 0
-- 	};

-- 	local success, result = pcall(function()
-- 		if item_buffs.list then
-- 			for key, buff in pairs(item_buffs.list) do
-- 				if buff and buff.timer and buff.timer > 0 then
-- 					if key == "might_seed" then
-- 						consumed.might_seeds = consumed.might_seeds + 1;
-- 					elseif key == "adamant_seed" then
-- 						consumed.defense_seeds = consumed.defense_seeds + 1;
-- 					elseif key == "demondrug" or key == "mega_demondrug" then
-- 						consumed.demon_drugs = consumed.demon_drugs + 1;
-- 					elseif key == "armorskin" or key == "mega_armorskin" then
-- 						consumed.armor_skin = consumed.armor_skin + 1;
-- 					elseif key == "demon_powder" or key == "hardshell_powder" then
-- 						consumed.powders = consumed.powders + 1;
-- 					elseif key == "gourmet_fish" then
-- 						consumed.gourmet_fish = consumed.gourmet_fish + 1;
-- 					else
-- 						consumed.other = consumed.other + 1;
-- 					end
-- 				end
-- 			end
-- 		end

-- 		if misc_buffs.list then
-- 			for key, buff in pairs(misc_buffs.list) do
-- 				if buff and buff.timer and buff.timer > 0 then
-- 					if key == "stamina_use_down" then
-- 						consumed.stamina_birds = consumed.stamina_birds + 1;
-- 					else
-- 						consumed.other = consumed.other + 1;
-- 					end
-- 				end
-- 			end
-- 		end

-- 		return consumed;
-- 	end)

-- 	return success and result or consumed;
-- end

function this.extract_quest_info()
	local quest_info = {
		flow_state = quest_status.flow_state,
		flow_state_name = quest_status.get_flow_state_name(quest_status.flow_state, false),
		is_online = quest_status.is_online,
		cart_count = quest_status.cart_count,
		max_cart_count = quest_status.max_cart_count
	};

	return quest_info;
end

function this.extract_time_info()
	local time_info = {
		total_elapsed_seconds = time.total_elapsed_seconds,
		elapsed_minutes = time.elapsed_minutes,
		elapsed_seconds = time.elapsed_seconds
	};

	return time_info;
end

function this.extract_player_info()
	local player = players.myself;
	if player == nil then
		return nil;
	end

	local player_state = {
		name = player.name,
		id = player.id,
		hunter_rank = player.hunter_rank,
		master_rank = player.master_rank,
		type = player.type,
		cart_count = player.cart_count,
		position = {
			x = players.myself_position.x,
			y = players.myself_position.y,
			z = players.myself_position.z
		},
		health = {
			current = player_info.list.health,
			max = player_info.list.max_health
		},
		stamina = {
			current = player_info.list.stamina,
			max = player_info.list.max_stamina
		},
		stats = {
			attack = player_info.list.attack,
			defense = player_info.list.defense,
			affinity = player_info.list.affinity
		},
		element = {
			type1 = player_info.list.element_type,
			attack1 = player_info.list.element_attack,
			type2 = player_info.list.element_type_2,
			attack2 = player_info.list.element_attack_2
		},
		resistances = {
			fire = player_info.list.fire_resistance,
			water = player_info.list.water_resistance,
			thunder = player_info.list.thunder_resistance,
			ice = player_info.list.ice_resistance,
			dragon = player_info.list.dragon_resistance
		},
		damage = {
			total = player.display.total_damage,
			physical = player.display.physical_damage,
			elemental = player.display.elemental_damage,
			ailment = player.display.ailment_damage,
			dps = player.dps
		},
		-- endemic_life = this.get_active_endemic_life(),
		-- consumed_items = this.get_consumed_items(),
		buffs = this.extract_player_buffs()
	};

	return player_state;
end

function this.extract_player_buffs()
	local buff_list = {};

	local buff_categories = {
		abnormal_statuses = require("MHR_Overlay.Buffs.abnormal_statuses"),
		item_buffs = require("MHR_Overlay.Buffs.item_buffs"),
		endemic_life_buffs = require("MHR_Overlay.Buffs.endemic_life_buffs"),
		melody_effects = require("MHR_Overlay.Buffs.melody_effects"),
		dango_skills = require("MHR_Overlay.Buffs.dango_skills"),
		rampage_skills = require("MHR_Overlay.Buffs.rampage_skills"),
		skills = require("MHR_Overlay.Buffs.skills"),
		weapon_skills = require("MHR_Overlay.Buffs.weapon_skills"),
		otomo_moves = require("MHR_Overlay.Buffs.otomo_moves"),
		misc_buffs = require("MHR_Overlay.Buffs.misc_buffs")
	};

	for category_name, category in pairs(buff_categories) do
		if category.list then
			for buff_key, buff in pairs(category.list) do
				if buff and buff.name then
					table.insert(buff_list, {
						name = buff.name,
						type = buff.type,
						key = buff.key,
						level = buff.level,
						timer = buff.timer,
						duration = buff.duration,
						is_infinite = buff.is_infinite,
						minutes_left = buff.minutes_left,
						seconds_left = buff.seconds_left
					});
				end
			end
		end
	end

	return buff_list;
end

function this.extract_large_monsters()
	local monster_list = {};

	if singletons.enemy_manager == nil then
		return monster_list;
	end

	local enemy_manager = singletons.enemy_manager;
	local enemy_count = get_boss_enemy_count_method:call(enemy_manager);

	for i = 0, enemy_count - 1 do
		local enemy = get_boss_enemy_method:call(enemy_manager, i);
		if enemy == nil then
			goto continue;
		end

		local monster = large_monster.list[enemy];
		if monster == nil then
			goto continue;
		end

		local monster_data = {
			name = monster.name,
			id = monster.id,
			unique_id = monster.unique_id,
			is_large = monster.is_large,
			dead_or_captured = monster.dead_or_captured,
			position = {
				x = monster.position.x,
				y = monster.position.y,
				z = monster.position.z
			},
			head_position = {
				x = monster.head_position.x,
				y = monster.head_position.y,
				z = monster.head_position.z
			},
			health = {
				current = monster.health,
				max = monster.max_health,
				percentage = monster.health_percentage,
				missing = monster.missing_health
			},
			capture = {
				health = monster.capture_health,
				percentage = monster.capture_percentage,
				is_capturable = monster.is_capturable
			},
			stamina = {
				current = monster.stamina,
				max = monster.max_stamina,
				percentage = monster.stamina_percentage,
				is_tired = monster.is_tired,
				tired_timer = monster.tired_timer,
				tired_duration = monster.tired_duration
			},
			rage = {
				point = monster.rage_point,
				limit = monster.rage_limit,
				percentage = monster.rage_percentage,
				is_in_rage = monster.is_in_rage,
				timer = monster.rage_timer,
				duration = monster.rage_duration
			},
			stealth = {
				is_stealth = monster.is_stealth,
				can_go_stealth = monster.can_go_stealth
			},
			size = {
				value = monster.size,
				small_border = monster.small_border,
				big_border = monster.big_border,
				king_border = monster.king_border,
				crown = monster.crown
			},
			rider_id = monster.rider_id,
			is_anomaly = monster.is_anomaly,
			parts = this.extract_body_parts(monster),
			ailments = this.extract_monster_ailments(monster)
		};

		table.insert(monster_list, monster_data);

		::continue::
	end

	return monster_list;
end

function this.extract_body_parts(monster)
	local parts_list = {};

	if monster.parts == nil then
		return parts_list;
	end

	for part_id, part in pairs(monster.parts) do
		local part_data = {
			name = part.name,
			id = part.id,
			health = {
				current = part.health,
				max = part.max_health,
				percentage = part.health_percentage
			},
			break_info = {
				current = part.break_current,
				max = part.break_max,
				count = part.break_count,
				max_count = part.break_max_count
			},
			loss = {
				current = part.loss_current,
				max = part.loss_max,
				is_severed = part.is_severed
			},
			anomaly = {
				current = part.anomaly_current,
				max = part.anomaly_max,
				is_active = part.anomaly_is_active
			}
		};

		table.insert(parts_list, part_data);
	end

	return parts_list;
end

function this.extract_monster_ailments(monster)
	local ailment_list = {};

	if monster.ailments == nil or monster.ailments.list == nil then
		return ailment_list;
	end

	for ailment_key, ailment in pairs(monster.ailments.list) do
		if ailment and ailment.name then
			local ailment_data = {
				name = ailment.name,
				key = ailment_key,
				timer = ailment.timer,
				max_timer = ailment.max_timer,
				is_active = ailment.is_active,
				buildups = this.extract_ailment_buildups(monster, ailment_key)
			};

			table.insert(ailment_list, ailment_data);
		end
	end

	return ailment_list;
end

function this.extract_ailment_buildups(monster, ailment_key)
	local buildup_list = {};

	if monster.ailment_buildup_list == nil then
		return buildup_list;
	end

	local buildup_data = monster.ailment_buildup_list[ailment_key];
	if buildup_data == nil or buildup_data.buildups == nil then
		return buildup_list;
	end

	for player_id, buildup in pairs(buildup_data.buildups) do
		if buildup and buildup.buildup ~= nil then
			table.insert(buildup_list, {
				player_id = player_id,
				buildup = buildup.buildup,
				max_buildup = buildup.max_buildup,
				percentage = buildup.percentage
			});
		end
	end

	return buildup_list;
end

function this.extract_small_monsters()
	local monster_list = {};

	if singletons.enemy_manager == nil then
		return monster_list;
	end

	local enemy_manager = singletons.enemy_manager;
	local enemy_count = get_enemy_count_method:call(enemy_manager);

	for i = 0, enemy_count - 1 do
		local enemy = get_enemy_method:call(enemy_manager, i);
		if enemy == nil then
			goto continue;
		end

		local monster = small_monster.list[enemy];
		if monster == nil then
			goto continue;
		end

		if monster.is_large then
			goto continue;
		end

		local monster_data = {
			name = monster.name,
			id = monster.id,
			is_large = monster.is_large,
			dead_or_captured = monster.dead_or_captured,
			position = {
				x = monster.position.x,
				y = monster.position.y,
				z = monster.position.z
			},
			head_position = {
				x = monster.head_position.x,
				y = monster.head_position.y,
				z = monster.head_position.z
			},
			health = {
				current = monster.health,
				max = monster.max_health,
				percentage = monster.health_percentage
			},
			ailments = this.extract_small_monster_ailments(monster)
		};

		table.insert(monster_list, monster_data);

		::continue::
	end

	return monster_list;
end

function this.extract_small_monster_ailments(monster)
	local ailment_list = {};

	if monster.ailments == nil or monster.ailments.list == nil then
		return ailment_list;
	end

	for ailment_key, ailment in pairs(monster.ailments.list) do
		if ailment and ailment.name then
			local ailment_data = {
				name = ailment.name,
				key = ailment_key,
				timer = ailment.timer,
				max_timer = ailment.max_timer,
				is_active = ailment.is_active
			};

			table.insert(ailment_list, ailment_data);
		end
	end

	return ailment_list;
end

-- function this.get_world_endemic_life_counts()
-- 	local counts = {
-- 		wirebugs = 0,
-- 		flies = 0,
-- 		lampreys = 0,
-- 		others = 0
-- 	};

-- 	local success, result = pcall(function()
-- 		if env_creature.list then
-- 			for _, creature in pairs(env_creature.list) do
-- 				if creature and creature.id then
-- 					local id = creature.id;
-- 					-- Wirebugs: 62 (ruby), 63 (gold)
-- 					if id == 62 or id == 63 then
-- 						counts.wirebugs = counts.wirebugs + 1;
-- 					-- Flies: 7 (clothfly), 28 (butterflame), 29 (peepersects), 50 (cutterfly)
-- 					elseif id == 7 or id == 28 or id == 29 or id == 50 then
-- 						counts.flies = counts.flies + 1;
-- 					-- Lampreys: 34 (red), 35 (yellow)
-- 					elseif id == 34 or id == 35 then
-- 						counts.lampreys = counts.lampreys + 1;
-- 					-- Others: 23 (stinkmink)
-- 					else
-- 						counts.others = counts.others + 1;
-- 					end
-- 				end
-- 			end
-- 		end

-- 		return counts;
-- 	end)
-- 	print("EC list size: " .. (env_creature.list and #env_creature.list or 0));

-- 	return success and result or counts;
-- end

-- function this.extract_endemic_life()
-- 	local world_counts = this.get_world_endemic_life_counts();
-- 	local active_ec = this.get_active_endemic_life();
-- 	local consumed = this.get_consumed_items();

-- 	return {
-- 		world = world_counts,
-- 		player_active = active_ec,
-- 		consumed = consumed
-- 	};
-- end

this.init_module();

return this;