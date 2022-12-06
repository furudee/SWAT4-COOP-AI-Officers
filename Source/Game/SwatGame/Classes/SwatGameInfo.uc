
class SwatGameInfo extends Engine.GameInfo
    implements IInterested_GameEvent_EvidenceSecured,
               IInterested_GameEvent_ReportableReportedToTOC
    config(SwatGame)
    dependsOn(SwatStartPointBase) 
	dependsOn(SwatOfficerStart)
    dependsOn(SwatGUIConfig)
    native;

//import enum eDifficultyLevel from SwatGame.SwatGUIConfig;
import enum EEntryType from SwatGame.SwatStartPointBase;
import enum Pocket from Engine.HandheldEquipment;
import enum EOfficerStartType from SwatGame.SwatOfficerStart;
import enum EMPMode from Engine.Repo;

// Defines the multiplayer team
enum EMPTeam
{
    // @NOTE: The order of these is currently very important!! MPT_Swat must
    // be 0, and MPT_Suspects must be 1.
	MPT_Swat,    // The SWAT team
	MPT_Suspects // The "Bad Guys" team
};

// Used to indicate the outcome of a multiplayer round
enum ESwatRoundOutcome
{
	SRO_SwatVictoriousNormal,
	SRO_SuspectsVictoriousNormal,
	SRO_SwatVictoriousRapidDeployment,
	SRO_SuspectsVictoriousRapidDeployment,
	SRO_RoundEndedInTie,
	SRO_SwatVictoriousVIPEscaped,
	SRO_SuspectsVictoriousKilledVIPValid,
	SRO_SwatVictoriousSuspectsKilledVIPInvalid,
	SRO_SuspectsVictoriousSwatKilledVIP,
	SRO_COOPCompleted,
	SRO_COOPFailed,
};

var private array<Mesh> PrecacheMeshes;
var private array<StaticMesh> PrecacheStaticMeshes;
var private array<Material> PrecacheMaterials;
var private bool LevelHasFemaleCharacters;

var bool bDebugFrames;
var array<DebugFrameData> DebugFrameData;
var DebugFrameData CurrentDebugFrameData;

var private SpawningManager SpawningManager;

// The Repo
var private SwatRepo Repo;


var GameEventsContainer GameEvents;

var private Timer ObjectiveTimer;

var private NavigationPoint LastPlayerStartSpot;    // last place player looking for start spot started from
var private NavigationPoint LastStartSpot;          // last place any player started from

var private array<PlayerStart> PlayerStartArray;
var private int NextPlayerStartPoint;

// Contains a reference to the current GameMode if our netmode is standalone
// or we are on the server. On network clients, there's no GameInfo anyway.
var private GameMode GameMode;

// Keep track of the last time we called NetRoundTimeRemaining() on the GameMode.
var private int PreviousNetRoundTimeRemaining;

// Global damage modifiers for Single Player games base on difficulty setting
var private config float SPDamageModifierEasy;
var private config float SPDamageModifierNormal;
var private config float SPDamageModifierHard;
var private config float SPDamageModifierElite;

// Global damage modifier for MultiPlayer games
var private config float MPDamageModifier;
var private config float COOPDamageModifier;

// Number of officers that were spawned
var private int NumSpawnedOfficers;

var config bool DebugObjectives;
var config bool DebugLeadership;
var config bool DebugLeadershipStatus;
var config bool DebugSpawning;

var private bool bAlreadyCompleted;
var private bool bAlreadyFailed;
var private bool bAlreadyEnded;

//Update interval for the objectives and procedures
var private config float ScoringUpdateInterval;
//Timer for objectives & procedures updates
var private Timer ScoringUpdateTimer;
var private Timer ReconnectionTimer;
var private config float ReconnectionTime;

//admin feature management
var SwatAdmin Admin;

delegate MissionObjectiveTimeExpired();

///////////////////////////////////////////////////////////////////////////////

function PreBeginPlay()
{
    local SwatPlayerStart Point;

    label = 'Game';

    Repo = SwatRepo(Level.GetRepo());

    // ckline: Only debug objectives, leadership, and spawning if 
    // EnableDevTools=true in [Engine.GameEngine] section
    // of Swat4.ini
    DebugObjectives = DebugObjectives && Level.GetEngine().EnableDevTools;
    DebugLeadership = DebugLeadership && Level.GetEngine().EnableDevTools;
    DebugLeadershipStatus = DebugLeadershipStatus && Level.GetEngine().EnableDevTools;
    DebugSpawning = DebugSpawning && Level.GetEngine().EnableDevTools;

    bAlreadyCompleted=false;
    bAlreadyFailed=false;
    bAlreadyEnded=false;
	bPostGameStarted=false;
    
    // GameEvents needs to exist before the call to Super.PreBeginPlay,
    // which in turn calls InitGameReplicationInfo, which creates the
    // team objects, which depend on GameEvents upon their creation.
    // @TODO: Write a lazy creation accessor for it, make the variable
    // private, and restrict access through that accessor only. [darren]
    GameEvents = new class'GameEventsContainer';

    // In a single player game, we want the player pawns to be spawned
    // immediately. In multiplayer, players start in limbo until choosing
    // their team. [darren]
    if (Level.NetMode != NM_Standalone)
    {
        bDelayedStart = true;
        bTeamGame = true;
    }

    Super.PreBeginPlay();

    Admin = Spawn( class'SwatAdmin' );
    Admin.SetAdminPassword( SwatRepo(Level.GetRepo()).GuiConfig.AdminPassword );
    
    RegisterNotifyGameStarted();

    if (bDebugFrames)
    {
        AddDebugFrameData();
    }

    // Initialize the array of player start points.
	foreach AllActors( class'SwatPlayerStart', Point )
	{
		// we don't want to spawn at Officer Start Points in single player mode
		if ((Level.NetMode != NM_Standalone) || (! Point.IsA('SwatOfficerStart')))
		{
			PlayerStartArray[PlayerStartArray.Length] = Point;
		}
	}

    if (PlayerStartArray.Length == 0)
    {
        // If we don't fatally assert here, the game will go into an infinite loop 
        // spewing to the log. Which sucks.
        assertWithDescription(false , "Fatal Error: Failed to find any SwatPlayerStart points to spawn at -- make sure your start points are SwatPlayerStarts and not PlayerStarts!" );
        assert(false); 
    }

    NextPlayerStartPoint = 0;

    InitializeGameMode();

    if ( Level.NetMode == NM_ListenServer || Level.NetMode == NM_DedicatedServer )
    {
        SetAssertWithDescriptionShouldUseDialog( true );
    }
}


function PostBeginPlay()
{
    Super.PostBeginPlay();
    
    //create and initialize Mission Objectives
    if( Level.NetMode == NM_Standalone || 
        Level.IsCOOPServer )
    {
        if (GetCustomScenario() != None)
            log("[MISSION] Playing Custom Scenario");
        else
            log("[MISSION] Playing a Campaign or Multiplayer Mission (not a Custom Scenario)");

        Repo.MissionObjectives.Initialize( self );
        log("[MISSION] Mission Objectives Initialized for Mission "$Repo.GuiConfig.CurrentMission);

        SpawningManager = SpawningManager(Level.SpawningManager);
        if (SpawningManager == None)
            Warn("SKIPPING SPAWNING: This map has no SpawningManager in its LevelInfo.");
        else
        {
            SpawningManager.Initialize(Level);
            SpawningManager.DoSpawning(self);
        }

        MissionStatus();    //log initial mission status

        //initialize Leadership system
        Repo.Procedures.Init(self);
        
        
        ScoringUpdateTimer = Spawn(class'Timer');
        assert(ScoringUpdateTimer != None);
        ScoringUpdateTimer.timerDelegate = UpdateScoring;
        ScoringUpdateTimer.StartTimer( ScoringUpdateInterval, true );
    }
    
    Level.TickSpecialEnabled = false;
    
    if( Level.NetMode != NM_Standalone && Repo.NumberOfRepoPlayerItems() > GetNumPlayers() )
    {
        ReconnectionTimer = Spawn(class'Timer');
        assert(ReconnectionTimer != None);
        ReconnectionTimer.timerDelegate = ReconnectionTimerExpired;
        ReconnectionTimer.StartTimer( ReconnectionTime );
    }
}

function ReconnectionTimerExpired()
{
    //remove any bogus player items at this time
    Repo.FlushBogusPlayerItems();
        
    //update the waitingForPlayers flag after flushing the items
    TestWaitingForPlayersToReconnect();
    
    if( ReconnectionTimer != None )
        ReconnectionTimer.Destroy();
}

function TestWaitingForPlayersToReconnect()
{
    SwatGameReplicationInfo(GameReplicationInfo).SetWaitingForPlayers( Repo.NumberOfRepoPlayerItems() > GetNumPlayers() );
}

final function UpdateScoring()
{
    local int i;
    local SwatGameReplicationInfo SGRI;

    SGRI = SwatGameReplicationInfo(GameReplicationInfo);

    for( i = 0; i < SGRI.MAX_PROCEDURES; i++ )
    {
        if( i < Repo.Procedures.Procedures.Length &&
            ( Repo.GuiConfig.SwatGameState != GAMESTATE_MidGame ||
              Repo.Procedures.Procedures[i].IsShownInObjectivesPanel ) ) //Dont update PostGame only procedures during the game
        {
            SGRI.ProcedureCalculations[i] = Repo.Procedures.Procedures[i].Status();
            SGRI.ProcedureValue[i] = Repo.Procedures.Procedures[i].GetCurrentValue();
        }
    }

    for( i = 0; i < SGRI.MAX_OBJECTIVES; i++ )
    {
        if( i < Repo.MissionObjectives.Objectives.Length )
        {
            SGRI.ObjectiveStatus[i] = Repo.MissionObjectives.Objectives[i].GetStatus();
        }
    }
}

//////////////////////////////////////////////////////////////////////////////////////
// Special triggers
//////////////////////////////////////////////////////////////////////////////////////
function BombExploded()
{
    //broadcast the event to all clients
    Broadcast( None, "", 'BombExploded' );
    }

//////////////////////////////////////////////////////////////////////////////////////
// Mission Objectives
//////////////////////////////////////////////////////////////////////////////////////
final function ClearTimedMissionObjective()
{
    local SwatGameReplicationInfo SGRI;

    SGRI = SwatGameReplicationInfo(GameReplicationInfo);
    SGRI.SpecialTime = 0;
    SGRI.TimedObjectiveIndex = -1;
    
    MissionObjectiveTimeExpired = None;

    if( ObjectiveTimer != None )
        ObjectiveTimer.Destroy();
}

final function SetTimedMissionObjective(Objective Objective)
{
    local SwatGameReplicationInfo SGRI;
    local int i;

    SGRI = SwatGameReplicationInfo(GameReplicationInfo);
    SGRI.SpecialTime = Objective.Time;

    for( i = 0; i < Repo.MissionObjectives.Objectives.Length; i++ )
    {
        if( Repo.MissionObjectives.Objectives[i] == Objective )
        {
            SGRI.TimedObjectiveIndex = i;
            break;
        }
}

    MissionObjectiveTimeExpired = Objective.OnTimeExpired;
    
    ObjectiveTimer = Spawn(class'Timer');
    assert(ObjectiveTimer != None);
    ObjectiveTimer.timerDelegate = UpdateTimedMissionObjective;
    ObjectiveTimer.StartTimer( 1.0, true );
}

final function UpdateTimedMissionObjective()
{
    local SwatGameReplicationInfo SGRI;

    SGRI = SwatGameReplicationInfo(GameReplicationInfo);

    SGRI.SpecialTime--;
    if( SGRI.SpecialTime <= 0 )
        MissionObjectiveTimeExpired();
}

final function OnMissionObjectiveCompleted(Objective Objective)
{
    if (DebugObjectives)
        log("[OBJECTIVES] "$Objective.name$" ("$Objective.Description$") Completed");

    //TODO/COOP: Broadcast message to all clients, have the clients internally dispatchMessage
    dispatchMessage(new class'MessageMissionObjectiveCompleted'(Objective.name));

    if( Repo.GuiConfig.CurrentMission.IsMissionCompleted() )
    {
        if( !bAlreadyCompleted && !bAlreadyFailed )
            MissionCompleted();
        OnCriticalMoment();
    }
}

final function OnMissionObjectiveFailed(Objective Objective)
{
    if (DebugObjectives) 
        log("[OBJECTIVES] "$Objective.name$" ("$Objective.Description$") Failed");

    //TODO/COOP: Broadcast message to all clients, have the clients internally dispatchMessage
    dispatchMessage(new class'MessageMissionObjectiveFailed'(Objective.name));

    if( Repo.GuiConfig.CurrentMission.IsMissionFailed() )
    {
        if( !bAlreadyFailed )
            MissionFailed();
        OnCriticalMoment();
    }
}

final function MissionCompleted()
{
    log("[dkaplan] >>> MissionCompleted" );
    bAlreadyCompleted=true;
    Broadcast( None, "", 'MissionCompleted' );    

    GameEvents.ReportableReportedToTOC.Register(self);
    GameEvents.EvidenceSecured.Register(self);

    GameEvents.MissionCompleted.Triggered();
}

final function MissionFailed()
{
    log("[dkaplan] >>> MissionFailed" );
    bAlreadyFailed=true;
    Broadcast( None, "", 'MissionFailed' );    

    GameEvents.ReportableReportedToTOC.Register(self);
    GameEvents.EvidenceSecured.Register(self);

    GameEvents.MissionFailed.Triggered();
}

final function MissionEnded()
{
    log("[dkaplan] >>> MissionEnded" );
    
    //dont trigger game ended twice
    if( bAlreadyEnded )
        return;
        
    //for the case where the mission ends before a mission completed/mission ended is triggered
    if( !bAlreadyCompleted && !bAlreadyFailed && 
        Repo.GuiConfig.SwatGameRole != GAMEROLE_MP_Client && 
        Repo.GuiConfig.SwatGameRole != GAMEROLE_MP_Host )
    {
        if( Repo.GuiConfig.CurrentMission.IsMissionCompleted() )
            MissionCompleted();
        else
        MissionFailed();
    }
    
    bAlreadyEnded=true;
    Broadcast( None, "", 'MissionEnded' );
    GameEvents.MissionEnded.Triggered();
}

//////////////////////////////////////////////////////////////////////////////////////
// Mission Termination
//////////////////////////////////////////////////////////////////////////////////////

function GameAbort()
{
    if( Repo.GuiConfig.SwatGameState != GAMESTATE_MidGame )
        return;

    if( bAlreadyEnded )
        return;

    if( Level.NetMode == NM_Standalone )
        Repo.OnMissionEnded();
    else
        GameMode.EndGame();

    //update scoring once more
    UpdateScoring();

    bAlreadyEnded=true;
}

final function OnCriticalMoment()
{
    log( "[dkaplan] in SwatGameinfo OnCriticalMoment()");
    Repo.OnCriticalMoment();
}
    
//interface IInterested_GameEvent_EvidenceSecured implementation
function OnEvidenceSecured(IEvidence Secured)
{
    if( bAlreadyCompleted || bAlreadyFailed )
        OnCriticalMoment();
}

// IInterested_GameEvent_ReportableReportedToTOC implementation
function OnReportableReportedToTOC(IAmReportableCharacter ReportableCharacter, Pawn Reporter)
{
    if( bAlreadyCompleted || bAlreadyFailed )
        OnCriticalMoment();
}

function InitGameReplicationInfo()
{
    local SwatRepo theRepo;
    local EMPMode currentGameMode;
    local SwatGameReplicationInfo SGRI;

    // Do this before calling Super.InitGameReplicationInfo().
    theRepo = SwatRepo(Level.GetRepo());
    currentGameMode = ServerSettings(Level.CurrentServerSettings).GameType;
    if ( currentGameMode == MPM_BarricadedSuspects )
        GameModeString = "0";
    else if ( currentGameMode == MPM_RapidDeployment )
        GameModeString = "1";
    else if ( currentGameMode == MPM_VIPEscort )
        GameModeString = "2";
    else
        GameModeString = "3";
    mplog( self$"...GameModeString="$GameModeString );

    Super.InitGameReplicationInfo();
    if ( Level.NetMode != NM_Standalone )
    {
        GameReplicationInfo.Teams[0] = Spawn(class'NetTeamA');
        GameReplicationInfo.Teams[1] = Spawn(class'NetTeamB');
    }

    // We store all the fun stuff in the SwatRepo, but parts of the engine
    // would like the values stored in the appropriate placed in the
    // engine. Copy those values to the right places here.
    SGRI = SwatGameReplicationInfo(GameReplicationInfo);
    GameReplicationInfo.ServerName = ServerSettings(Level.CurrentServerSettings).ServerName;

    if ( ServerSettings(Level.CurrentServerSettings).bShowTeammateNames )
        SGRI.ShowTeammateNames = 2;
    else
        SGRI.ShowTeammateNames = 1;

    if ( ServerSettings(Level.CurrentServerSettings).bShowEnemyNames )
        SGRI.ShowEnemyNames = 2;
    else
        SGRI.ShowEnemyNames = 1;

    // Level.Title is the name was should display in the ServerBrowser
    // listings. It should be set by the designers.
    mplog( "---SwatGameInfo::InitGameReplicationInfo(). Level.Title="$Level.Title );
    mplog( "...ShowTeammateNames="$SGRI.ShowTeammateNames );
    mplog( "...ShowEnemyNames="$SGRI.ShowEnemyNames );
}


function InitializeGameMode()
{
    local EMPMode GUIGameMode;

    bAlreadyEnded=false;
    
    log( "Initializing GameMode." );

    // The game mode should be destroyed if it already exists - this will clean up the game state
    //   This allows for quick restarts
    if( GameMode != None )
    {
        GameMode.OnMissionEnded();
        GameMode.Destroy();
        GameMode = None;
    }
    
    Assert( GameMode == None );

    if ( Level.NetMode == NM_Standalone )
    {
        GameMode = Spawn( class'GameModeStandalone', self );
    }
    else
    {
        Assert( ServerSettings(Level.CurrentServerSettings) != None );

        GUIGameMode = ServerSettings(Level.CurrentServerSettings).GameType;

        if ( GUIGameMode == MPM_VIPEscort )
            GameMode = Spawn( class'GameModeVIP', self );
        else if ( GUIGameMode == MPM_RapidDeployment )
            GameMode = Spawn( class'GameModeRD', self );
        else if ( GUIGameMode == MPM_COOP )
            GameMode = Spawn( class'GameModeCOOP', self );
        else
        {
            AssertWithDescription( GUIGameMode == MPM_BarricadedSuspects,
                                   "GameType was not set by GUI; defaulting to Barricaded Suspects" );
            GameMode = Spawn( class'GameModeBS', self );
        }
    }
    GameMode.Initialize();
}

function GameMode GetGameMode()
{
    return GameMode;
}

// This returns the _nonlocalized_ name of the game mode. We need it to be
// nonlocalized for sending it to the GameSpy master servers.
//
function string GetGameModeName()
{
    local EMPMode GUIGameMode;

    Assert( ServerSettings(Level.CurrentServerSettings) != None );

    GUIGameMode = ServerSettings(Level.CurrentServerSettings).GameType;

    if ( GUIGameMode == MPM_VIPEscort )
        return "VIP Escort";
    else if ( GUIGameMode == MPM_RapidDeployment )
        return "Rapid Deployment";
    else if ( GUIGameMode == MPM_COOP )
        return "CO-OP";
    else
    {
        AssertWithDescription( GUIGameMode == MPM_BarricadedSuspects,
                               "We need to get the name of the GameMode, but it hasn't been set yet; defaulting to Barricaded Suspects" );
        return "Barricaded Suspects";
    }
}

//////////////////////////////////////////////////////////
//overridden from GameInfo
function GetServerInfo( out ServerResponseLine ServerState )
{
	ServerState.ServerName		= ServerSettings(Level.CurrentServerSettings).ServerName;
	ServerState.MapName			= Level.Title;
	ServerState.GameType		= GetGameModeName();
	ServerState.CurrentPlayers	= NumberOfPlayersForServerBrowser();
	ServerState.MaxPlayers		= MaxPlayersForServerBrowser();
	ServerState.IP				= ""; // filled in at the other end.
	ServerState.Port			= GetServerPort();
	
	ServerState.ModName			= Level.ModName;
	ServerState.GameVersion		= Level.BuildVersion;

	ServerState.ServerInfo.Length = 0;
	ServerState.PlayerInfo.Length = 0;
}

function GetServerDetails( out ServerResponseLine ServerState )
{
	local int i;
	local Mutator M;
	local GameRules G;

	i = ServerState.ServerInfo.Length;

	// servermode
	ServerState.ServerInfo.Length = i+1;
	ServerState.ServerInfo[i].Key = "servermode";
	if( Level.NetMode==NM_ListenServer )
		ServerState.ServerInfo[i++].Value = "non-dedicated";
    else
		ServerState.ServerInfo[i++].Value = "dedicated";

	// adminemail
	ServerState.ServerInfo.Length = i+1;
	ServerState.ServerInfo[i].Key = "ServerVersion";
	ServerState.ServerInfo[i++].Value = level.EngineVersion;

	// has password
	if( AccessControl.RequiresPassword() )
	{
		ServerState.ServerInfo.Length = i+1;
		ServerState.ServerInfo[i].Key = "password";
		ServerState.ServerInfo[i++].Value = "true";
	}

	// Ask the mutators if they have anything to add.
	for (M = BaseMutator.NextMutator; M != None; M = M.NextMutator)
		M.GetServerDetails(ServerState);

	// Ask the gamerules if they have anything to add.
	for ( G=GameRulesModifiers; G!=None; G=G.NextGameRules )
		G.GetServerDetails(ServerState);
}
			
function GetServerPlayers( out ServerResponseLine ServerState )
{
    local Mutator M;
	local Controller C;
	local SwatPlayerReplicationInfo PRI;
	local int i;

#if 1 //dkaplan: we currently don't use any of this player information in the server browser
    return;
#endif

	i = ServerState.PlayerInfo.Length;

	for( C=Level.ControllerList;C!=None;C=C.NextController )
    {
		PRI = SwatPlayerReplicationInfo(C.PlayerReplicationInfo);
		if( (PRI != None) && !PRI.bBot && MessagingSpectator(C) == None )
        {
			ServerState.PlayerInfo.Length = i+1;
			ServerState.PlayerInfo[i].PlayerNum  = PRI.SwatPlayerID;		
			ServerState.PlayerInfo[i].PlayerName = PRI.PlayerName;
			ServerState.PlayerInfo[i].Score		 = PRI.netScoreInfo.GetScore();			
			ServerState.PlayerInfo[i].Ping		 = PRI.Ping;
			i++;
		}
	}

	// Ask the mutators if they have anything to add.
	for (M = BaseMutator.NextMutator; M != None; M = M.NextMutator)
		M.GetServerPlayers(ServerState);
}
//////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////

function SpawningManager GetSpawningManager()
{
    return SpawningManager;
}

function CustomScenario GetCustomScenario()
{
    if( Repo.GuiConfig.CurrentMission == None )
        return None;

    return Repo.GuiConfig.CurrentMission.CustomScenario;
}

function bool UsingCustomScenario()
{
    return GetCustomScenario() != None;
}

function bool CampaignObjectivesAreInEffect()
{
    if (GetCustomScenario() == None)
        return true;    //its a campaign mission

    return GetCustomScenario().UseCampaignObjectives;
}

///////////////////////////////////////////////////////////////////////////


function PostGameStarted()
{
	bPostGameStarted = true;

    GameEvents.PostGameStarted.Triggered();
}

function OnGameStarted()
{
    local SwatRepo RepoObj;
    log("[dkaplan] >>> SwatGameInfo::OnGameStarted()");
    if (bDebugFrames) Enable('Tick');

    GameEvents.GameStarted.Triggered();

    //if we are in a SP mission, start the Mission now
    RepoObj = Repo;
    Assert( RepoObj != None );
    if( RepoObj.GuiConfig.SwatGameRole == GAMEROLE_None ||
        RepoObj.GuiConfig.SwatGameRole == GAMEROLE_SP_Campaign ||
        RepoObj.GuiConfig.SwatGameRole == GAMEROLE_SP_Custom ||
        RepoObj.GuiConfig.SwatGameRole == GAMEROLE_SP_Other )
        RepoObj.OnMissionStarted();
        
//    TestHook(); //perform any tests
}

//this is the actual start of the mission
function OnMissionStarted()
{
    Level.TickSpecialEnabled = true;

    GameEvents.MissionStarted.Triggered();

	// send a message that the level has started
	dispatchMessage(new class'Gameplay.MessageLevelStart'(GetCustomScenario() != None));
}

function bool GameInfoShouldTick() { return bDebugFrames; }

function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);

    if (bDebugFrames)
    {
    	//record the last frame time
    	CurrentDebugFrameData.DeltaTime = DeltaTime;
        //prepare a new DebugFrameData for the current frame
    	AddDebugFrameData();
    }
}

function NetRoundTimeRemaining( float TimeRemaining )
{
    local int IntTimeRemaining;

    Assert( Level.NetMode != NM_Standalone );

    IntTimeRemaining = TimeRemaining;
    if ( IntTimeRemaining != PreviousNetRoundTimeRemaining )
    {
        PreviousNetRoundTimeRemaining = IntTimeRemaining;
        GameMode.NetRoundTimeRemaining( IntTimeRemaining );
    }
}


function NetRoundTimerExpired()
{
    Assert( Level.NetMode != NM_Standalone );
    GameMode.NetRoundTimerExpired();
}


#if IG_EFFECTS
// Dump the state of the SoundEffectsSubsystem to the log
//
// SystemName should be one of "VISUAL" or "SOUND"
exec function DumpEffects(Name SystemName)
{
    local EffectsSystem FX;    
    local EffectsSubsystem SubSys;
    local Name ClassName;
        
    FX = EffectsSystem(Level.EffectsSystem);
    assert(FX != None);

    if (SystemName == 'SOUND')
    {
        ClassName = 'SoundEffectsSubsystem';
    }
    else if (SystemName == 'VISUAL')
    {
        ClassName = 'VisualEffectsSubsystem';
    }

    Subsys = FX.GetSubsystem(ClassName);
    if (Subsys == None)
    {
        Warn("WARNING: Cannot dump effects; subsystem not found: "$ClassName);
        return;
    }
    Subsys.LogState();
}
#endif

exec function DebugFrames(Name Option, String Param)
{
    //calculate the frame-time mean and standard deviation
    local float Mean;
    local float Variance;
    local float StandardDeviation;
    local int i;
    local bool QualifiedFrame;  //is the current frame qualified to be logged according to the user's request

    //mean
    for (i=0; i<DebugFrameData.length; ++i)
    	Mean += DebugFrameData[i].DeltaTime;
    Mean = Mean / DebugFrameData.length;

    //add squared deviations
    for (i=0; i<DebugFrameData.length; ++i)
        Variance += Square(DebugFrameData[i].DeltaTime - Mean);
    Variance = Variance / DebugFrameData.length;

    //standard deviation
    StandardDeviation = Sqrt(Variance);

    log("DebugFrames: NumFrames="$DebugFrameData.length$", MeanTime="$Mean$", StandardDeviation="$StandardDeviation);
    switch (Option)
    {
        case 'hitches':
            log("                Hitches - Frames with time > a standard deviation from the mean:");
            break;

        case 'keyword':
            log("                Keyword - Frames with the string '"$param$"' found in GuardString:");
            break;

        case 'all':
            log("                All - all frame data:");
            break;

        default:
            log("DebugFrames Usage: debugframes [name Option] [string Param]");
            log("             Options: 'hitches' (string Param ignored), 'keyword' (specified in string Param), 'all' (string param ignored)");
            return;
    }

    for (i=0; i<DebugFrameData.length; ++i)
    {
        switch (Option)
        {
            case 'hitches':
                QualifiedFrame = (DebugFrameData[i].DeltaTime > (Mean + StandardDeviation));
                break;

            case 'keyword':
                QualifiedFrame = (Instr(DebugFrameData[i].GetGuardString(), param) != -1);
                break;

            case 'all':
                QualifiedFrame = true;
                break;

            default:
                assert(false);  //unexpected option
        }

        if (QualifiedFrame)
            log("    -> Frame #"$i$": EndTime="$DebugFrameData[i].EndTimeSeconds$", DeltaTime="$DebugFrameData[i].DeltaTime$" ("$1.f/DebugFrameData[i].DeltaTime$"fps, "$abs(DebugFrameData[i].DeltaTime - Mean) / StandardDeviation$" s.d.(s) from mean), GuardString="$DebugFrameData[i].GetGuardString());
    }
}

//add a new entry to the array of DebugFrameData to represent the current frame
function AddDebugFrameData()
{
    if (CurrentDebugFrameData != None)
        CurrentDebugFrameData.EndTimeSeconds = Level.TimeSeconds;

    CurrentDebugFrameData = new class'DebugFrameData';
    DebugFrameData[DebugFrameData.length] = CurrentDebugFrameData;
}

function GuardSlow(String GuardString)
{
    CurrentDebugFrameData.AddGuardString(GuardString);
}

//override GameInfo::AddDefaultInventory() to give the player his/her LoadOut
function AddDefaultInventory(Pawn inPlayerPawn)
{
    local OfficerLoadOut LoadOut;
    local SwatPlayer PlayerPawn;
    local SwatRepoPlayerItem RepoPlayerItem;
    local NetPlayer theNetPlayer;
    local int i;
    local DynamicLoadOutSpec LoadOutSpec;

    log( "In SwatGameInfo::AddDefaultInventory(). Pawn="$inPlayerPawn);

    PlayerPawn = SwatPlayer(inPlayerPawn);
    assert(PlayerPawn != None);

    if ( Level.NetMode == NM_Standalone )
    {
        if( Level.IsTraining )
        {
            LoadOut = Spawn(class'OfficerLoadOut', PlayerPawn, 'TrainingLoadOut');
            LoadOutSpec = None;
        }
        else
        {
            LoadOut = Spawn(class'OfficerLoadOut', PlayerPawn, 'DefaultPlayerLoadOut');
            LoadOutSpec = Spawn(class'DynamicLoadOutSpec', PlayerPawn, 'CurrentPlayerLoadOut');
        }
        assert(LoadOut != None);
    }
    else
    {
        assert( Level.NetMode == NM_DedicatedServer || Level.NetMode == NM_ListenServer );

        theNetPlayer = NetPlayer( inPlayerPawn );
        if ( theNetPlayer.IsTheVIP() )
        {
            mplog( "...this player is the VIP." );
            
            // The VIP must always be on the SWAT team.
            Assert( NetPlayer(PlayerPawn).GetTeamNumber() == 0 );

            LoadOut = Spawn( class'OfficerLoadOut', PlayerPawn, 'VIPLoadOut' );
            LoadOutSpec = Spawn(class'DynamicLoadOutSpec', None, 'DefaultVIPLoadOut');
            Assert( LoadOutSpec != None );

            // Copy the items from the loadout to the netplayer.
            for( i = 0; i < Pocket.EnumCount; ++i )
            {
                theNetPlayer.SetPocketItemClass( Pocket(i), LoadOutSpec.LoadOutSpec[ Pocket(i) ] );
            }

            theNetPlayer.SwitchToMesh( theNetPlayer.VIPMesh );
        }
        else
        {
            mplog( "...this player is NOT the VIP." );

            if ( NetPlayer(PlayerPawn).GetTeamNumber() == 0 )
                LoadOut = Spawn(class'OfficerLoadOut', PlayerPawn, 'EmptyMultiplayerOfficerLoadOut' );
            else
                LoadOut = Spawn(class'OfficerLoadOut', PlayerPawn, 'EmptyMultiplayerSuspectLoadOut' );

            log( "...In AddDefaultInventory(): loadout's owner="$LoadOut.Owner );
            assert(LoadOut != None);

            // First, set all the pocket items in the NetPlayer loadout spec, so
            // that remote clients (ones who don't own the pawn) can locally spawn
            // the loadout items.
            RepoPlayerItem = SwatGamePlayerController(PlayerPawn.Controller).SwatRepoPlayerItem;

            //RepoPlayerItem.PrintLoadOutSpecToMPLog();
        
            // Copy the items from the loadout to the netplayer.
            for( i = 0; i < Pocket.EnumCount; ++i )
            {
                theNetPlayer.SetPocketItemClass( Pocket(i), RepoPlayerItem.RepoLoadOutSpec[ Pocket(i) ] );
            }
        
            LoadOutSpec = theNetPlayer.GetLoadoutSpec();
        }
    }
    
    LoadOut.Initialize( LoadOutSpec );

    PlayerPawn.ReceiveLoadOut(LoadOut);

    // We have to do this after ReceiveLoadOut() because that's what sets the
    // Replicated Skins.
    if ( Level.NetMode != NM_Standalone )
        theNetPlayer.InitializeReplicatedCounts();

    //TMC TODO do this stuff in the PlayerPawn (legacy support)
	SetPlayerDefaults(PlayerPawn);
}

exec function MissionStatus()
{
    local int i;
    local Objective CurrentObjective;

    log("[MISSION STATUS]");

    for (i=0; i<Repo.MissionObjectives.Objectives.length; ++i)
    {
        CurrentObjective = Repo.MissionObjectives.Objectives[i];

        log("... Objective '"$CurrentObjective.name
        $"': "$CurrentObjective.Description
        $".  Status: "$CurrentObjective.GetStatusString());
    }
}

//returns the current leadership score for the mission
exec function int LeadershipStatus()
{
    local int i;
    local int Score;
    local Procedure CurrentProcedure;

    log("[LEADERSHIP STATUS]");

    for (i=0; i<Repo.Procedures.Procedures.length; ++i)
    {
        CurrentProcedure = Repo.Procedures.Procedures[i];

        log("... Procedure '"$CurrentProcedure.name
        $"': "$CurrentProcedure.Description
        $".  Status: "$CurrentProcedure.Status());

        Score += CurrentProcedure.GetCurrentValue();
    }

    Score = Max( 0, Score );

    log("-> Mission Score: "$Score);

    return Score;
}

// returns the 'best' player start for this player to start from.
//
// FIXME: move this to a subclass based on game type, a la UT2K3's
// game-specific GameInfo subclasses
function NavigationPoint FindPlayerStart(Controller Player, optional byte InTeam, optional string incomingName)
{
    local PlayerStart PointToUse;
	local EEntryType DesiredEntryType;
	local int IndexOfFirstCheckedPoint;

	Log("SwatGameInfo.FindPlayerStart() ");

	// Take into account whether the team should use the primary or
	// secondary entry point.

    // In a coop game, its possible for the server's desired entry point to be
    // secondary, yet be playing a map that only has a primary spawn point.
    // Since this FindPlayerStart function really only provides a temporary
    // spot, and the real multiplayer spawning happens in
    // GameMode::FindNetPlayerStart, coop servers should just look for primary
    // starts.
    if ( Level.IsCOOPServer )
	    DesiredEntryType = ET_Primary;	
    else
	    DesiredEntryType = Repo.GetDesiredEntryPoint();	
	
	// Remember the first point we checked, to avoid infinite loops
	IndexOfFirstCheckedPoint = NextPlayerStartPoint;

	// Keep looking until we find a SwatPlayerStart that is not touching any
	// other players and (if this is a single-player game) has the correct
	// entry type.
    PointToUse = PlayerStartArray[ IndexOfFirstCheckedPoint ];
    while ( PointToUse.Touching.Length > 0 || 
			!PointToUse.IsA('SwatPlayerStart') ||
			( ( Level.NetMode == NM_Standalone || Level.IsCOOPServer )
			    && SwatPlayerStart(PointToUse).EntryType != DesiredEntryType ) )
    {
        if (PointToUse.Touching.Length > 0)
			log( " FindPlayerStart(): Skipping "$PointToUse$" because it is touching "$PointToUse.Touching.Length$" actors" );
        else if (!PointToUse.IsA('SwatPlayerStart'))
			log( " FindPlayerStart(): Skipping "$PointToUse$" because it is not of class SwatPlayerStart");
        else if( ( Level.NetMode == NM_Standalone || Level.IsCOOPServer )
                 && SwatPlayerStart(PointToUse).EntryType != DesiredEntryType )
			log( " FindPlayerStart(): Skipping "$PointToUse$" because we're in a single-player or coop game and its entry type ("$GetEnum(EEntryType,SwatPlayerStart(PointToUse).EntryType)$") does not match the desired entry type ("$GetEnum(EEntryType,DesiredEntryType)$")");

		// try the next point
		NextPlayerStartPoint = NextPlayerStartPoint + 1;
        if ( NextPlayerStartPoint == PlayerStartArray.Length )
        {
            NextPlayerStartPoint = 0;
        }
		
		// See if we've exhausted all the possible start points
		if (NextPlayerStartPoint == IndexOfFirstCheckedPoint)
		{
			PointToUse = None;
			break;
		}
		else
		{
			PointToUse = PlayerStartArray[ NextPlayerStartPoint ];
		}
    }
	
	// Increment the start point so the next player to spawn won't choose the
	// same point.
    NextPlayerStartPoint = NextPlayerStartPoint + 1;
    if ( NextPlayerStartPoint == PlayerStartArray.Length )
    {
        NextPlayerStartPoint = 0;
    }
	
	AssertWithDescription(PointToUse != None, "Failed to find any usable SwatPlayerStart points!");

	log(" FindPlayerStart(): returning  "$PointToUse);

    return PointToUse;
}

// Override default spawning so that you don't spawn on the point another
// player has spawned on. 
//
// FIXME: move this to a subclass based on game type, a la UT2K3's
// game-specific GameInfo subclasses
function float RatePlayerStart(NavigationPoint N, byte Team, Controller Player)
{
    local PlayerStart P;
    local float Score;
	//local float NextDist;
    //local Controller OtherPlayer;

    P = PlayerStart(N);

	// only log this if we're not in single player
	if (Level.NetMode != NM_Standalone)
	{
		Log("SwatGameInfo.RatePlayerStart() rating NavigationPoint "$N);
	}
	
    if ( (P == None) || !P.bEnabled || P.PhysicsVolume.bWaterVolume || ((Level.NetMode == NM_Standalone || Level.IsCOOPServer) && ! P.bSinglePlayerStart) )
	{
		//Log("   Final rating is -1000 because start spot is none, not enabled, or water");
        return -1000;
	}
	
	Log("   Base Rating is 1000");
	Score = 1000;
	
	if (P.TimeOfLastSpawn >= 0) // TimeOfLastSpawn is -1 if nothing has spawned there yet
	{
		Score -= Max(Level.TimeSeconds - P.TimeOfLastSpawn, 0);
  		Log("   Decreasing base to "$Score$" because someone spawned here "$
			(Level.TimeSeconds - P.TimeOfLastSpawn)$" seconds ago ("$Level.TimeSeconds$"-"$P.TimeOfLastSpawn$")");
	}

	Score = FMax(Score, 1);
	Log("   Final rating is "$Score$" after clamping to minimum of 1");
	return Score;
}


///////////////////////////////////////////////////////////////////////////////
//
//
//
function SetStartClustersForRoundStart()
{
    Assert( Role == ROLE_Authority );
    GameMode.SetStartClustersForRoundStart();
}


function AssignPlayerRoles()
{
    Assert( Role == ROLE_Authority );
    GameMode.AssignPlayerRoles();
}


// Can only be called on the server. Respawns all dead players
exec function RespawnAll()
{
    Assert( Role == ROLE_Authority );
    GameMode.RespawnAll();
}


function bool AtCapacity(bool bSpectator)
{
    local int MaxPlayerSetting;
    local int CurrentPlayers;

    if ( Level.NetMode == NM_Standalone )
		return false;

    // Find max players right now for this server.
	MaxPlayerSetting = ServerSettings(Level.CurrentServerSettings).MaxPlayers;

    // Find number of players connected to the server by counting repo
    // items. This should give us the right value whether we're in the round
    // or doing the switch level thing.
    CurrentPlayers = SwatRepo(Level.GetRepo()).NumberOfRepoPlayerItems();

    return ( (MaxPlayerSetting>0) && (CurrentPlayers>=MaxPlayerSetting) );
}

///////////////////////////////////////////////////////////////////////////////
//
// Login-related overridden functions
//

//
// Log a player in.
// Fails login if you set the Error string.
// PreLogin is called before Login, but significant game time may pass before
// Login is called, especially if content is downloaded.
//
event PlayerController Login(string Portal, string Options, out string Error)
{
    local NavigationPoint    StartSpot;
    local PlayerController   NewPlayer;
    local Pawn               TestPawn;
    local string             InName, InAdminName, InPassword, InChecksum, InClass, InCharacter; 
    local byte               InTeam;
    local class<Security>    MySecurityClass;
    local int                InSwatPlayerID, NewSwatPlayerID;
    local SwatRepoPlayerItem theSwatRepoPlayerItem;

    BaseMutator.ModifyLogin(Portal, Options);

    // Get URL options.
    InName     = Left(ParseOption ( Options, "Name"), 20);
    InTeam     = GetIntOption( Options, "Team", 255 ); // default to "no team"
    InAdminName= ParseOption ( Options, "AdminName");
    InPassword = ParseOption ( Options, "Password" );
    InChecksum = ParseOption ( Options, "Checksum" );
    InSwatPlayerID = GetIntOption( Options, "SwatPlayerID", 0 ); // zero means we are
                                                                 // a new connector.

    // Make sure there is capacity except for returning players (denoted by a non-0 player id)
    if ( InSwatPlayerID == 0 && AtCapacity( false ) )
    {
        Error=GameMessageClass.Default.MaxedOutMessage;
        return None;
    }

    log( "Login:" @ InName );
    log( "  SwatPlayerID: "$InSwatPlayerID );

    if ( Level.NetMode != NM_Standalone )
    {
        // Fix up the playerID and find the repo item. Create a new one if ID is
        // zero.
        if ( InSwatPlayerID == 0 )
        {
            // The player didn't have a repo item.
            NewSwatPlayerID = Repo.GetNewSwatPlayerID();
            theSwatRepoPlayerItem = Repo.GetRepoPlayerItem( NewSwatPlayerID );
            InTeam = GetAutoJoinTeamID();
            theSwatRepoPlayerItem.SetTeamID( InTeam );
        }
        else
        {
            // The player already had a repo item.
            NewSwatPlayerID = InSwatPlayerID;
            theSwatRepoPlayerItem = Repo.GetRepoPlayerItem( NewSwatPlayerID );
            InTeam = theSwatRepoPlayerItem.GetPreferredTeamID();
        }
        theSwatRepoPlayerItem.bConnected = true;
    }

    // Find a start spot.

    // ckline: Note, from what I can tell, this finds a "potential" spot to
    // spawn; it's only checking the controller, not the pawn. Later, in
    // RestartPlayer, starting points will be checked again.
    StartSpot = FindPlayerStart( None, InTeam, Portal );

    if( StartSpot == None )
    {
        // Login will fail because no place could be found to spawn the player
        Error = GameMessageClass.Default.FailedPlaceMessage;
        return None;
    }

    if ( PlayerControllerClass == None )
        PlayerControllerClass = class<PlayerController>(DynamicLoadObject(PlayerControllerClassName, class'Class'));

    NewPlayer = Spawn(PlayerControllerClass,,,StartSpot.Location,StartSpot.Rotation);

    // Handle spawn failure.
    if( NewPlayer == None )
    {
        log("Couldn't spawn player controller of class "$PlayerControllerClass);
        Error = GameMessageClass.Default.FailedSpawnMessage;
        return None;
    }
    log("Spawned player "$NewPlayer$" at "$StartSpot); // ckline

    NewPlayer.StartSpot = StartSpot;

    SwatGamePlayerController(NewPlayer).SwatPlayerID = NewSwatPlayerID;
    if ( Level.NetMode != NM_Standalone )
    SwatGamePlayerController(NewPlayer).SwatRepoPlayerItem = theSwatRepoPlayerItem;

    //auto set the local PC's admin PW to be correct
    if( Level.GetLocalPlayerController() == NewPlayer )
        theSwatRepoPlayerItem.LastAdminPassword = SwatRepo(Level.GetRepo()).GuiConfig.AdminPassword;

    //attempt to log the new player in as an admin (based on their last entered password)        
    Admin.AdminLogin( NewPlayer, theSwatRepoPlayerItem.LastAdminPassword );

    // Init player's replication info
    NewPlayer.GameReplicationInfo = GameReplicationInfo;

    // Apply security to this controller
    MySecurityClass=class<Security>(DynamicLoadObject(SecurityClass,class'class'));
    if (MySecurityClass!=None)
    {
        NewPlayer.PlayerSecurity = spawn(MySecurityClass,NewPlayer);
        if (NewPlayer.PlayerSecurity==None)
            log("Could not spawn security for player "$NewPlayer,'Security');
    }
    else
        log("Unknown security class ["$SecurityClass$"] -- System is no secure.",'Security');

    // Init player's name
    if( InName=="" )
        InName=DefaultPlayerName;
    if( Level.NetMode!=NM_Standalone || NewPlayer.PlayerReplicationInfo.PlayerName==DefaultPlayerName )
        SwatGamePlayerController(NewPlayer).SetName( InName );

    newPlayer.StartSpot = StartSpot;

    // Set the player's ID.
    NewPlayer.PlayerReplicationInfo.PlayerID = CurrentID++;
    SwatPlayerReplicationInfo(NewPlayer.PlayerReplicationInfo).SwatPlayerID = NewSwatPlayerID;
    SwatPlayerReplicationInfo(NewPlayer.PlayerReplicationInfo).COOPPlayerStatus = STATUS_NotReady;

    InClass = ParseOption( Options, "Class" );

    if (InClass == "")
        InClass = DefaultPlayerClassName;
    InCharacter = ParseOption(Options, "Character");
    NewPlayer.SetPawnClass(InClass, InCharacter);

    NumPlayers++;
    bWelcomePending = true;

    SetPlayerTeam( SwatGamePlayerController(NewPlayer), InTeam );

    // If a multiplayer game, set playercontroller to limbo state
    if ( Level.NetMode != NM_Standalone )
    {
        if ( bDelayedStart && !SwatGamePlayerController(NewPlayer).IsAReconnectingClient() )
        {
            NewPlayer.GotoState('NetPlayerLimbo');
            return NewPlayer;	
        }
    }

    // Try to match up to existing unoccupied player in level,
    // for savegames and coop level switching.
    ForEach DynamicActors(class'Pawn', TestPawn )
    {
        if ( (TestPawn!=None) && (PlayerController(TestPawn.Controller)!=None) && (PlayerController(TestPawn.Controller).Player==None) && (TestPawn.Health > 0)
            &&  (TestPawn.OwnerName~=InName) )
        {
            NewPlayer.Destroy();
            TestPawn.SetRotation(TestPawn.Controller.Rotation);
            TestPawn.bInitializeAnimation = false; // FIXME - temporary workaround for lack of meshinstance serialization
            TestPawn.PlayWaiting();
            return PlayerController(TestPawn.Controller);
        }
    }

    TestWaitingForPlayersToReconnect();

    return newPlayer;
}	

///////////////////////////////////////
//
// Called after a successful login. This is the first place
// it is safe to call replicated functions on the PlayerPawn.
//
event PostLogin( PlayerController NewPlayer )
{
    local class<HUD> HudClass;
    local class<Scoreboard> ScoreboardClass;
    local String SongName;

    // Log player's login.
    if (GameStats!=None)
    {
        GameStats.ConnectEvent(NewPlayer.PlayerReplicationInfo);
        GameStats.GameEvent("NameChange",NewPlayer.PlayerReplicationInfo.playername,NewPlayer.PlayerReplicationInfo);		
    }

    // If single player, start player in level immediately
    // MCJ: Also start player immediately if we've just reconnected to the
    // server because the round is starting.
    
	if ( !bDelayedStart ) //|| SwatGamePlayerController(NewPlayer).CreatePawnOponLogin() )
    {
        // start match, or let player enter, immediately
        bRestartLevel = false;	// let player spawn once in levels that must be restarted after every death
        bKeepSamePlayerStart = true;
        if ( bWaitingToStartMatch )
            StartMatch();
        else
            RestartPlayer(newPlayer);
        bKeepSamePlayerStart = false;
        bRestartLevel = Default.bRestartLevel;
    }

    // Start player's music.
    SongName = Level.Song;
    if( SongName != "" && SongName != "None" )
        NewPlayer.ClientSetMusic( SongName, MTRAN_Fade );

    // tell client what hud and scoreboard to use
    if( HUDType != "" )
        HudClass = class<HUD>(DynamicLoadObject(HUDType, class'Class'));

    if( ScoreBoardType != "" )
        ScoreboardClass = class<Scoreboard>(DynamicLoadObject(ScoreBoardType, class'Class'));
    NewPlayer.ClientSetHUD( HudClass, ScoreboardClass );

    if ( NewPlayer.Pawn != None )
        NewPlayer.Pawn.ClientSetRotation(NewPlayer.Pawn.Rotation);

    PlayerLoggedIn(NewPlayer);
}


///////////////////////////////////////////////////////////////////////////////
//
//
function PlayerLoggedIn(PlayerController NewPlayer)
{
    local SwatGamePlayerController PC;

    //dkaplan: when finished logging in, 
    //
    // if this is not a remote client (is the Local PlayerController) or is the first time
    //   goto pregame state
    // else 
    //   the client's gamestate should be set to the same as the server's 
    //
    //NOTE: this looks like it can be optimized better, but doing so may break
    //  the natural progression of gamestate (Pregame->Midgame->Postgame) 

    log( "[dkaplan] >>>  PlayerLoggedIn(), NewPlayer = "$NewPlayer);
    log( "[dkaplan]    ...  Level.GetLocalPlayerController() = "$Level.GetLocalPlayerController());
    log( "[dkaplan]    ...  Repo.GuiConfig.SwatGameState = "$Repo.GuiConfig.SwatGameState);
    
    PC = SwatGamePlayerController(NewPlayer);
    if (PC != None )
    {
        if ( Level.NetMode != NM_Standalone )
            log( "[dkaplan]    ...  SwatGamePlayerController(NewPlayer).IsAReconnectingClient() = "$PC.IsAReconnectingClient() );
            
        if( Level.IsCOOPServer )
            PrecacheOnClient( PC );
            
        if( NewPlayer == Level.GetLocalPlayerController()
            || Repo.GuiConfig.SwatGameState == GAMESTATE_PreGame
            || (Level.NetMode != NM_Standalone && !PC.IsAReconnectingClient()) )
        {
            PC.ClientOnLoggedIn();
            
            //notify of newly joined player
            if ( Level.NetMode != NM_Standalone )
            {
            if( !PC.IsAReconnectingClient())
                Broadcast( NewPlayer, NewPlayer.PlayerReplicationInfo.PlayerName, 'PlayerConnect');
            }
            
            //notify of pre-game waiting state
            //if( Repo.GuiConfig.SwatGameState == GAMESTATE_PreGame )
                //NewPlayer.ClientMessage( "Waiting for round to start!", 'SwatGameEvent' );
        }
        else if ( Repo.GuiConfig.SwatGameState == GAMESTATE_MidGame )
        {
            PC.ClientOnLoggedIn();
            PlayerLateStart( PC );
        }
        else if ( Repo.GuiConfig.SwatGameState == GAMESTATE_PostGame )
        {
            PC.ClientOnLoggedIn();
            PC.ClientRoundStarted();
            PC.ClientGameEnded();
        }
    }

	// This call may need to be moved at some point so that the entry point for the spawned officers
	// is the same as the player.  For now I will just leave it here.  [crombie]
	if ( Level.NetMode == NM_Standalone )
    {
        SpawnOfficers();
    }
	log( "[dkaplan] <<<  PlayerLoggedIn(), NewPlayer = "$NewPlayer);
}


function Logout( Controller Exiting )
{
    local SwatGamePlayerController SGPC;

    mplog( "---SwatGameInfo::Logout(). ControllerLeaving="$Exiting );

    SGPC = SwatGamePlayerController( Exiting );
    if ( SGPC != None && SGPC.SwatPlayer != None )
    {
        //broadcast this player's disconnection to all players
        Broadcast( SGPC, SGPC.PlayerReplicationInfo.PlayerName, 'PlayerDisconnect');
    
        //log the player out: remove their RepoItem
        Repo.Logout( SGPC );
        
        mplog( "......triggering game event." );
        GameEvents.PlayerDied.Triggered( SGPC, SGPC );
    }

    TestWaitingForPlayersToReconnect();

    // call this *after* the code above.
    Super.Logout( Exiting );
}


private function bool ShouldSpawnOfficerRedOne()  { return ((Repo.GuiConfig.CurrentMission.CustomScenario == None) || Repo.GuiConfig.CurrentMission.CustomScenario.HasOfficerRedOne);  }
private function bool ShouldSpawnOfficerRedTwo()  { return ((Repo.GuiConfig.CurrentMission.CustomScenario == None) || Repo.GuiConfig.CurrentMission.CustomScenario.HasOfficerRedTwo);  }
private function bool ShouldSpawnOfficerBlueOne() { return ((Repo.GuiConfig.CurrentMission.CustomScenario == None) || Repo.GuiConfig.CurrentMission.CustomScenario.HasOfficerBlueOne); }
private function bool ShouldSpawnOfficerBlueTwo() { return ((Repo.GuiConfig.CurrentMission.CustomScenario == None) || Repo.GuiConfig.CurrentMission.CustomScenario.HasOfficerBlueTwo); }

private function bool ShouldSpawnOfficerAtStart(SwatOfficerStart OfficerStart, EEntryType DesiredEntryType)
{
	assert(OfficerStart != None);

	if (OfficerStart.EntryType == DesiredEntryType)
	{
		switch (OfficerStart.OfficerStartType)
		{
			case RedOneStart:
				return ShouldSpawnOfficerRedOne();
			case RedTwoStart:
				return ShouldSpawnOfficerRedTwo();
			case BlueOneStart:
				return ShouldSpawnOfficerBlueOne();
			case BlueTwoStart:
				return ShouldSpawnOfficerBlueTwo();
		}
	}

	return false;
}

// Goes through all of the SwatOfficerStart points and tells it to spawn the officer
private function SpawnOfficers()
{
	local int i;
	local NavigationPoint Iter;
	local EEntryType DesiredEntryType;
	local SwatOfficerStart OfficerStart;
	local array<SwatOfficerStart> OfficerSpawnPoints;

	// find out if we should use the primary or secondary entry points
	DesiredEntryType = Repo.GetDesiredEntryPoint();

	NumSpawnedOfficers = 0;

	// first go through and figure out where we will spawn the officers, as well as how many will spawn
	// at this point we do not spawn because we need to know how many will spawn first
	Log("SPAWNING OFFICERS:");
	for (Iter = Level.NavigationPointList; Iter != None; Iter = Iter.nextNavigationPoint)
	{
		if (Iter.IsA('SwatStartPointBase'))
		{
			if(Iter.IsA('SwatOfficerStart'))
            {
                OfficerStart = SwatOfficerStart(Iter);
				if (ShouldSpawnOfficerAtStart(OfficerStart, DesiredEntryType))
				{
		            log("  Will *Spawn* officer at "$OfficerStart$" with entry type "$GetEnum(EEntryType,DesiredEntryType));
			        OfficerSpawnPoints[OfficerStart.OfficerStartType] = OfficerStart;
			        ++NumSpawnedOfficers;
		        }
		        else
		        {
			        log("  Not spawning officer at "$OfficerStart$" because its entry type ("$GetEnum(EEntryType,OfficerStart.EntryType)$") doesn't match desired entry "$GetEnum(EEntryType,DesiredEntryType)$")");
		        }
            }
            else
            {
                log("  Not spawning officer at "$Iter$" because it is not a SwatOfficerStart");
            }
        }
	}

	// now go through and spawn the officers
	for(i=0; i<OfficerSpawnPoints.Length; ++i)
	{
		if (OfficerSpawnPoints[i] != None)
			OfficerSpawnPoints[i].SpawnOfficer();
	}

	Log("  TOTAL OFFICERS SPAWNED: "$NumSpawnedOfficers);
}

function int GetNumSpawnedOfficers()
{
	return NumSpawnedOfficers;
}


//
// Restart a player.
//
function RestartPlayer( Controller aPlayer )	
{
	local NavigationPoint startSpot;
    local SwatMPStartPoint MPStartSpot;
	local int TeamNum;

    mplog( "---SwatGameInfo::RestartPlayer(). PlayerController="$aPlayer );

	if( bRestartLevel && Level.NetMode!=NM_DedicatedServer && Level.NetMode!=NM_ListenServer )
    {
        mplog( "...1" );
		return;
    }

    if ( Level.NetMode == NM_Standalone )
    {
        if ( (aPlayer.PlayerReplicationInfo == None) || (aPlayer.PlayerReplicationInfo.Team == None) )
            TeamNum = 255;
        else
            TeamNum = aPlayer.PlayerReplicationInfo.Team.TeamIndex;

        // Spawn the player's pawn at an appropriate starting spot
        startSpot = SpawnPlayerPawn(aPlayer, TeamNum); // ckline: refactored code out of this function into SpawnPlayerPawn
        if( startSpot == None )
        {
            log(" Player pawn start not found!!!");
            return;
        }	
	
        log("Setting TimeOfLastSpawn to "$Level.TimeSeconds$" for "$StartSpot);
        StartSpot.TimeOfLastSpawn = Level.TimeSeconds; // ckline added

        aPlayer.Pawn.Anchor = startSpot;
        aPlayer.Pawn.LastStartSpot = PlayerStart(startSpot);
        aPlayer.Pawn.LastStartTime = Level.TimeSeconds;
        aPlayer.PreviousPawnClass = aPlayer.Pawn.Class;

        aPlayer.Possess(aPlayer.Pawn);
        aPlayer.PawnClass = aPlayer.Pawn.Class;

        aPlayer.Pawn.PlayTeleportEffect(true, true);
        aPlayer.ClientSetRotation(aPlayer.Pawn.Rotation);
        AddDefaultInventory(aPlayer.Pawn);
        TriggerEvent( StartSpot.Event, StartSpot, aPlayer.Pawn);
    }
    else
    {
        // We're in a network game.

        // Spawn the player's pawn at an appropriate starting spot
        MPStartSpot = SpawnNetPlayerPawn( aPlayer );
        if( MPstartSpot == None )
        {
            log("...Net player pawn start not found!!! returning from RestartPlayer()...");
            return;
        }	

        NetPlayer(aPlayer.Pawn).SwatPlayerID = SwatGamePlayerController(aPlayer).SwatPlayerID;

        if ( SwatGamePlayerController(aPlayer).ThisPlayerIsTheVIP )
        {
            mplog( "...setting that the player is the VIP" );
            NetPlayer(aPlayer.Pawn).SetIsVIP();
        }
	
        //log("Setting TimeOfLastSpawn to "$Level.TimeSeconds$" for "$StartSpot);
        //StartSpot.TimeOfLastSpawn = Level.TimeSeconds; // ckline added

        //aPlayer.Pawn.Anchor = startSpot;
        //aPlayer.Pawn.LastStartSpot = PlayerStart(startSpot);
        aPlayer.Pawn.LastStartTime = Level.TimeSeconds;
        aPlayer.PreviousPawnClass = aPlayer.Pawn.Class;

        mplog( "...about to Possess the pawn." );
        mplog( "......controller="$aPlayer );
        mplog( "......pawn="$aPlayer.Pawn );
        aPlayer.Possess(aPlayer.Pawn);
        aPlayer.PawnClass = aPlayer.Pawn.Class;

        aPlayer.Pawn.PlayTeleportEffect(true, true);
        aPlayer.ClientSetRotation(aPlayer.Pawn.Rotation);
        AddDefaultInventory(aPlayer.Pawn);
        TriggerEvent( MPStartSpot.Event, MPStartSpot, aPlayer.Pawn);
        
        SwatPlayerReplicationInfo(aPlayer.PlayerReplicationInfo).COOPPlayerStatus = STATUS_Healthy;
    }
    mplog( "...Leaving RestartPlayer()." );
}


///////////////////////////////////////////////////////////////////////////////
//
// MCJ: This is a copy of SpawnPlayerPawn(). I needed a copy for net games,
// since start points for net players are not NavigationPoints, which is what
// SpawnPlayerPawn returns.
//
function SwatMPStartPoint SpawnNetPlayerPawn(Controller aPlayer )
{
    local class<Pawn> DefaultPlayerClass;
    local SwatMPStartPoint startSpot;
    local bool SuccessfullySpawned;

    mplog( "In SwatGameInfo::SpawnNetPlayerPawn(). Controller="$aPlayer$", aPlayer.PlayerReplicationInfo="$aPlayer.PlayerReplicationInfo$", aPlayer.PlayerReplicationInfo.Team="$aPlayer.PlayerReplicationInfo.Team );

    // If in multiplayer game, and the controller is on a team, use the team's
    // default player class
    if (Level.NetMode != NM_Standalone && aPlayer.PlayerReplicationInfo.Team != None)
    {
        aPlayer.PawnClass = aPlayer.PlayerReplicationInfo.Team.DefaultPlayerClass;
    }

	if (aPlayer.PreviousPawnClass!=None && aPlayer.PawnClass != aPlayer.PreviousPawnClass)
    {
		BaseMutator.PlayerChangedClass(aPlayer);			
    }

    SuccessfullySpawned = false;
    while ( !SuccessfullySpawned )
    {
        startSpot = GameMode.FindNetPlayerStart( aPlayer );
        mplog( "...startSpot="$startSpot );
        if ( startSpot == None )
        {
            break;
        }

        if ( aPlayer.PawnClass != None )
        {
            mplog( "...1" );
            //TMC tagged player pawn 'Player'; needed for pulling loadout info from ini file
            aPlayer.Pawn = Spawn( aPlayer.PawnClass, , 'Player', startSpot.Location, StartSpot.Rotation );
        }

        if( aPlayer.Pawn == None )
        {
            mplog( "...2" );
            DefaultPlayerClass = GetDefaultPlayerClass(aPlayer);
            //TMC tagged player pawn 'Player'; needed for pulling loadout info from ini file
            aPlayer.Pawn = Spawn( DefaultPlayerClass, , 'Player', startSpot.Location, StartSpot.Rotation );
        }

        if ( aPlayer.Pawn != None )
        {
            // We successfully spawned the player.
            log("Spawned *pawn* for player "$aPlayer$" at "$StartSpot); // ckline
            SuccessfullySpawned = true;
        }
    }

    // If startSpot == None here, we failed to spawn because all of the
    // possible start spots were already used. Log it and return.
    if ( startSpot == None )
    {
        log( "Couldn't spawn pawn of class for player "$aPlayer$" because we ran out of start spots." );
#if IG_SHARED
        AssertWithDescription(false, "Couldn't spawn pawn for player "$aPlayer$" because we ran out of start spots." );
#endif
        log( "...sending controller to state Dead" );
        aPlayer.GotoState('Dead');
    }

    return startSpot;
}


function NetTeam GetTeamFromID( int TeamID )
{
    return NetTeam(GameReplicationInfo.Teams[TeamID]);    
}

///////////////////////////////////////////////////////////////////////////////
//overridden from Engine.GameInfo
event Broadcast( Actor Sender, coerce string Msg, optional name Type )
{
//log( self$"::Broadcast( "$Msg$" )" );
	BroadcastHandler.Broadcast(Sender,Msg,Type);
}

//overridden from Engine.GameInfo
function BroadcastTeam( Controller Sender, coerce string Msg, optional name Type )
{
//log( self$"::BroadcastTeam( "$Sender$", "$Msg$" ), sender.statename = "$Sender.GetStateName() );
    if( Sender.IsInState( 'ObserveTeam' ) || 
        Sender.IsInState( 'Dead' ) )
        BroadcastObservers( Sender, Msg, Type );
        
	BroadcastHandler.BroadcastTeam(Sender,Msg,Type);
}

function BroadcastObservers( Controller Sender, coerce string Msg, optional name Type )
{
	local Controller C;
	local PlayerController P;
//log( self$"::BroadcastObservers( "$Msg$" )" );

	// see if allowed (limit to prevent spamming)
	if ( !BroadcastHandler.AllowsBroadcast(Sender, Len(Msg)) )
		return;

	if ( Sender != None )
	{
		For ( C=Level.ControllerList; C!=None; C=C.NextController )
		{
			P = PlayerController(C);
			if ( ( P != None ) 
			    && ( P.PlayerReplicationInfo.Team == Sender.PlayerReplicationInfo.Team )
				&& ( P.IsInState( 'ObserveTeam' ) 
				  || P.IsInState( 'Dead' ) ) )
				P.TeamMessage( Sender.PlayerReplicationInfo, Msg, Type );
		}
	}
}

function BroadcastDeathMessage(Controller Killer, Controller Other, class<DamageType> damageType)
{
    local String KillerName;
    local String VictimName;
    local String WeaponName;
    local int VictimTeam, KillerTeam;
    local SwatPlayer OtherPlayer;

    //dont send death messages for generic deaths
    if( damageType == class'GenericDamageType' )
        return;
        
    KillerName = Killer.GetHumanReadableName();
    VictimName = Other.GetHumanReadableName();
    WeaponName = damageType.static.GetFriendlyName();   //this actually calls polymorphically into the DamageType subclass!
    if( NetPlayer(Killer.Pawn) != None )
        KillerTeam = NetPlayer(Killer.Pawn).GetTeamNumber();
    if( NetPlayer(Other.Pawn) != None )
        VictimTeam = NetPlayer(Other.Pawn).GetTeamNumber();

    // Don't send a death message if someone shot a non-VIP after he was
    // arrested.
    OtherPlayer = SwatPlayer(Other.Pawn);
    if ( OtherPlayer != None && !OtherPlayer.IsTheVIP() && OtherPlayer.IsArrested() )
        return;
    
    // Note: VictimName might be None if Controller's Pawn is destroyed before this
    // this method is called. Hopefully that won't happen, but try to do something
    // semi-intelligent in this situation.

	if( Other.IsA('PlayerController') && NetPlayer(Other.Pawn) != None && 
	    Killer.IsA('PlayerController') && NetPlayer(Killer.Pawn) != None )
	{
	    if ( (Killer == Other) || (Killer == None) )
	    {
	        if( KillerTeam == 0 )
    		    Broadcast(Other, VictimName, 'SwatSuicide');
	        else
    		    Broadcast(Other, VictimName, 'SuspectsSuicide');
		}
	    else if( KillerTeam == VictimTeam )
	    {
	        if( KillerTeam == 0 )
    		    Broadcast(Other, KillerName$"\t"$VictimName$"\t"$WeaponName, 'SwatTeamKill');
	        else
    		    Broadcast(Other, KillerName$"\t"$VictimName$"\t"$WeaponName, 'SuspectsTeamKill');
		}
		else
		{
	        if( KillerTeam == 0 )
    		    Broadcast(Other, KillerName$"\t"$VictimName$"\t"$WeaponName, 'SwatKill');
	        else
    		    Broadcast(Other, KillerName$"\t"$VictimName$"\t"$WeaponName, 'SuspectsKill');
		}
	}
	else // someone killed a non-player (e.g., an AI was killed)
	{
		Broadcast(Other, KillerName$"\t"$VictimName$"\t"$WeaponName, 'AIDeath');	// TODO: should this be a 'PlayerDeath' Message Type?
	}
}

function BroadcastArrestedMessage(Controller Killer, Controller Other)
{
    local String KillerName;
    local String VictimName;
    local int VictimTeam;

    KillerName = Killer.Pawn.GetHumanReadableName();
    VictimName = Other.Pawn.GetHumanReadableName();
    VictimTeam = NetPlayer(Other.Pawn).GetTeamNumber();
    
	AssertWithDescription( Killer != Other, KillerName $ " somehow arrested himself.  That really shouldn't ever happen!" );
	if( Other.IsA('PlayerController') && NetPlayer(Other.Pawn) != None &&
	    Killer.IsA('PlayerController') && NetPlayer(Killer.Pawn) != None )
	{
	if( VictimTeam == 1 )
    	Broadcast(Other, KillerName$"\t"$VictimName, 'SwatArrest');
	else
    	Broadcast(Other, KillerName$"\t"$VictimName, 'SuspectsArrest');
}
}

function Killed( Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType )
{
    Super.Killed( Killer, Killed, KilledPawn, damageType );
    
    SwatPlayerReplicationInfo(Killed.PlayerReplicationInfo).COOPPlayerStatus = STATUS_Incapacitated;
}


function SetPlayerTeam(SwatGamePlayerController Player, int TeamID)
{
	local TeamInfo CurrentTeam;
	local TeamInfo NewTeam;

    // Set the preferred team to the team that was requested. However, if
    // we're in COOP, this will be overridden for the current round in the
    // following code.
    Player.SwatRepoPlayerItem.SetPreferredTeamID( TeamID );

    // Make sure that players are on the SWAT
    if ( Level.IsCoopServer )
        TeamID = 0; 

    CurrentTeam = Player.PlayerReplicationInfo.Team;

    if (TeamID == 0 || TeamID == 1)
    {
        NewTeam = GameReplicationInfo.Teams[TeamID];
    }
    log( self$"::SetPlayerTeam( "$Player$", "$TeamID$" ) ... CurrentTeam = "$CurrentTeam$", NewTeam = "$NewTeam );

    // If a new team, remove from current team, kill off pawn, add to new
    // team, and restart the player
    if (NewTeam != None && CurrentTeam != NewTeam)
    {
        if (CurrentTeam != None)
        {
            CurrentTeam.RemoveFromTeam(Player);
        }

        if (Player.Pawn != None)
        {
            Player.Pawn.Died( None, class'GenericDamageType', Player.Pawn.Location, vect(0,0,0) );
            //Player.Pawn.Destroy();
        }

        NewTeam.AddToTeam(Player);

        Repo.GetRepoPlayerItem( Player.SwatPlayerID ).SetTeamID( TeamID );

        //notify the game mode that a new player has joined the team
        GetGameMode().PlayerJoinedTeam( Player, TeamID );
    }
}

///////////////////////////////////////

// This function used to be called from ClientOnLoggedIn() on an individual
// client. I've changed it to join the team designated in the Repo item rather
// than selecting a team automatically. All of this will change when we delay
// creation of the pawn; this is just a hack for the current milestone.
//
function AutoSetPlayerTeam(SwatGamePlayerController Player)
{
//     local int TeamToJoin;

//     TeamToJoin = Repo.GetRepoPlayerItem( Player.SwatPlayerID ).GetTeamID();
//     SetPlayerTeam( Player, TeamToJoin );
}


function int GetAutoJoinTeamID()
{
    local int i;
    local int lowestTeamID;
    local int lowestTeamSize;

    if (Level.NetMode == NM_Standalone || Level.IsCOOPServer)
    {
        return 0;
    }

    // Find team with lowest number of players
    lowestTeamID   = 0;
    lowestTeamSize = GameReplicationInfo.Teams[lowestTeamID].Size;
    for (i = 1; i < ArrayCount(GameReplicationInfo.Teams); i++)
    {
        if (GameReplicationInfo.Teams[i].Size < lowestTeamSize)
        {
            lowestTeamID   = i;
            lowestTeamSize = GameReplicationInfo.Teams[i].Size;
        }
    }

    return lowestTeamID;
}


function ChangePlayerTeam( SwatGamePlayerController Player )
{
    local int CurrentTeam, NewTeam;
    local SwatRepoPlayerItem RepoItem;

    RepoItem = Repo.GetRepoPlayerItem( Player.SwatPlayerID );
    CurrentTeam = RepoItem.GetTeamID();
    if ( CurrentTeam == 0 )
        NewTeam = 1;
    else
        NewTeam = 0;

    SetPlayerTeam( Player, NewTeam );
    
    if( Repo.GuiConfig.SwatGameState == GAMESTATE_MidGame )
        Broadcast( Player, Player.PlayerReplicationInfo.PlayerName, 'SwitchTeams');
}


function SetPlayerReady( SwatGamePlayerController Player )
{
    log("[dkaplan] >>> SetPlayerReady()"  );

    if( !SwatPlayerReplicationInfo(Player.PlayerReplicationInfo).GetPlayerIsReady() )
        TogglePlayerReady( Player );
}

function SetPlayerNotReady( SwatGamePlayerController Player )
{
    log("[dkaplan] >>> SetPlayerNotReady()"  );

    if( SwatPlayerReplicationInfo(Player.PlayerReplicationInfo).GetPlayerIsReady() )
        TogglePlayerReady( Player );
}

function TogglePlayerReady( SwatGamePlayerController Player )
{
    log("[dkaplan] >>> TogglePlayerReady(): Player.HasEnteredFirstRoundOfNetworkGame() = "$Player.HasEnteredFirstRoundOfNetworkGame() );

    if( SwatPlayerReplicationInfo(Player.PlayerReplicationInfo).COOPPlayerStatus == STATUS_NotReady )
        SwatPlayerReplicationInfo(Player.PlayerReplicationInfo).COOPPlayerStatus = STATUS_Ready;
    SwatPlayerReplicationInfo(Player.PlayerReplicationInfo).TogglePlayerIsReady();

#if !IG_THIS_IS_SHIPPING_VERSION
    logPlayerReadyValues();
#endif

    // Do the following if the player is a late joiner.
    if( Player != Level.GetLocalPlayerController() && (! Player.HasEnteredFirstRoundOfNetworkGame()) 
        && !bChangingLevels )
    {
        if ( Repo.GuiConfig.SwatGameState == GAMESTATE_MidGame )
        {
            PlayerLateStart( Player );
        }
        else if ( Repo.GuiConfig.SwatGameState == GAMESTATE_PostGame )
        {
            Player.ClientRoundStarted();
            Player.ClientGameEnded();
        }
    }

    TestWaitingForPlayersToReconnect();
}

function logPlayerReadyValues()
{
    local SwatGameReplicationInfo SGRI;
    local int i;
    
    SGRI = SwatGameReplicationInfo(GameReplicationInfo);
    if( SGRI == None )
        return;

    log( "The SwatGameReplicationInfo's PRIStaticArray is:" );

    for (i = 0; i < ArrayCount(SGRI.PRIStaticArray); ++i)
    {
        if (SGRI.PRIStaticArray[i] == None)
        {
            Log( "  ...PRIStaticArray["$i$"] = None " );
        }
        else
        {
            Log( "  ...PRIStaticArray["$i$"] = "$SGRI.PRIStaticArray[i]$", PlayerIsReady = "$SGRI.PRIStaticArray[i].GetPlayerIsReady() );
        }
    }
}

function PlayerLateStart( SwatGamePlayerController Player )
{
    // This function gets called if the player connects and the round is in
    // progress. The player should be put in the respawn queue for their team
    // and wait to respawn with the rest of their teammates.

    // Puts the client in midgame gamestate.
    Player.ClientRoundStarted();

    // Don't restart here...
    //RestartPlayer( Player ); 
    
	// player has entered the round (and thus had its pawn created)
	Player.SwatRepoPlayerItem.SetHasEnteredFirstRound(); 

    // Send them into observercam.
    Player.ForceObserverCam();
}

///////////////////////////////////////////////////////////////////////////////


function int NumberOfPlayersForServerBrowser()
{
    return Max( SwatRepo(Level.GetRepo()).NumberOfPlayersWhoShouldReturn(), GetNumPlayers() );
}

function int MaxPlayersForServerBrowser()
{
    return ServerSettings(Level.CurrentServerSettings).MaxPlayers;
}

function bool GameIsPasswordProtected()
{
    local SwatRepo RepoObj;

    RepoObj = SwatRepo(Level.GetRepo());
    Assert( RepoObj != None );

	if( ServerSettings(Level.CurrentServerSettings).bPassworded )
        return true;
    else
        return false;
}

function string GetPlayerName( PlayerController PC )
{
    local SwatPlayerReplicationInfo SPRI;

    SPRI = SwatPlayerReplicationInfo(PC.PlayerReplicationInfo);
    if ( SPRI == None )
        return "";

    return SPRI.PlayerName;
}

function int GetPlayerScore( PlayerController PC )
{
    local SwatPlayerReplicationInfo SPRI;

    SPRI = SwatPlayerReplicationInfo(PC.PlayerReplicationInfo);
    if ( SPRI == None )
        return 0;

    return SPRI.NetScoreInfo.GetScore();
}

function int GetPlayerPing( PlayerController PC )
{
    local SwatPlayerReplicationInfo SPRI;

    SPRI = SwatPlayerReplicationInfo(PC.PlayerReplicationInfo);
    if ( SPRI == None )
        return 999;

    return SPRI.Ping;
}


function int ReduceDamage( int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType )
{
    local int ModifiedDamage;
    local float Modifier;

    Modifier = 1;
    
    if( Level.IsCOOPServer && ClassIsChildOf(Injured.Class, class'NetPlayer') )
    {
        // In COOP, reduce damage based on MP damage modifier
        Modifier = COOPDamageModifier;
    }
    else if ( (Level.NetMode == NM_StandAlone ) &&
        (ClassIsChildOf(Injured.Class, class'SwatPlayer') || ClassIsChildOf(Injured.Class, class'SwatOfficer')))
    {
        // In single-player, reduce damage based on difficulty
        Switch(Repo.GuiConfig.CurrentDifficulty)
        {
            case DIFFICULTY_Easy:   Modifier = SPDamageModifierEasy;    break;
            case DIFFICULTY_Normal: Modifier = SPDamageModifierNormal;  break;
            case DIFFICULTY_Hard:   Modifier = SPDamageModifierHard;    break;
            case DIFFICULTY_Elite:  Modifier = SPDamageModifierElite;   break;
            default:
                Modifier = 1;
                AssertWithDescription(false, "Invalid setting ("$Repo.GuiConfig.CurrentDifficulty$") for SwatGUIConfig.CurrentDifficulty");
        }
    }
    else if (ClassIsChildOf(Injured.Class, class'NetPlayer'))
    {
        // In multiplayer, reduce damage based on MP damage modifier
        Modifier = MPDamageModifier;
    }

    ModifiedDamage = Damage * Modifier;

    if (Level.AnalyzeBallistics)
    {
        if (Level.NetMode == NM_StandAlone || Level.IsCOOPServer)
            log("[BALLISTICS]   ... SP Difficulty Damage Modifier = "$
                    Modifier$" (difficulty="$Repo.GuiConfig.CurrentDifficulty$")");
        else
            log("[BALLISTICS]   ... MP Difficulty Damage Modifier = "$Modifier);

        log("[BALLISTICS]   ... Modified Damage = "$Damage$" * "$Modifier$" = "$ModifiedDamage);
    }

    return Super.ReduceDamage(ModifiedDamage, Injured, InstigatedBy, HitLocation, Momentum, DamageType);
}

event DetailChange()
{
	local SwatOfficer officer;
	Super.DetailChange();
	foreach DynamicActors(class'SwatOfficer', officer)
	{
       officer.UpdateOfficerLOD(); // update visibility of gratuitous attachments on officers
    }
}

// Execute only on server.
function PreQuickRoundRestart()
{
    local Controller Controller;
    local SwatGamePlayerController SwatController;

    // Count the number of playercontrollers whose are reconnecting clients.
    for ( Controller = Level.ControllerList; Controller != None; Controller = Controller.NextController )
    {
        SwatController = SwatGamePlayerController(Controller);
        if (SwatController != None)
        {
            SwatController.ClientPreQuickRoundRestart();
        }
    }
    
    // Clean up garbage when quick restarting.
    //
    // The clients also do this in SwatGamePlayerController.ClientPreQuickRoundRestart()
    Log("Server in PreQuickRoundRestart: Collecting garbage.");
    ConsoleCommand( "obj garbage" );    
}

function OnServerSettingsUpdated( Controller Admin )
{
    Broadcast(Admin, Admin.GetHumanReadableName(), 'SettingsUpdated');
}

simulated event Destroyed()
{
    MissionObjectiveTimeExpired = None;

    Super.Destroyed();
}



////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
function SetLevelHasFemaleCharacters()
{
    LevelHasFemaleCharacters = true;
}

function AddMesh( Mesh inMesh )
{
    local int i;
    
    for( i = 0; i < PrecacheMeshes.Length; i++ )
    {
        if( inMesh == PrecacheMeshes[i] )
            return;
    }
    
    PrecacheMeshes[PrecacheMeshes.Length] = inMesh;
}

function AddMaterial( Material inMaterial )
{
    local int i;
    
    for( i = 0; i < PrecacheMaterials.Length; i++ )
    {
        if( inMaterial == PrecacheMaterials[i] )
            return;
    }
    
    PrecacheMaterials[PrecacheMaterials.Length] = inMaterial;
}

function AddStaticMesh( StaticMesh inStaticMesh )
{
    local int i;
    
    for( i = 0; i < PrecacheStaticMeshes.Length; i++ )
    {
        if( inStaticMesh == PrecacheStaticMeshes[i] )
            return;
    }
    
    PrecacheStaticMeshes[PrecacheStaticMeshes.Length] = inStaticMesh;
}

function PrecacheOnClient( SwatGamePlayerController SGPC )
{
    local int i;
    
    for( i = 0; i < PrecacheMaterials.Length; i++ )
    {
        SGPC.ClientAddPrecacheableMaterial( PrecacheMaterials[i].outer.name $ "." $ PrecacheMaterials[i].name );
    }
    
    for( i = 0; i < PrecacheMeshes.Length; i++ )
    {
        SGPC.ClientAddPrecacheableMesh( PrecacheMeshes[i].outer.name $ "." $ PrecacheMeshes[i].name );
    }
    
    for( i = 0; i < PrecacheStaticMeshes.Length; i++ )
    {
        SGPC.ClientAddPrecacheableStaticMesh( PrecacheStaticMeshes[i].outer.name $ "." $ PrecacheStaticMeshes[i].name );
    }
    
    SGPC.ClientPrecacheAll( LevelHasFemaleCharacters );
}

////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////


defaultproperties
{
    PlayerControllerClassName="SwatGame.SwatGamePlayerController"
    HUDType="SwatGame.SwatHUD"
    MutatorClass="SwatGame.SwatMutator"
    GameReplicationInfoClass=class'SwatGame.SwatGameReplicationInfo'
    bDelayedStart=false
    bDebugFrames=false

    SPDamageModifierEasy=0.75;
    SPDamageModifierNormal=1;
    SPDamageModifierHard=1.25;
    SPDamageModifierElite=1.5;
    MPDamageModifier=1;
    COOPDamageModifier=1;
    
    ScoringUpdateInterval=1.0
    
    ReconnectionTime=60.0
}
