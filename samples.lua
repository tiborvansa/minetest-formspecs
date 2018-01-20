-- How to try this example:
-- 1) Move this file into a new "afs_test" directory under mods and rename it "init.lua".
-- 2) Create a "depends.txt" file in the new directory with the following lines of text:
--		nyancat
--		formspecs
-- 3) Launch your Minetest server and enable the "afs_test" mod. Then, login as usual!

minetest.register_privilege( "uptime", "View the uptime of the server interactively" )

local get_nyancat_formspec = function( meta )
	local uptime = minetest.get_server_uptime( )
	local formspec = "size[4,4]"
		.. default.gui_bg_img
		.. string.format( "label[0.5,0.5;%s %0.1f %s]",
			minetest.colorize( "#FFFF00", "Server Uptime:" ),
			meta.is_minutes and uptime / 60 or uptime,
			meta.is_minutes and "mins" or "secs"
		)
		.. "checkbox[0.5,1;is_minutes;Show Minutes;" .. tostring( meta.is_minutes ) .. "]"
		.. "button[0.5,2;2.5,1;update;Refresh]"
		.. "button_exit[0.5,3;2.5,1;close;Close]"
		.. "hidden[view_count;1;number]"
		.. "hidden[view_limit;5;number]"		-- limit the number of refreshes!
	return formspec
end

minetest.override_item( "nyancat:nyancat", {
	description = "System Monitor",
        
	on_open = function( meta, player )
		local player_name = player:get_player_name( )

		if meta.is_minutes == nil then meta.is_minutes = true end

		if minetest.check_player_privs( player, "uptime" ) then
			return get_nyancat_formspec( meta )
		else
                        minetest.chat_send_player( player_name, "Your privileges are insufficient." )
		end
	end,
	on_close = function( meta, player, fields )
		if not minetest.check_player_privs( player, "uptime" ) then return end

		if meta.view_count == meta.view_limit then
			minetest.destroy_form( player )
			print( "afs_test: Player exceeded refresh limit." )
		elseif fields.update then
			meta.view_count = meta.view_count + 1
			minetest.update_form( player, get_nyancat_formspec( meta ) )
		elseif fields.is_minutes then
			meta.is_minutes = fields.is_minutes == "true"
			minetest.update_form( player, get_nyancat_formspec( meta ) )
		end
	end
} )

minetest.register_chatcommand( "uptime", {
	description = "View the uptime of the server interactively",
	func = function( name, param )
		local get_formspec = function( meta )
			local uptime = minetest.get_server_uptime( )

			local formspec = "size[4,3]"
				.. default.gui_bg_img
				.. string.format( "label[0.5,0.5;%s %0.1f %s]",
					minetest.colorize( "#FFFF00", "Server Uptime:" ),
					meta.is_minutes and uptime / 60 or uptime,
					meta.is_minutes and "mins" or "secs"
				)
				.. "checkbox[0.5,1;is_minutes;Show Minutes;" .. tostring( meta.is_minutes ) .. "]"
				.. "button[0.5,2;2.5,1;update;Refresh]"
			return formspec
		end
		local on_close = function( meta, player, fields )
			if fields.update then
				minetest.update_form( player, get_formspec( meta ) )
			elseif fields.is_minutes then
				meta.is_minutes = fields.is_minutes == "true"
				minetest.update_form( player, get_formspec( meta ) )
			end
		end

		local player = minetest.get_player_by_name( name )
		local meta = { is_minutes = false }
		
		minetest.create_form( meta, player, get_formspec( meta ), on_close )
	end
} )
