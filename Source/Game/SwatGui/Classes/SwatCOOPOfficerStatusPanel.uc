// ====================================================================
//  Class:  SwatGui.SwatCOOPOfficerStatusPanel
//  Parent: GUIPanel
//
//  Menu to load map from entry screen.
// ====================================================================

class SwatCOOPOfficerStatusPanel extends SwatGUIPanel
     ;

import enum COOPStatus from SwatGame.SwatPlayerReplicationInfo;

var(SWATGui) private EditInline Config GUIMultiColumnListBox MyTeamBox;

var() private config localized string IncapacitatedString;
var() private config localized string InjuredString;
var() private config localized string HealthyString;
var() private config localized string NotAvailable;
var() private config localized string NotReady;
var() private config localized string Ready;

var private bool bSelectThisPlayer;
var private int SelectPlayerCount;

function InitComponent(GUIComponent MyOwner)
{
	Super.InitComponent(MyOwner);
}

event Show()
{
    Super.Show();
    SetTimer( GC.MPPollingDelay, true );
}

event Timer()
{
    if( SelectPlayerCount++ > 10 )
        bSelectThisPlayer = true;
    DisplayScores();
}


function DisplayScores()
{
    local SwatGameReplicationInfo SGRI;
    local SwatPlayerReplicationInfo PlayerInfo;
    local int i,row;
    local int lastSelected;
    local string PlayerName;

    SGRI = SwatGameReplicationInfo( PlayerOwner().GameReplicationInfo );
    
    if( SGRI == None )
        return;
        
    lastSelected=MyTeamBox.GetIndex();
    MyTeamBox.Clear();

    //populate the players into their team boxes, sorted by score
    for (i = 0; i < ArrayCount(SGRI.PRIStaticArray); ++i)
    {
        PlayerInfo = SGRI.PRIStaticArray[i];
        if (PlayerInfo != None)
        {
            PlayerName = PlayerInfo.PlayerName;
            if( SwatPlayerController(PlayerOwner()).ShouldDisplayPRIIds )
            {
                PlayerName = "[b]["$i$"][\\b]"$PlayerName;
            }
            MyTeamBox.AddNewRowElement( "Ping",,,Min(999,PlayerInfo.Ping));
            MyTeamBox.AddNewRowElement( "Teamnames",,PlayerName,PlayerInfo.SwatPlayerID);
            MyTeamBox.AddNewRowElement( "Health",,GetStatusString( PlayerInfo.COOPPlayerStatus ));

            //if( PlayerInfo.GetPlayerIsReady() )

            row = MyTeamBox.PopulateRow();
        }
    }

    if( bSelectThisPlayer )
    {
        if( MyTeamBox.GetColumn( "Teamnames" ).FindExtraIntData(SwatPlayerReplicationInfo(PlayerOwner().PlayerReplicationInfo).SwatPlayerID,,true) == -1 )
            MyTeamBox.MyActiveList.SetIndex(-1,,true);
    }
    else
    {
        MyTeamBox.MyActiveList.SetIndex(lastSelected,,true);
    }

    if( bSelectThisPlayer )
    {
        bSelectThisPlayer = false;
        SelectPlayerCount = 0;
    }
}

private function string GetStatusString( COOPStatus status )
{
    switch(status)
    {
        case STATUS_NotReady:
            if( GC.SwatGameState != GAMESTATE_MidGame )
                return NotReady;
            else
                return NotAvailable;
        case STATUS_Ready:
            if( GC.SwatGameState != GAMESTATE_MidGame )
                return Ready;
            else
                return NotAvailable;
        case STATUS_Healthy:
            return HealthyString;
        case STATUS_Injured:
            return InjuredString;
        case STATUS_Incapacitated:
            return IncapacitatedString;
    }

    return "";
}

defaultproperties
{
    Ready="[c=00FF00]Ready"
    NotReady="[c=FF0000]Not Ready"
    HealthyString="Healthy"
    InjuredString="[c=ff0000]Injured"
    IncapacitatedString="[c=ff0000][b]Incapacitated"
    NotAvailable="[c=ff00ff][b]Not Available"
}