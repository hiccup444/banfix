extends Node

var banned_players = {}  # Tracks banned players by Steam ID
var GAME_MASTER = false  # Tracks if the user is the lobby's game master
var STEAM_LOBBY_ID = 0   # Current lobby ID
var SteamNetwork  # Placeholder for SteamNetwork node reference

# Initialize the mod
func _ready():
	print("Mod initialized: /ban and /unban commands enabled.")
	SteamNetwork = find_steam_network()
	if SteamNetwork and SteamNetwork.is_instance_valid():
		initialize_lobby_state()
	else:
		print("SteamNetwork node is not available or valid. Falling back to limited functionality.")

# Find the SteamNetwork node dynamically
func find_steam_network():
	var root = get_tree().root
	for child in root.get_children():
		if child.has_method("steamInit"):
			return child
	return null

# Setup initial lobby information
func initialize_lobby_state():
	var init = SteamNetwork.call("steamInit") if SteamNetwork else null
	if init and init.get("status", 0) == 1:  # Check if Steam initialized successfully
		STEAM_LOBBY_ID = Steam.getLobbyId()
		if Steam.getLobbyOwner(STEAM_LOBBY_ID) == Steam.getSteamID():
			GAME_MASTER = true
		else:
			GAME_MASTER = false
		connect_lobby_signals()
	else:
		print("Steam initialization failed or not configured.")

# Connect to necessary Steam signals
func connect_lobby_signals():
	Steam.connect("lobby_chat_update", self, "_on_lobby_chat_update")
	Steam.connect("p2p_session_request", self, "_on_p2p_session_request")

# Refresh the list of lobby members
func refresh_lobby_members():
	if STEAM_LOBBY_ID > 0:
		var member_count = Steam.getNumLobbyMembers(STEAM_LOBBY_ID)
		for i in range(member_count):
			var member_id = Steam.getLobbyMemberByIndex(STEAM_LOBBY_ID, i)
			if member_id in banned_players:
				force_disconnect_player(member_id)

# Ban a player by their display name
func ban_player_by_name(display_name):
	for i in range(Steam.getNumLobbyMembers(STEAM_LOBBY_ID)):
		var member_id = Steam.getLobbyMemberByIndex(STEAM_LOBBY_ID, i)
		var member_name = Steam.getFriendPersonaName(member_id)
		if member_name.to_lower() == display_name.to_lower():
			ban_player(member_id)
			return
	print("Player not found: " + display_name)

# Unban a player by their display name
func unban_player_by_name(display_name):
	for steam_id in banned_players.keys():
		var member_name = Steam.getFriendPersonaName(steam_id)
		if member_name.to_lower() == display_name.to_lower():
			unban_player(steam_id)
			return
	print("Player not found: " + display_name)

# Ban a player by their Steam ID
func ban_player(steam_id):
	if steam_id in banned_players:
		print("Player is already banned.")
		return
	banned_players[steam_id] = true
	print("Banning player: " + str(steam_id))
	update_lobby_ban_list()
	force_disconnect_player(steam_id)

# Unban a player by their Steam ID
func unban_player(steam_id):
	if steam_id in banned_players:
		banned_players.erase(steam_id)
		print("Unbanning player: " + str(steam_id))
		update_lobby_ban_list()
	else:
		print("Player is not banned: " + str(steam_id))

# Update the lobby's ban list
func update_lobby_ban_list():
	if GAME_MASTER and STEAM_LOBBY_ID > 0:
		var ban_list = ",".join(banned_players.keys())
		Steam.setLobbyData(STEAM_LOBBY_ID, "banned_players", ban_list)

# Forcefully disconnect a player
func force_disconnect_player(steam_id):
	if steam_id in Steam.getLobbyMembers(STEAM_LOBBY_ID):  # Validate if still connected
		Steam.closeP2PSessionWithUser(steam_id)
		print("Player disconnected: " + str(steam_id))

# Handle P2P session requests
func _on_p2p_session_request(remote_id):
	if remote_id in banned_players:
		print("Denying session for banned player: " + str(remote_id))
		Steam.closeP2PSessionWithUser(remote_id)
		return
	print("Accepting session request from: " + str(remote_id))
	Steam.acceptP2PSessionWithUser(remote_id)
