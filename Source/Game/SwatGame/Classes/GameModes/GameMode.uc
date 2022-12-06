// GameMode.uc

class GameMode extends Engine.Actor
    abstract
    config(SwatGame)
    native;

var SwatGameInfo SGI;

//Force game over
function EndGame()
{
    Assert( false );
}

function Initialize()
{
    mplog( self$"---GameMode::Initialize()." );
    SGI = SwatGameInfo(Owner);
    Assert( SGI != None ); 
}

// Override in derived class.
function OnMissionEnded();

// Override in derived class.
function SetStartClustersForRoundStart()
{
    Assert( false );
}


// This is meant to do things like select which player is the VIP.
function AssignPlayerRoles()
{
    Assert( false );
}


// Override in derived class.
function SwatMPStartPoint FindNetPlayerStart( Controller Player )
{
    Assert( false );
    return None;
}


// Override in derived class.
function NetRoundTimeRemaining( int TimeRemaining )
{
    Assert( false );
}


// Override in derived class.
function NetRoundTimerExpired()
{
    Assert( false );
}

// Override in derived class.
function SetSpawnClusterEnabled( name ClusterName, bool SetEnabled )
{
    Assert( false );
}

// Override in derived class.
function RespawnAll()
{
    Assert( false );
}


//called when a player joins a team
// subclasses should implement
function PlayerJoinedTeam( SwatGamePlayerController Player, int team ) 
{
    Assert( false );
}

defaultproperties
{
    bHidden=true
}
