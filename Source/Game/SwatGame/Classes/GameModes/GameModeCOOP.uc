// GameModeCOOP.uc

class GameModeCOOP extends GameModeMPBase
    implements IInterested_GameEvent_MissionCompleted,
               IInterested_GameEvent_MissionFailed
    ;

var private bool bMissionCompleted;

function OnMissionEnded()
{
    Super.OnMissionEnded();
    SGI.gameEvents.MissionFailed.UnRegister(self);
    SGI.gameEvents.MissionCompleted.UnRegister(self);
}

function OnMissionCompleted()
{
    bMissionCompleted = true;
}

function OnMissionFailed()
{
    bMissionCompleted = false;
}

function EndGame()
{
    if( bMissionCompleted )
        NetRoundFinished( SRO_COOPCompleted );
    else
        NetRoundFinished( SRO_COOPFailed );
}


function Initialize()
{
    mplog( "Initialize() in GameModeCOOP." );
    Super.Initialize();
}

// This is meant to do things like select which player has which voice set
function AssignPlayerRoles()
{
    //do nothing for now
}


// return a start point from the selected entry spawn cluster 
function SwatMPStartPoint FindNetPlayerStart( Controller Player )
{
    return Super.FindNetPlayerStart( Player );
}

// not used in COOP
function NetRoundTimeRemaining( int TimeRemaining ) 
{
    //coop mid-game is untimed
    if( SwatRepo(Level.GetRepo()).GuiConfig.SwatGameState == GAMESTATE_MidGame )
        TimeRemaining = 0;
        
    Super.NetRoundTimeRemaining( TimeRemaining );
}

// not used in COOP
function NetRoundTimerExpired() {}

// not used in COOP
function SetSuspectsSpawnCluster( name NewSuspectsSpawnCluster ) {}

// not used in COOP
function RespawnAll() {}

//called when a player joins a team
// not used in COOP
function PlayerJoinedTeam( SwatGamePlayerController Player, int team ) {}

// Override in derived class.
function bool ValidSpawnClusterForMode( SwatMPStartCluster theCluster )
{
    //only swat spawns allowed in coop
    return theCluster.ClusterTeam == MPT_Swat;
}

// Override in derived classes
function bool ClusterPointValidForRoundStart( SwatMPStartCluster thePoint )
{
    if( ServerSettings(Level.CurrentServerSettings).DesiredMPEntryPoint == ET_Primary )
        return thePoint.IsPrimaryEntryPoint;
    else
        return thePoint.IsSecondaryEntryPoint;
}

