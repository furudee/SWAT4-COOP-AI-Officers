class GameSpyManager extends Core.Object
	native;

enum EGSProfileResult
{
	CPR_VALID,
	CPR_BAD_EMAIL,
	CPR_BAD_PASSWORD,
	CPR_BAD_NICK
};

var GameEngine	Engine;

var const bool	bAvailable;
var const bool	bFailedAvailabilityCheck;

var const bool	bInitAsServer;
var const bool	bInitAsClient;

var const bool	bInitialised;
var const bool	bFailedInitialisation;

#if IG_SWAT
var bool bServer; // true if we're a server, false if a client
#endif

var const bool	bTrackingStats;				// If true try to initialise the stat tracker
var const bool	bStatsInitalised;

var const bool	bUsingPresence;				// If true try to initialise the presence sdk
var const bool	bPresenceInitalised;

var const bool	bServerUpdateFinished;		// Used during GetNextServer
var const int	currentServerIndex;			// Used during GetNextServer

var Array<byte> ServerKeyIds;
var Array<String> ServerKeyNames;

var Array<byte> PlayerKeyIds;
var Array<String> PlayerKeyNames;

var Array<byte> TeamKeyIds;
var Array<String> TeamKeyNames;

var Array<byte> CustomServerKeyIds;
var Array<String> CustomServerKeyNames;

var Array<byte> CustomPlayerKeyIds;
var Array<String> CustomPlayerKeyNames;

var Array<byte> CustomTeamKeyIds;
var Array<String> CustomTeamKeyNames;

// This function initialises GameSpy as a client
// Note: This function only tells GameSpy to initialise it may take longer and wont be initialised after returning from this function
// The GameSpyInitialised event will be called once GameSpy has finished initalising.
// There is no need for a script side function to init as a server as this is done automatically in native code when a server starts
final native function InitGameSpyClient();

// This event is called once GameSpy as initialised
event GameSpyInitialised();

event InitGameSpyData();
final native function LevelInfo GetLevelInfo();

final native function Player GetPlayerObject();

// This function starts an update of the server list
final native function UpdateServerList(optional String filter);

// This function starts an update of the server list for the LAN
final native function LANUpdateServerList();

// This function starts an update for a specific server in the list to update server specific data (player/team data)
// serverId is the server id received in UpdatedServerData during a server list update
// if refresh is true then the update will be done even if the server data is already available
final native function UpdateServer(int serverId, bool Refresh);

// This function will cancel a previously started update of the server list
final native function CancelUpdate();

// This function returns the ip address for the given serverId
final native function String GetServerIpAddress(int serverId);

// This function returns the port for the given serverId
final native function String GetServerPort(int serverId);

// This function can be used to iterate over all the servers currently in the list
// Returns true if there is still more data, but the data may not have arrived yet
// If the data has not arrived yet serverId will be zero
final native function bool GetNextServer(out int serverId, out String ipAddress, out Array<String> serverData);

// Call this function when a new game starts to tell the stat tracking server
final native function StatsNewGameStarted();

// Call this function to verify that a connected player has a profile id and stat response string
final native function bool StatsHasPIDAndResponse(PlayerController pc);

// Call this function to get the profile id for the given player controller
final native function String StatsGetPID(PlayerController pc);

// Call this function to get the stat response string for the given player controller
final native function String StatsGetStatResponse(PlayerController pc);

// Call this function to add a new player to the stat tracking server
final native function StatsNewPlayer(int PlayerId, string PlayerName);

// Call this function to add a new team to the stat tracking server
final native function StatsNewTeam(int TeamID, string TeamName);

// Call this function to remove a player from the stat tracking server
final native function StatsRemovePlayer(int PlayerId);

// Call this function to remove a team from the stat tracking server
final native function StatsRemoveTeam(int TeamID);

// Set the value of a server related stat
final native function SetServerStat(coerce string statName, coerce string statValue);

// Set the value of a player specific stat
final native function SetPlayerStat(coerce string statName, coerce string statValue, int PlayerId);

// Set the value of a team specific stat
final native function SetTeamStat(coerce string statName, coerce string statValue, int TeamID);

// Call this function to send a snapshot of the game stats to the stat server. Set finalSnapshot to true if the game has ended (default false)
final native function SendStatSnapshot(optional bool finalSnapshot);

#if !IG_SWAT

// Call this function to create a new user account
final native function CreateUserAccount(string Nick, string Email, string Password);

// Call this function to check with GameSpy that the given account details are valid
final native function CheckUserAccount(string Nick, string Email, string Password);

#endif // !IG_SWAT

// This function is called each time a servers data is updated
event UpdatedServerData(int serverId, String ipAddress, int Ping, Array<String> serverData, Array<String> playerData, Array<String> teamData);

// This function is called after an update of the server list completes
event UpdateComplete();

// This function is called on the server to get the data for a particular server key
event string GetValueForKey(int key);

// This function is called on the server to get the data for a particular player key
event string GetValueForPlayerKey(int key, int index);

// This function is called on the server to get the data for a particular team key
event string GetValueForTeamKey(int key, int index);

event int GetNumTeams()
{
	return 0;
}

// Client side function to get the user's GameSpy profile id
event String GetGameSpyProfileId();

event String GetGameSpyPassword();

event EmailAlreadyTaken();
event ProfileCreateResult(EGSProfileResult result, int profileId);
event ProfileCheckResult(EGSProfileResult result, int profileId);

#if IG_SWAT
event bool ShouldCheckClientCDKeys()
{
    Assert( false );
    return false;
}

// Call this from script code to uninitialize GameSpy.
final native function CleanUpGameSpy();

// Returns 1 if we should advertise the server on the Internet using
// GameSpy's master server, or 0 if this is just a LAN game.
event int ShouldAdvertiseServerOnInternet();

// Call this, only on the server, after the level finishes loading.
final native function SendServerStateChanged();

// This is a quick check to see if the host's CDKey is valid before allowing
// it to host. It just checks the validity locally, and doesn't connect to the
// GameSpy servers.
final native function bool IsHostCDKeyValid();

#endif

defaultproperties
{
    bServer=false
}

