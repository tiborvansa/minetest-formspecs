--------------------------------------------------------
-- Minetest :: ActiveFormspecs Mod v2.1 (formspecs)
--
-- See README.txt for licensing and release notes.
-- Copyright (c) 2016-2018, Leslie Ellen Krause
--
-- ./games/just_test_tribute/mods/formspecs/init.lua
--------------------------------------------------------

print( "Loading ActiveFormspecs Mod" )

minetest.FORMSPEC_SIGEXIT = true	-- player clicked exit button or pressed esc key (boolean for backward compatibility)
minetest.FORMSPEC_SIGQUIT = 1		-- player logged off
minetest.FORMSPEC_SIGKILL = 2		-- player was killed
minetest.FORMSPEC_SIGTERM = 3		-- server is shutting down
minetest.FORMSPEC_SIGFORM = 4		-- closure requested
minetest.FORMSPEC_SIGTIME = 5		-- timeout reached

local afs = { }		-- obtain localized, protected namespace

afs.forms = { }
afs.session_id = 0
afs.session_seed = math.random( 0, 65535 )

-----------------------------------------------------------------
-- create node-dependent formspecs during registration
-----------------------------------------------------------------

local on_rightclick = function( pos, node, player )
	-- should be passing meta to on_open( ) and on_close( ) as first param?
	-- local meta = { pos = pos, node = node }
	local formspec = minetest.registered_nodes[ node.name ].on_open( pos, player )
	if formspec then
		minetest.create_form( pos, player, formspec, minetest.registered_nodes[ node.name ].on_close )
	end
end

local old_register_node = minetest.register_node
local old_override_item = minetest.override_item

minetest.register_node = function ( name, def )
	if def.on_open and not def.on_rightclick then
		def.on_rightclick = on_rightclick
	end
	old_register_node( name, def )
end

minetest.override_item = function ( name, def )
	if minetest.registered_nodes[ name ] and def.on_open then
		def.on_rightclick = on_rightclick
	end
	old_override_item( name, def )
end

-----------------------------------------------------------------
-- invoke callback for detached formspec with state table
-----------------------------------------------------------------

minetest.register_on_player_receive_fields( function( player, formname, fields )
	local form = afs.forms[ player:get_player_name( ) ]

	-- perform a basic sanity check, since these shouldn't technically occur
	if not form or player ~= form.player or formname ~= form.name then return end
	
	form.proc( form.meta, form.player, fields )

	-- revoke current session when formspec is closed
	if fields.quit then
		afs.forms[ player:get_player_name( ) ] = nil
	end
end )

-----------------------------------------------------------------
-- open detached formspec
-----------------------------------------------------------------
-- possibly change order of params and accept player_name instead?
-- minetest.create_form = function ( player_name, formspec, meta, proc )

minetest.create_form = function ( meta, player, formspec, proc )
	local form = { }

	-- short circuit whenever required params are missing
	if not player or not formspec or not proc then return end

	-- invoke new session when formspec is opened
	afs.session_id = afs.session_id + 1

	form.player = player
	form.name = minetest.get_password_hash( player:get_player_name( ), afs.session_seed + afs.session_id )
	form.proc = proc
	form.meta = meta or { }
	form.timer = 0

	-- public methods for use by callbacks (still wip)
	form.update = function ( self, formspec )
		minetest.update_form( self.player, formspec )
	end
	form.destroy = function ( self )
		minetest.destroy_form( self.player )
	end

	-- hidden elements only provide default, initial values 
	-- for state table and are always stripped afterward
	formspec = string.gsub( formspec, "hidden%[(.-);(.-)%]", function( key, value )
		if form.meta[ key ] == nil then
			local data, type = string.match( value, "^(.-);(.-)$" )

			-- parse according to specified data type
			if type == "string" or type == "" then
				form.meta[ key ] = data
			elseif type == "number" then
				form.meta[ key ] = tonumber( data )
			elseif type == "boolean" then
				form.meta[ key ] = ( { ["1"] = true, ["0"] = false, ["true"] = true, ["false"] = false } )[ data ]
			elseif type == nil then
				form.meta[ key ] = value	-- default to string, if no data type specified
			end
		end
		return ""	-- strip hidden elements prior to showing formspec
	end )

	afs.forms[ player:get_player_name( ) ] = form
	minetest.show_formspec( player:get_player_name( ), form.name, formspec )

	return form.name
end

-----------------------------------------------------------------
-- reset detached formspec
-----------------------------------------------------------------

minetest.update_form = function ( player, formspec )
	local pname = player:get_player_name( )
	local form = afs.forms[ pname ]

	minetest.show_formspec( pname, form.name, formspec )
end

-----------------------------------------------------------------
-- close detached formspec
-----------------------------------------------------------------

minetest.destroy_form = function ( player )
	local pname = player:get_player_name( )
	local form = afs.forms[ pname ]

	minetest.close_formspec( pname, form.name )

	form.proc( form.meta, player, { quit = minetest.FORMSPEC_SIGFORM } )
	afs.forms[ pname ] = nil
end

-----------------------------------------------------------------
-- signal callbacks after unexpected formspec termination
-----------------------------------------------------------------

minetest.register_on_leaveplayer( function( player, is_timeout )
	local pname = player:get_player_name( )
	local form = afs.forms[ pname ]

	if form then
		form.proc( form.meta, player, { quit = minetest.FORMSPEC_SIGQUIT } )
		afs.forms[ pname ] = nil
	end
end )

minetest.register_on_dieplayer( function( player )
	local pname = player:get_player_name( )
	local form = afs.forms[ pname ]

	if form then
		form.proc( form.meta, player, { quit = minetest.FORMSPEC_SIGKILL } )
		afs.forms[ pname ] = nil
	end
end )

minetest.register_on_shutdown( function( )
	for _, form in pairs( afs.forms ) do
		form.proc( form.meta, form.player, { quit = minetest.FORMSPEC_SIGTERM } )
	end
	afs.forms = { }
end )
