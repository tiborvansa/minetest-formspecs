--------------------------------------------------------
-- Minetest :: ActiveFormspecs Mod v2.0 (formspecs)
--
-- NOTE: You must add to depends.txt in default mod!
--
-- See README.txt for licensing and other information.
-- Copyright (c) 2016-2017, Leslie Ellen Krause
--
-- ./games/just_test_tribute/mods/formspecs/init.lua
--------------------------------------------------------

print( "Loading ActiveFormspecs Mod" )

minetest.forms = { }
minetest.form_id = 0

-----------------------------------------------------------------
-- create node-dependent formspecs during registration
-----------------------------------------------------------------

minetest.old_register_node = minetest.register_node

minetest.register_node = function ( name, fields )
	if fields.on_open and not fields.on_rightclick then
		fields.on_rightclick = function( pos, node, player )
			-- should be passing meta to on_open( ) and on_close( ) as first param?
			-- local meta = { pos = pos, node = node }
			local formspec = minetest.registered_nodes[ node.name ].on_open( pos, player )
			if formspec then
				minetest.create_form( pos, player, formspec, minetest.registered_nodes[ node.name ].on_close )
			end
		end
	end
	minetest.old_register_node( name, fields )
end

-----------------------------------------------------------------
-- invoke callback for detached formspec with metadata
-----------------------------------------------------------------

minetest.register_on_player_receive_fields( function( player, formname, fields )
	local form = minetest.forms[ player:get_player_name( ) ]

	if form then
		-- perhaps we should merge meta into fields table?
		form.proc( form.meta, player, fields )

		if fields.quit then
			minetest.forms[ player:get_player_name( ) ] = nil
		end
	end
end )

-----------------------------------------------------------------
-- open detached formspec
-----------------------------------------------------------------
-- CHANGE TO
-- minetest.create_form = function ( player_name, formspec, meta, proc )

minetest.create_form = function ( meta, player, formspec, proc )
	local param, value
	local form = { }

	minetest.form_id = minetest.form_id + 1
	form.name = player:get_player_name( ) .. ":" .. string.format( "%#06x", minetest.form_id )
	form.proc = proc

	if meta then
		form.meta = meta
	else
		form.meta = { }
		for param, value in string.gmatch( formspec, 'hidden%[(.-);(.-)%]' ) do
			form.meta[ param ] = value
		end
	end

	minetest.forms[ player:get_player_name( ) ] = form
	minetest.show_formspec( player:get_player_name( ), form.name, formspec )

	return form.name
end

-----------------------------------------------------------------
-- reset detached formspec
-----------------------------------------------------------------

minetest.update_form = function ( player, formspec )
	local form = minetest.forms[ player:get_player_name( ) ]

	minetest.show_formspec( player:get_player_name( ), form.name, formspec )
end

-----------------------------------------------------------------
-- close active formspec
-----------------------------------------------------------------

minetest.destroy_form = function ( player )
	local form = minetest.forms[ player:get_player_name( ) ]

--	minetest.show_formspec( player:get_player_name( ), form.name, "" )
--	form.proc( form.meta, player, { quit = true } )
end
