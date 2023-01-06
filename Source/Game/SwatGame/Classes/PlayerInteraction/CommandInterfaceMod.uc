class CommandInterfaceMod extends CommandInterface;


var Actor PendingCommandTargetActor;
var Vector PendingCommandTargetLocation;
var vector PendingCommandOrigin;
var name LastFocusSource;
var Pawn LastPlayer;

simulated function SwatAICommon.OfficerTeamInfo GetTeamByName(name teamName)
{
    switch (teamName)
    {
        case 'RedTeam':
            return RedTeam;
        case 'BlueTeam':
            return BlueTeam;
        case 'Element':
            return Element;
        default:
            assert(false);
    }
}

simulated function name GetTeamByInfo(SwatAICommon.OfficerTeamInfo teamName)
{
    switch (teamName)
    {
        case RedTeam:
            return 'RedTeam';
        case BlueTeam:
            return 'BlueTeam';
        case Element:
            return 'Element';
        default:
            assert(false);
    }
}

simulated function ReceiveCommandMP_mod(
        int CommandIndex,           //index into Commands array of the command that is being given
        Actor Source,               //the player giving the command
        string SourceID,            //unique ID of the source
        String SourceActorName,     //the human readable name of the player giving the command
        Actor TargetActor,          //the actor that the command refers to
        string TargetID,            //unique ID of the target
        Vector TargetLocation,      //the location that the command refers to.
        eVoiceType VoiceType,		//the voice to use when playing this command
		name CommandTeam )       
{
    local Actor SourceOfSound;
    local Name VoiceTag;
	local String Color;
    
    if( Source == None && SourceID != "" )
        Source = FindByUniqueID( None, SourceID );
        
    if( TargetActor == None && TargetID != "" )
        TargetActor = FindByUniqueID( None, TargetID );
    
    //Note!  This is a command received from (potentially) another client.
    //  The PendingCommand* variables can NOT be used here.

    log("TMC CommandInterfaceMod::ReceiveCommandMP() received the command "$Commands[CommandIndex].name
            $", Source="$Source
            $", TargetActor="$TargetActor
            $", TargetLocation="$TargetLocation
            $", VoiceType="$GetEnum(eVoiceType,VoiceType)
            $", Command_MP(Commands[CommandIndex]).ArrowLifetime = "$Command_MP(Commands[CommandIndex]).ArrowLifetime );

    //taunts are played on the speaker, others are played on the listener
    if (Command_MP(Commands[CommandIndex]).IsTaunt)
        SourceOfSound = Source;
    else
        SourceOfSound = PlayerPawn;

    //choose the voice type that should be used for the source of this command
    VoiceTag = SwatRepo(Level.GetRepo()).GuiConfig.GetTagForVoiceType( VoiceType );

    //set temporary effect contexts for target SwatPawns regarding gender and hostility
    if (TargetActor != None && TargetActor.IsA('SwatPawn'))
    {
        if (TargetActor.IsA('SwatAICharacter') && SwatAICharacter(TargetActor).IsFemale())
            AddContextForNextEffectEvent('Female');
        else
            AddContextForNextEffectEvent('Male');

        //for 'OrderedRestrain', players on other team are considered suspects, ie. use more agressive language, "Tie up that idiot"
        if (TargetActor.IsA('SwatHostage'))
            AddContextForNextEffectEvent('Civilian');
        else
            AddContextForNextEffectEvent('Suspect');
    }
    //note that if the TargetActor is None or not a SwatPawn, then no temporary contexts will be added
    
    //trigger the sound effect for the command given
    if( SourceOfSound != None )
        SourceOfSound.TriggerEffectEvent(Commands[CommandIndex].EffectEvent,,,,,,,,VoiceTag);


	//display the command given as a chat message
	Switch(CommandTeam)
	{
		case 'RedTeam':
			PlayerController.ClientMessage(
				"[c=cc0000][b]"$SourceActorName $ GaveCommandString $ Commands[CommandIndex].Text,
				'CommandGiven');
			break;
        case 'BlueTeam':
			PlayerController.ClientMessage(
				"[c=3d85c6][b]"$SourceActorName $ GaveCommandString $ Commands[CommandIndex].Text,
				'CommandGiven');
			break;
        default:
			PlayerController.ClientMessage(
				"[c=FFC800][b]"$SourceActorName $ GaveCommandString $ Commands[CommandIndex].Text,
				'CommandGiven');
	}
	/*
		PlayerController.ClientMessage(
			"[c=" $ Color $ "][b]"$SourceActorName $ GaveCommandString $ Commands[CommandIndex].Text,
			'CommandGiven');
	*/
	
    //Display the Command Arrow
    if( Source != None && Command_MP(Commands[CommandIndex]).ArrowLifetime > 0.0 )
    {
        Assert( Source.IsA('SwatPlayer') );
        SwatPlayer(Source).ShowCommandArrow( Command_MP(Commands[CommandIndex]).ArrowLifetime, Source, TargetActor, Source.Location, TargetLocation, ( Command_MP(Commands[CommandIndex]).IsTaunt || Command_MP(Commands[CommandIndex]).TargetIsSelf ) );
    }
    
    //PlayerController.myHUD.AddDebugBox(TargetLocation, 5, class'Engine.Canvas'.Static.MakeColor(255,200,200), 10);
    //PlayerController.myHUD.AddDebugLine(Source.Location, TargetLocation, class'Engine.Canvas'.Static.MakeColor(255,50,50), 10);
}

simulated function GiveCommandMP()
{
    local eVoiceType VoiceType;
    local string SourceID, TargetID;
	local name CommandTeam;
	local Pawn Player;
	
	CommandTeam = GetCurrentTeam();
	Player = Level.GetLocalPlayerController().Pawn;

    PendingCommandTargetActor = GetPendingCommandTargetActor();
	log(self$" GiveCommandMP() - PendingCommandTargetActor "$PendingCommandTargetActor);

    //note that GetPendingCommandTargetActor() returns None if the PendingCommand
    //  isn't associated with any particular actor.
    if (PendingCommandTargetActor != None)
        PendingCommandTargetLocation = PendingCommandTargetActor.Location;
    else 
	{//no target actor
        PendingCommandTargetLocation = GetLastFocusLocation();  //the point where the command interface focus trace was blocked
	}
    if( NetPlayerMod(PlayerPawn) != None )
    {
        if( NetPlayerMod(PlayerPawn).IsTheVIP() )
            VoiceType = eVoiceType.VOICETYPE_VIP;
        else
            VoiceType = NetPlayerMod(PlayerPawn).VoiceType;
    }
    SourceID = PlayerPawn.UniqueID();
    if( PendingCommandTargetActor != None )
        TargetID = PendingCommandTargetActor.UniqueID();
    
    if( PlayerController.CanIssueCommand() )
    {
        PlayerController.StartIssueCommandTimer();
	
        //RPC the command to remote clients (will skip the local player)
        PlayerController.ServerGiveCommand(
            PendingCommand.Index,
            Command_MP(PendingCommand).IsTaunt,
            PlayerPawn,
            SourceID,
            PendingCommandTargetActor,
            TargetID,
            PendingCommandTargetLocation, 
            VoiceType,
			CommandTeam,
			PendingCommandTargetCharacter,
			Player	);
		
		/*
        //instant feedback on client who gives the command (the local player)
        ReceiveCommandMP(
            PendingCommand.Index,
            PlayerPawn,
            SourceID,
            PlayerController.GetHumanReadableName(),
            PendingCommandTargetActor,
            TargetID,
            PendingCommandTargetLocation,
            VoiceType );
		*/
		
		//Display the Command Arrow
		if( Player != None && Command_MP(Commands[PendingCommand.Index]).ArrowLifetime > 0.0 )	
			SwatPlayer(Player).ShowCommandArrow( Command_MP(Commands[PendingCommand.Index]).ArrowLifetime, Player, PendingCommandTargetActor, Player.Location, PendingCommandTargetLocation, ( Command_MP(Commands[PendingCommand.Index]).IsTaunt || Command_MP(Commands[PendingCommand.Index]).TargetIsSelf ) );

		StartCommand();
    }
}

state SpeakingCommand extends Speaking
{
    // called when an effect is initialized, which happens before it is started
    function OnEffectInitialized(Actor inInitializedEffect)
    {
        CommandSpeechInitialized = true;
    }

    // Called whenever an effect is started.
    function OnEffectStarted(Actor inStartedEffect) {}

    // Called whenever an effect is stopped.
    // the command speech has either completed, or it has been interrupted.
    function OnEffectStopped(Actor inStoppedEffect, bool Completed)
    {
		local name CommandTeamName;
		local Pawn Player;
		
		CommandTeamName = GetTeamByInfo(PendingCommandTeam);
		Player = Level.GetLocalPlayerController().Pawn;
		/*
		PendingCommandTargetActor = GetPendingCommandTargetActor();
		if (PendingCommandTargetActor != None)
			PendingCommandTargetLocation = PendingCommandTargetActor.Location;
		else 
		{//no target actor
			PendingCommandTargetLocation = GetLastFocusLocation();  //the point where the command interface focus trace was blocked
		}
		*/
        if (SwatRepo(Level.GetRepo()).GuiConfig.SwatGameState != GAMESTATE_MidGame)
        {
            GotoState('');
            return;
        }

        if (Completed)
        {
            log("[COMMAND INTERFACE] At Time "$Level.TimeSeconds$", "$PendingCommand.name$" completed.");
            //SendCommandToOfficers();
			PlayerController.ServerOrderOfficers(
				PendingCommand.Index,
				PendingCommandTargetActor,
				PendingCommandTargetLocation, 
				CommandTeamName,
				PendingCommandTargetCharacter,
				PendingCommandOrigin,
				Player	);
        }
        //else, PendingCommand is probably a new command that was just started

        if (CommandSpeechInitialized)
            GotoState('');
        //otherwise, we're starting a command speech that has interrupted
        //  an already-playing command speech.
        //in that case, we want to remain in the SpeakingCommand state.
    }

    //this functions as a BeginState(), but is explicitly called so that it
    //  happens even if the CommandInterfaceMod is already in this state.
    function ExplicitBeginState()
    {
        local name EffectTag;

        if (PendingCommandTargetCharacter != None)
        {
            if (PendingCommandTargetCharacter.IsA('SwatEnemy'))
            {
                if (PendingCommandTargetCharacter.IsFemale())
                    EffectTag = 'FemaleSuspect';
                else
                    EffectTag = 'MaleSuspect';
            }
            else
            if (PendingCommandTargetCharacter.IsA('SwatHostage'))
            {
                if (PendingCommandTargetCharacter.IsFemale())
                    EffectTag = 'FemaleCivilian';
                else
                    EffectTag = 'MaleCivilian';
            }
        }

        //detect if the TriggerEffectEvent didn't result in any speech
        CommandSpeechInitialized = false;

        //instigate the command speech
        Level.GetLocalPlayerController().Pawn.TriggerEffectEvent(
            PendingCommand.EffectEvent, , , , , , , Self, EffectTag);  //pass Self as IEffectObserver
        //this should generate a callback to OnEffectInitialized(), where we set CommandSpeechInitialized=true

        if (!CommandSpeechInitialized)
        {
            //triggering the speech for the pending command didn't result in any sound starting.
            //this can happen if the player is shot while giving a command, causing the player to play a higher priority sound
            Warn("[tcohen] Tried to start the speech for the pending command "$PendingCommand.name
                $", but triggering the "$PendingCommand.EffectEvent
                $" did not result in any sound starting.");
            GotoState('');  //fail-safe (otherwise the CommandInterfaceMod would appear to be "hung")
        }
    }
}



simulated function SendCommandToOfficers()
{
	if(Level.NetMode == NM_Standalone)
	{
		Super.SendCommandToOfficers();
		return;
	}
	//PendingCommandTargetActor = GetPendingCommandTargetActor();

	/*
	if (Level.GetLocalPlayerController().Pawn == None)
	{
		log("[COMMAND INTERFACE] At Time "$Level.TimeSeconds
			$", ...          in SendCommandToOfficers(), Level.GetLocalPlayerController().Pawn is none");
		return;
	}
	
	//LastFocusSource = SwatGamePlayerController(Level.GetLocalPlayerController()).GetLastFocusSource();

	//check the given command against any current expected command - for Training mission
	if  (
			(   //unexpected command
				ExpectedCommand != ''
			&&  PendingCommand.name != ExpectedCommand
			)
		||  (   //unexpected command team
				ExpectedCommandTeam != ''
			&&  PendingCommandTeam.label != ExpectedCommandTeam
			)
		||  (
				//unexpected command target door
				ExpectedCommandTargetDoor != ''
			&&  (
					PendingCommandTargetActor == None
				||  !PendingCommandTargetActor.IsA('SwatDoor')
				||  PendingCommandTargetActor.label != ExpectedCommandTargetDoor
				)
			)
		||  (   //unexpected command source
				ExpectedCommandSource != ''
			&& !IsExpectedCommandSource(LastFocusSource)
			)
		)
	{
		dispatchMessage(new class'MessageUnexpectedCommandGiven'(
					ExpectedCommand,
					ExpectedCommandTeam,
					ExpectedCommandTargetDoor,
					ExpectedCommandSource,
					PendingCommand.name,
					PendingCommandTeam.name,
					PendingCommandTargetActor.name,
					LastFocusSource));

		log("[COMMAND INTERFACE] At Time "$Level.TimeSeconds
			$", ...          sent MessageUnexpectedCommandGiven:"
			$"  ExpectedCommand="$ExpectedCommand$", PendingCommand.name="$PendingCommand.name$"."
			$"  ExpectedCommandTeam="$ExpectedCommandTeam$", PendingCommandTeam.name="$PendingCommandTeam.name$"."
			$"  PendingCommandTargetActor.class="$PendingCommandTargetActor.class.name
			$", PendingCommandTargetActor.name="$PendingCommandTargetActor.name$"."
			$". Focus: "$GetPendingFocusString());

		return;
	}
	*/
	
	log(self$" PendingCommand "$PendingCommand);
	log(self$" PendingCommandTeam "$PendingCommandTeam);
	//log("Level.GetLocalPlayerController().Pawn "$Level.GetLocalPlayerController().Pawn);
	log(self$" PendingCommandOrigin "$PendingCommandOrigin);
	log(self$" PendingCommandTargetActor "$PendingCommandTargetActor);
	//log("GetLastFocusLocation() "$GetLastFocusLocation());
	
	//
	// "THE BIG ASS SWITCH"
	//
	// Call into the current AI OfficerTeamInfo and give it the command.
	//

	assertWithDescription(PendingCommand != None,
		"[tcohen] CommandInterfaceMod::SendCommandToOfficers() was called with PendingCommand=None");

	if (PendingCommandTargetActor != None)
		log("[COMMAND INTERFACE] At Time "$Level.TimeSeconds
			$", ...          sending "$PendingCommand.name
			$" to "$PendingCommandTeam.class.name
			$". Focus: "$GetPendingFocusString()
			$"  PendingCommandTargetActor.class="$PendingCommandTargetActor.class.name
			$", PendingCommandTargetActor.name="$PendingCommandTargetActor.name$".");
	else
		log("[COMMAND INTERFACE] At Time "$Level.TimeSeconds
			$", ...          sending "$PendingCommand.name
			$" to "$PendingCommandTeam.class.name
			$". Focus: "$GetPendingFocusString()
			$"  PendingCommandTargetActor=None.");

	Switch (PendingCommand.Command)
	{

	case Command_FallIn:
		PendingCommandTeam.FallIn(
			LastPlayer,
			PendingCommandOrigin);
		break;

	case Command_MoveTo:
		PendingCommandTeam.MoveTo(
			LastPlayer,
			PendingCommandOrigin,
			PendingCommandTargetLocation);
		break;

	case Command_Cover:
		PendingCommandTeam.Cover(
			LastPlayer, 
			PendingCommandOrigin,
			PendingCommandTargetLocation);
		break;

	case Command_Deploy_Flashbang:
		PendingCommandTeam.DeployThrownItemAt(
			LastPlayer, 
			PendingCommandOrigin,
			Slot_Flashbang,
			PendingCommandTargetLocation,
			SwatDoor(PendingCommandTargetActor));
		Back();
		break;

	case Command_Deploy_CSGas:
		PendingCommandTeam.DeployThrownItemAt(
			LastPlayer, 
			PendingCommandOrigin,
			Slot_CSGasGrenade,
			PendingCommandTargetLocation,
			SwatDoor(PendingCommandTargetActor));
		Back();
		break;

	case Command_Deploy_StingGrenade:
		PendingCommandTeam.DeployThrownItemAt(
			LastPlayer, 
			PendingCommandOrigin,
			Slot_StingGrenade,
			PendingCommandTargetLocation,
			SwatDoor(PendingCommandTargetActor));
		Back();
		break;

	case Command_Disable:
		if (PendingCommandTargetActor != None)
			PendingCommandTeam.DisableTarget(
				LastPlayer, 
				PendingCommandOrigin,
					PendingCommandTargetActor);
		break;

	case Command_RemoveWedge:
		PendingCommandTeam.RemoveWedge(
			LastPlayer, 
			PendingCommandOrigin,
			SwatDoor(PendingCommandTargetActor));
		break;

	case Command_SecureEvidence:
		if (PendingCommandTargetActor != None)
		PendingCommandTeam.SecureEvidence(
			LastPlayer, 
			PendingCommandOrigin,
				PendingCommandTargetActor);
		break;

	case Command_MirrorCorner:
		if (PendingCommandTargetActor != None)
			PendingCommandTeam.MirrorCorner(
				LastPlayer, 
				PendingCommandOrigin,
					PendingCommandTargetActor);
		break;

	//Commands that require a valid Door

	case Command_StackUpAndTryDoor:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.StackUpAndTryDoorAt(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_PickLock:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.PickLock(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_MoveAndClear:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.MoveAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	//clear with nothing

	case Command_BreachAndClear:
	case Command_BreachAndMakeEntry:
	case Command_OpenAndClear:
	case Command_OpenAndMakeEntry:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.BreachAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	//clear with bang

	case Command_BangAndClear:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.BangAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_BreachBangAndClear:
	case Command_BreachBangAndMakeEntry:
	case Command_OpenBangAndClear:
	case Command_OpenBangAndMakeEntry:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.BreachBangAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	//clear with gas

	case Command_GasAndClear:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.GasAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_BreachGasAndClear:
	case Command_BreachGasAndMakeEntry:
	case Command_OpenGasAndClear:
	case Command_OpenGasAndMakeEntry:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.BreachGasAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	//clear with sting

	case Command_StingAndClear:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.StingAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_BreachStingAndClear:
	case Command_BreachStingAndMakeEntry:
	case Command_OpenStingAndClear:
	case Command_OpenStingAndMakeEntry:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.BreachStingAndClear(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_Deploy_C2Charge:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.DeployC2(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		Back();
		break;

	case Command_Deploy_BreachingShotgun:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.DeployShotgun(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		Back();
		break;

	case Command_Deploy_Wedge:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.DeployWedge(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		Back();
		break;

	case Command_CloseDoor:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.CloseDoor(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_MirrorRoom:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.MirrorRoom(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	case Command_MirrorUnderDoor:
		if (CheckForValidDoor(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.MirrorUnderDoor(
				LastPlayer, 
				PendingCommandOrigin,
				SwatDoor(PendingCommandTargetActor));
		break;

	//Commands that require a valid Pawn

	case Command_Restrain:
		if (CheckForValidPawn(PendingCommand, PendingCommandTargetActor))
			PendingCommandTeam.Restrain(
				LastPlayer, 
				PendingCommandOrigin,
				Pawn(PendingCommandTargetActor));
		break;

	case Command_Deploy_PepperSpray:
		if (CheckForValidPawn(PendingCommand, PendingCommandTargetActor))
		{
			PendingCommandTeam.DeployPepperSpray(
				LastPlayer, 
				PendingCommandOrigin,
				Pawn(PendingCommandTargetActor));
			Back();
		}
		break;

	case Command_Deploy_Taser:
		if (CheckForValidPawn(PendingCommand, PendingCommandTargetActor))
		{
			PendingCommandTeam.DeployTaser(
				LastPlayer, 
				PendingCommandOrigin,
				Pawn(PendingCommandTargetActor));
			Back();
		}
		break;

	case Command_Deploy_LessLethalShotgun:
		if (CheckForValidPawn(PendingCommand, PendingCommandTargetActor))
		{
			PendingCommandTeam.DeployLessLethalShotgun(
				LastPlayer, 
				PendingCommandOrigin,
				Pawn(PendingCommandTargetActor));
			Back();
		}
		break;

	case Command_Deploy_CSBallLauncher:
		if (CheckForValidPawn(PendingCommand, PendingCommandTargetActor))
		{
			PendingCommandTeam.DeployPepperBallGun(
				LastPlayer, 
				PendingCommandOrigin,
				Pawn(PendingCommandTargetActor));
			Back();
		}
		break;

	default:
		assertWithDescription(false,
			"[tcohen] CommandInterfaceMod::SendCommandToOfficers() Unexpected command "$GetEnum(ECommand,PendingCommand.Command));
		return;
	}

	if  (
			PendingCommandTargetActor != None
		&&  PendingCommandTargetActor.IsA('SwatDoor')
		)
		dispatchMessage(new class'MessageCommandGiven'(PendingCommand.name, PendingCommandTeam.label, PendingCommandTargetActor.label));
	else
		dispatchMessage(new class'MessageCommandGiven'(PendingCommand.name, PendingCommandTeam.label, ''));

	return;
	
}

simulated function GiveCommand(Command Command)
{
    local SwatGamePlayerController Player;
    local ExternalViewportManager ExternalViewportManager;
    local IControllableThroughViewport Controllable;
    local Actor OriginActor;

    //handle cancel command
    if (Command.IsCancel)
    {
        CancelGivingCommand();
        return;
    }
    
    //handle submenu anchors
    if (Command.SubPage != Page_None)
    {
        SetCurrentPage(Command.SubPage);
        return;
    }

    //determine the source of the command
    Player = SwatGamePlayerController(Level.GetLocalPlayerController());

    //return early if the player is dead or has no pawn to issue commands from
    if( Player.Pawn == None || Player.Pawn.CheckDead( Player.Pawn ) )
    {
        return;
    }
    
    FlushPendingCommand();
    
    ExternalViewportManager = Player.GetExternalViewportManager();
    if (Player.ActiveViewport == ExternalViewportManager)
    {
        Controllable = ExternalViewportManager.GetCurrentControllable();
        OriginActor = Actor(Controllable);
        assert(Controllable != None);
        PendingCommandOrigin = ExternalViewportManager.GetCurrentControllable().GetViewportLocation();
    }
    else
    {
        OriginActor = Player.Pawn;
        PendingCommandOrigin = LastFocusUpdateOrigin;
    }

    PendingCommand = Command;
    PendingCommandTeam = CurrentCommandTeam;
    PendingCommandFoci = Foci;
    PendingCommandFociLength = FociLength;
    PendingCommandTargetCharacter = SwatAICharacter(GetFocusOfClass('SwatAICharacter'));
    
    log("[COMMAND INTERFACE] At Time "$Level.TimeSeconds
        $", Player began to give "$Command.name
        $" through "$OriginActor.name
        $" from ("$PendingCommandOrigin
        $") to "$CurrentCommandTeam
        $".  Focus: "$GetPendingFocusString());

	log("COMMAND INTERFACE-GiveCommand()---CURRENTCOMMANDTEAM: "$CurrentCommandTeam);

    if (Level.NetMode == NM_Standalone)
        GiveCommandSP();
	else
        GiveCommandMP();
}


simulated function bool CheckForValidPawn(Command Command, Actor Pawn)
{
    local bool ValidPawn;

    ValidPawn = (Pawn != None && Pawn.IsA('Pawn'));
    assertWithDescription(ValidPawn,
        "[tcohen] CommandInterfaceMod::CheckForValidPawn() Gave "$GetEnum(ECommand, Command.Command)
        $" which requires a valid Pawn, but Pawn="$Pawn);
	log(self$" CheckForValidPawn - ValidPawn: "$ValidPawn);
    return ValidPawn;
}