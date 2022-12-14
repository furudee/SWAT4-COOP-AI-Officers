class GraphicCommandInterfaceMod extends CommandInterfaceMod;

var  GUIGraphicCommandInterface View;
var  bool bIsClosed;
var  bool bWasClosedBeforePageChange;

simulated function Initialize()
{
    local SwatGamePlayerController Player;

    Player = SwatGamePlayerController(Level.GetLocalPlayerController());
	log(self$" Initialize()");
    View = Player.GetHUDPage().GraphicCommandInterfaceMod;
    assert(View != None);
log( self$"::Initialize() ... Setting the Logic to self!" );
    View.SetLogic(self);

    View.ClearAllCommands();

    Super.Initialize();

    View.OnCurrentTeamChanged(CurrentCommandTeam);

    SetCurrentPage(CurrentMainPage, true);    //force update

    View.CloseInstantly();
}

//
// Update Sequence - See documentation above PlayerFocusInterface::PreUpdate()
//

simulated protected function bool PreUpdateHook(SwatGamePlayerController Player, HUDPageBase HUDPage)
{
    return Super.PreUpdateHook(Player, HUDPage) && bIsClosed;
}

//
// (End of Update Sequence)
//

simulated function CancelGivingCommand()
{
	log(self$" CancelGivingCommand()");
    Close();
}

simulated function Open()
{
	log(self$" Open()");
    if (!Enabled || !SwatGamePlayerController(Level.GetLocalPlayerController()).CanOpenGCI())
    {
        TriggerEffectEvent('Denied');
        return;
    }

    SwatGamePlayerController(Level.GetLocalPlayerController()).UpdateFocus();
    View.Open();
    
    bIsClosed = false;
}

simulated protected function PostDeactivated()
{
	log(self$" PostDeactivated()");
    View.Hide();
}

//
// forward calls to the view
//

simulated function Close()
{
	log(self$" Close()");
    View.Close();
    bIsClosed = true;
}

simulated protected function OnCurrentTeamChanged(SwatAICommon.OfficerTeamInfo NewTeam)
{
    if (View != None)
        View.OnCurrentTeamChanged(NewTeam);
}

simulated function ClearCommands(bool PageChange)
{
    if (View != None)
        View.ClearCommands(PageChange);
}

simulated function SetCommand(Command Command, MenuPadStatus Status)
{
    if (View != None)
        View.SetCommand(Command, Status);
}

simulated event Destroyed()
{
	log(self$" Destroyed()");

    View = None;

    Super.Destroyed();
}

//called from CommandInterfaceMod::SetMainPage(), usually as a result of NextMainPage()
simulated protected function PreMainPageChanged()
{
    bWasClosedBeforePageChange = bIsClosed;
    bIsClosed=true;
    
    if (View != None)
        View.CloseInstantly();
}

//called from CommandInterfaceMod::SetMainPage(), usually as a result of NextMainPage()
simulated protected function PostMainPageChanged()
{
	//restore bIsClosed from before the page change
    bIsClosed = bWasClosedBeforePageChange;

	//if we are not closed, open the view.
    if (View != None && !bIsClosed)
        View.Open();
}

cpptext
{
    UBOOL Tick(FLOAT DeltaSeconds, enum ELevelTick TickType);
}

defaultproperties
{
    bStatic=false
    Physics=PHYS_None
    bStasis=true
    bIsClosed=true
}
