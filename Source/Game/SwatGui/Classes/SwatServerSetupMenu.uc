// ====================================================================
//  Class:  SwatGui.SwatServerSetupMenu
//  Parent: SwatGUIPage
//
//  Menu to load map from entry screen.
// ====================================================================

class SwatServerSetupMenu extends SwatGUIPage
     ;

import enum EMPMode from Engine.Repo;
import enum EEntryType from SwatStartPointBase;
//copied from ServerSettings
const MAX_MAPS = 40;

var(SWATGui) private EditInline Config GUIButton		    MyMainMenuButton;
var(SWATGui) private EditInline Config GUIButton		    StartButton;

var(SWATGui) private EditInline Config GUIButton		    MyQuitButton;

var(SWATGui) private EditInline Config GUINumericEdit      MyMaxPlayersBox;
var(SWATGui) private EditInline Config GUINumericEdit      MyRoundsBox;
var(SWATGui) private EditInline Config GUINumericEdit      MyDeathLimitBox;
var(SWATGui) private EditInline Config GUINumericEdit      MyPreGameTimeLimitBox;
var(SWATGui) private EditInline Config GUINumericEdit      MyTimeLimitBox;
var(SWATGui) private EditInline Config GUINumericEdit      MyPostGameTimeLimitBox;
var(SWATGui) private EditInline Config GUIEditBox          MyNameBox;
var(SWATGui) private EditInline Config GUIEditBox          MyServerNameBox;
var(SWATGui) private EditInline Config GUIEditBox          MyPasswordBox;
var(SWATGui) private EditInline Config GUIEditBox          MyAdminPasswordBox;

var(SWATGui) private EditInline Config GUISlider           MyFriendlyFireSlider;
var(SWATGui) private EditInline Config GUICheckBoxButton   MyEnemyFireButton;

var(SWATGui) private EditInline Config GUICheckBoxButton   MyPasswordedButton;
var(SWATGui) private EditInline Config GUICheckBoxButton   MyShowEnemyButton;
var(SWATGui) private EditInline Config GUICheckBoxButton   MyShowTeammatesButton;
var(SWATGui) private EditInline Config GUICheckBoxButton   MyNoRespawnButton;
var(SWATGui) private EditInline Config GUICheckBoxButton   MyQuickResetBox;
var(SWATGui) private EditInline Config GUICheckBoxButton   MyDesirePrimaryCOOPEntryPoint;
var(SWATGui) private EditInline Config GUICheckBoxButton   MyDedicatedServerCheck;
var(SWATGui) private EditInline Config GUILabel            MyDedicatedServerLabel;

var(SWATGui) private EditInline Config GUIComboBox         MyGameTypeBox;
var(SWATGui) private EditInline Config GUIComboBox         MyUseGameSpyBox;

var(SWATGui) private EditInline Config GUIListBox          DisplayOnlyMaps;

var(SWATGui) private EditInline Config GUIListBox          SelectedMaps;
var(SWATGui) private EditInline Config GUIListBox          AvailableMaps;

var(SWATGui) private EditInline Config GUIButton		   MyRemoveButton;
var(SWATGui) private EditInline Config GUIButton		   MyAddButton;
var(SWATGui) private EditInline Config GUIButton		   MyUpButton;
var(SWATGui) private EditInline Config GUIButton		   MyDownButton;

//Level information
var(SWATGui) private EditInline Config GUIImage            MyLevelScreenshot;
var(SWATGui) private EditInline Config GUILabel            MyIdealPlayerCount;
var(SWATGui) private EditInline Config GUILabel            MyLevelAuthor;
var(SWATGui) private EditInline Config GUILabel            MyLevelTitle;

var(DEBUG) private int SelectedIndex;
var() private config localized string SelectedIndexColorString;

var private config int COOPMaxPlayers;
 
var(SWATGui) private EMPMode CurGameType;

var() private config localized string BackButtonHelpString;
var() private config localized string CancelButtonHelpString;
var() private config localized string QuitButtonHelpString;
var() private config localized string AcceptButtonHelpString;
var() private config localized string StartButtonHelpString;
var() private config localized string ReStartButtonHelpString;

var() private config localized string BackButtonString;
var() private config localized string CancelButtonString;
var() private config localized string QuitButtonString;
var() private config localized string AcceptButtonString;
var() private config localized string StartButtonString;
var() private config localized string ReStartButtonString;

var() private config localized string CannotUndercutCurrentPlayersFormatString;
var() private config localized string LoadingMaplistString;
var() private config localized string HostCDKeyInvalidString;
var() private config localized string StartDedicatedServerQueryString;
var() private config localized string CannotStartDedicatedServerString;
var() private config localized string StartServerQueryString;
var() private config localized string ReStartServerQueryString;
var() private config localized string LANString;
var() private config localized string GAMESPYString;

var(DEBUG) SwatGameSpyManager SGSM;
var(DEBUG) private bool bUseGameSpy;
var(DEBUG) private bool bInGame;
var(DEBUG) private string PreviousMap;

//level summary info
var(DEBUG) private Material NoScreenshotAvailableImage;
var(DEBUG) private config localized string IdealPlayerCountString;
var(DEBUG) private config localized string LevelAuthorString;
var(DEBUG) private config localized string LevelTitleString;

var(DEBUG) private bool bUpdatingMapLists;

var(DEBUG) private GUIList FullMapList;
var(DEBUG) bool bIsAdmin;
    

///////////////////////////////////////////////////////////////////////////
// Initialization
///////////////////////////////////////////////////////////////////////////
function InitComponent(GUIComponent MyOwner)
{
    local int i;
	Super.InitComponent(MyOwner);

    FullMapList = GUIList(AddComponent("GUI.GUIList", self.Name$"_FullMapList", true ));

    LoadFullMapList();

    MyUseGameSpyBox.AddItem( LANString );
    MyUseGameSpyBox.AddItem( GAMESPYString );

    //set the available missions for the list box
	for( i = 0; i < EMPMode.EnumCount; ++i )
	{
    	MyGameTypeBox.AddItem(GC.GetGameModeName(EMPMode(i)));
    }
    MyGameTypeBox.SetIndex(0);

    SelectedMaps.List.OnDblClick=OnSelectedMapsDblClicked;
    SelectedMaps.OnChange=  OnSelectedMapsChanged;
    AvailableMaps.OnChange= OnAvailableMapsChanged;
    DisplayOnlyMaps.OnChange=OnAvailableMapsChanged;
    
    MyRemoveButton.OnClick= OnRemoveButtonClicked;
    MyAddButton.OnClick=    OnAddButtonClicked;
    MyUpButton.OnClick=     OnUpButtonClicked;
    MyDownButton.OnClick=   OnDownButtonClicked;
    
    MyGameTypeBox.OnChange=InternalOnChange;
    MyUseGameSpyBox.OnChange=InternalOnChange;
    MyPasswordedButton.OnChange=InternalOnChange;
    
    MyNameBox.OnChange=OnNameSelectionChanged;
    MyNameBox.MaxWidth = GC.MPNameLength;
    MyNameBox.AllowedCharSet = GC.MPNameAllowableCharSet;

    MyServerNameBox.OnChange=OnNameSelectionChanged;
    MyPasswordBox.OnChange=OnNameSelectionChanged;
}

///////////////////////////////////////////////////////////////////////////
// Page Activation
///////////////////////////////////////////////////////////////////////////

event HandleParameters(string Param1, string Param2, optional int param3)
{
    Super.HandleParameters( Param1, Param2, param3 );
    
    //if param1 == InGame, this is to be opened as an in game screen - special options apply
    bInGame = ( Param1 == "InGame" );


    StartButton.Hint = StartButtonHelpString;
    MyQuitButton.Hint = QuitButtonHelpString;
    MyMainMenuButton.Hint = BackButtonHelpString;

    StartButton.SetCaption( StartButtonString );
    MyQuitButton.SetCaption( QuitButtonString );
    MyMainMenuButton.SetCaption( BackButtonString );

    bIsAdmin = ( GC.SwatGameRole == GAMEROLE_MP_Host ) || SwatPlayerReplicationInfo(PlayerOwner().PlayerReplicationInfo).IsAdmin();
    LoadServerSettings( !bIsAdmin );

    MyDedicatedServerCheck.SetChecked(false);
    MyDedicatedServerCheck.SetVisibility( !bInGame );
    MyDedicatedServerCheck.SetActive( !bInGame );
    MyDedicatedServerLabel.SetVisibility( !bInGame );

    MyAdminPasswordBox.SetVisibility( GC.SwatGameRole == GAMEROLE_MP_Host );
    MyAdminPasswordBox.SetActive( GC.SwatGameRole == GAMEROLE_MP_Host );

    if( bInGame )
    {
        StartButton.Hint = ReStartButtonHelpString;
        MyQuitButton.Hint = AcceptButtonHelpString;
        MyMainMenuButton.Hint = CancelButtonHelpString;

        StartButton.SetCaption( ReStartButtonString );
        MyQuitButton.SetCaption( AcceptButtonString );
        MyMainMenuButton.SetCaption( CancelButtonString );
    }
}

function InternalOnActivate()
{
    MyQuitButton.OnClick=InternalOnClick;
    MyMainMenuButton.OnClick=InternalOnClick;
    StartButton.OnClick=InternalOnClick;

	SGSM = SwatGameSpyManager(PlayerOwner().Level.GetGameSpyManager());
	if (SGSM == None)
	{
		Log("Error:  no GameSpy manager found");
		return;
	}
}

private final function LaunchDedicatedServer()
{
    FlushConfig();
    Controller.LaunchDedicatedServer();
}

///////////////////////////////////////////////////////////////////////////
// Delegate handling
///////////////////////////////////////////////////////////////////////////
function InternalOnDlgReturned( int Selection, String passback )
{
    switch (passback)
    {
        case "StartDedicatedServer":
            if( Selection == QBTN_Ok )
            {
                SaveServerSettings();
                LaunchDedicatedServer();
            }
            break;
        case "StartServer":
            if( Selection == QBTN_Ok )
            {
                GC.FirstTimeThrough = true;

                if ( bUseGameSpy )
                {
                    // MCJ: we have to tell the GameSpyManager whether we're
                    // doing a LAN game or an Internet game, since it
                    // currently can't figure it out on it's own.
                    SGSM.SetShouldCheckClientCDKeys( true );
                }
                else
                {
                    SGSM.SetShouldCheckClientCDKeys( false );
                }

                SaveServerSettings();
                LoadSelectedMap();
            }
            break;
        case "RestartServer":
            if( Selection == QBTN_Ok )
            {
                if ( bUseGameSpy )
                {
                    // MCJ: we have to tell the GameSpyManager whether we're
                    // doing a LAN game or an Internet game, since it
                    // currently can't figure it out on it's own.
                    SGSM.SetShouldCheckClientCDKeys( true );
                }
                else
                {
                    SGSM.SetShouldCheckClientCDKeys( false );
                }
                SaveServerSettings();
                SwatPlayerController(PlayerOwner()).ServerQuickRestart();
            }
            break;
    }
}

function InternalOnChange(GUIComponent Sender)
{
    switch( Sender )
    {
        case MyPasswordedButton:
            MyPasswordBox.SetEnabled( MyPasswordedButton.bChecked );
            RefreshEnabled();
            break;
        case MyUseGameSpyBox:
            bUseGameSpy = (MyUseGameSpyBox.List.Get() == GAMESPYString);
            break;      
        case MyGameTypeBox:
            OnGameModeChanged( EMPMode(MyGameTypeBox.GetIndex()) );
            break;
    }
}


function InternalOnClick(GUIComponent Sender)
{
    local int MaxPlayers, CurrentPlayers;
    
    MaxPlayers = MyMaxPlayersBox.Value;
    CurrentPlayers = SwatGameReplicationInfo(PlayerOwner().GameReplicationInfo).NumPlayers();
    
	switch (Sender)
	{
	    case MyQuitButton:
	        if( bInGame && MaxPlayers < CurrentPlayers )
	        {
	            OpenDlg( FormatTextString( CannotUndercutCurrentPlayersFormatString, MaxPlayers, CurrentPlayers ), QBTN_OK, "IncreaseMaxPlayers" );
	            break;
	        }
    		SaveServerSettings();
		    //if in-game, accept and return
		    if( bInGame )
            {
                Controller.CloseMenu(); 
            }
            else
                Quit(); 
            break;
		case StartButton:
	        if( bInGame && MaxPlayers < CurrentPlayers )
	        {
	            OpenDlg( FormatTextString( CannotUndercutCurrentPlayersFormatString, MaxPlayers, CurrentPlayers ), QBTN_OK, "IncreaseMaxPlayers" );
	            break;
	        }

		    OnDlgReturned=InternalOnDlgReturned;
		    if( bInGame )
            {
        		OpenDlg( ReStartServerQueryString, QBTN_OkCancel, "RestartServer" );
            }
            else
            {
                // Dan, here is where we are checking the host's CD key and
                // should display a dialog if the key is not valid.
                if ( !bUseGameSpy || SGSM.IsHostCDKeyValid() )
                {
                    if( MyDedicatedServerCheck.bChecked )
                    {
                        // Dan, here's the check to use.
                        log( "mcj CanLaunchDedicatedServer="$Controller.CanLaunchDedicatedServer() );
                        if ( Controller.CanLaunchDedicatedServer() )
                            OpenDlg( StartDedicatedServerQueryString, QBTN_OkCancel, "StartDedicatedServer" );
                        else
                            OpenDlg( CannotStartDedicatedServerString, QBTN_Ok, "CannotStartDedicatedServer" );
                    }
                    else
                    {
            		    OpenDlg( StartServerQueryString, QBTN_OkCancel, "StartServer" );
                    }
                }
                else
                {
                    OpenDlg( HostCDKeyInvalidString, QBTN_Cancel, "HostCDKeyInvalid" );
                }
            }
            break;
		case MyMainMenuButton:
            //only save on back, not cancel
		    if( !bInGame && !SelectedMaps.IsEmpty() )
            {
    		    SaveServerSettings();
            }
            Controller.CloseMenu(); 
            break;
	}
}

private function OnNameSelectionChanged(GUIComponent Sender)
{
    RefreshEnabled();
}

///////////////////////////////////////////////////////////////////////////
// Start & Restart: Load a map
///////////////////////////////////////////////////////////////////////////
private function LoadSelectedMap()
{
    local String URL;
    URL = SelectedMaps.List.GetItemAtIndex(SelectedIndex) $ "?Name=" $ MyNameBox.GetText() $ "?listen";
    if (MyPasswordedButton.bChecked)
    {
        URL = URL$"?GamePassword="$MyPasswordBox.GetText();
    }

    SwatGUIController(Controller).LoadLevel(URL); 
}

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////
// Components enabling/disabling/resetting to defaults
///////////////////////////////////////////////////////////////////////////
function SetSubComponentsEnabled( bool bSetEnabled )
{
    StartButton.SetEnabled( bSetEnabled );
    MyQuitButton.SetEnabled( bSetEnabled );
    MyRemoveButton.SetEnabled( bSetEnabled );
    MyAddButton.SetEnabled( bSetEnabled );
    MyUpButton.SetEnabled( bSetEnabled );
    MyDownButton.SetEnabled( bSetEnabled );
    AvailableMaps.SetEnabled( bSetEnabled );
    SelectedMaps.SetEnabled( bSetEnabled );
    DisplayOnlyMaps.SetEnabled( bSetEnabled );
    MyMaxPlayersBox.SetEnabled( bSetEnabled );
    MyRoundsBox.SetEnabled( bSetEnabled );
    MyDeathLimitBox.SetEnabled( bSetEnabled );
    MyPreGameTimeLimitBox.SetEnabled( bSetEnabled );
    MyPostGameTimeLimitBox.SetEnabled( bSetEnabled );
    MyTimeLimitBox.SetEnabled( bSetEnabled );
    MyServerNameBox.SetEnabled( bSetEnabled && !bInGame );
    MyPasswordBox.SetEnabled( bSetEnabled && !bInGame );
    MyShowTeammatesButton.SetEnabled( bSetEnabled );
    MyEnemyFireButton.SetEnabled( bSetEnabled );
    MyFriendlyFireSlider.SetEnabled( bSetEnabled );
    MyShowEnemyButton.SetEnabled( bSetEnabled );
    MyPasswordedButton.SetEnabled( bSetEnabled && !bInGame );
    MyNoRespawnButton.SetEnabled( bSetEnabled );
    MyQuickResetBox.SetEnabled( bSetEnabled );
    MyUseGameSpyBox.SetEnabled( bSetEnabled && !bInGame );
    MyGameTypeBox.SetEnabled( bSetEnabled );
    MyNameBox.SetEnabled( bSetEnabled && !bInGame );
    MyDesirePrimaryCOOPEntryPoint.SetEnabled( bSetEnabled );
    
    MyRemoveButton.SetVisibility( bSetEnabled );
    MyAddButton.SetVisibility( bSetEnabled );
    MyUpButton.SetVisibility( bSetEnabled );
    MyDownButton.SetVisibility( bSetEnabled );
    AvailableMaps.SetVisibility( bSetEnabled );
    SelectedMaps.SetVisibility( bSetEnabled );
    DisplayOnlyMaps.SetVisibility( !bSetEnabled );
}

private function RefreshEnabled()
{
    local bool bEnableStart;
    
    bEnableStart = bIsAdmin &&
        !SelectedMaps.IsEmpty() &&
        MyNameBox.GetText() != "" &&
        MyServerNameBox.GetText() != "" &&
        ( MyPasswordBox.GetText() != "" || 
          !MyPasswordedButton.bChecked );
          
    StartButton.SetEnabled( bEnableStart );
    
    if( bInGame )
        MyQuitButton.SetEnabled( bEnableStart );

    MyPasswordBox.SetEnabled( MyPasswordedButton.bChecked );
    
    MyRemoveButton.SetEnabled( SelectedMaps.GetIndex() >= 0 );
    MyUpButton.SetEnabled( SelectedMaps.GetIndex() > 0 );
    MyDownButton.SetEnabled( SelectedMaps.GetIndex() >= 0 && SelectedMaps.GetIndex() < SelectedMaps.Num()-1 );
    MyAddButton.SetEnabled( AvailableMaps.GetIndex() >= 0 && SelectedMaps.Num() <= MAX_MAPS );
}

function ResetDefaultsForGameMode( EMPMode NewMode )
{
    //COOP special
    if( NewMode == EMPMode.MPM_COOP )
    {
        MyQuickResetBox.SetChecked(false);
        MyMaxPlayersBox.SetMaxValue( Clamp( COOPMaxPlayers, 0, 16 ) );
        MyMaxPlayersBox.SetValue( 5 );
        
        MyQuickResetBox.DisableComponent();
        MyTimeLimitBox.DisableComponent();
        MyShowEnemyButton.DisableComponent();
        MyEnemyFireButton.DisableComponent();
        MyFriendlyFireSlider.DisableComponent();
        MyFriendlyFireSlider.SetValue( 1.0 );
        
        //default to 480 second pre-game time for coop
        MyPreGameTimeLimitBox.SetValue( 480 );
        //default to 120 second pre-game time for coop
        MyPostGameTimeLimitBox.SetValue( 120 );
        
        //default 1 rounds per map for non-coop
        MyRoundsBox.SetValue( 1 );
    }
    else
    {
        MyDesirePrimaryCOOPEntryPoint.DisableComponent();
        MyQuickResetBox.SetChecked(true);
        MyMaxPlayersBox.SetMaxValue( 16 );
        MyMaxPlayersBox.SetValue( 16 );

        //default to 90 second pre-game time for non coop
        MyPreGameTimeLimitBox.SetValue( 90 );
        //default to 15 second pre-game time for non coop
        MyPostGameTimeLimitBox.SetValue( 15 );

        //default 5 rounds per map for non-coop
        MyRoundsBox.SetValue( 5 );
    }

    //Barricaded special
    if( NewMode == EMPMode.MPM_BarricadedSuspects )
    {
        MyTimeLimitBox.SetValue( 900, true );
        MyDeathLimitBox.SetValue( 50 );
    }
    else
    {
        MyDeathLimitBox.DisableComponent();
        MyNoRespawnButton.DisableComponent();
    }
    
    //Rapid deployment special
    if( NewMode == EMPMode.MPM_RapidDeployment )
    {
        MyTimeLimitBox.SetValue( 600, true );
    }
    else
    {
        //Do Nothing
    }

    //VIP special
    if( NewMode == EMPMode.MPM_VIPEscort )
    {
        MyEnemyFireButton.DisableComponent();
        MyTimeLimitBox.SetValue( 720, true );
        MyFriendlyFireSlider.DisableComponent();
        MyFriendlyFireSlider.SetValue( 1.0 );
    }
    else
    {
        //Do Nothing
    }

    MyNoRespawnButton.SetChecked(false);
    MyEnemyFireButton.SetChecked(false);
}

///////////////////////////////////////////////////////////////////////////
// Load Settings
///////////////////////////////////////////////////////////////////////////
function LoadServerSettings( optional bool ReadOnly )
{
    local ServerSettings Settings;
    
    //
    // choose the correct settings:
    //    non-admin (read-only):  Current settings
    //    admin:                  Pending settings
    //
    if( ReadOnly )
        Settings = ServerSettings(PlayerOwner().Level.CurrentServerSettings);
    else
        Settings = ServerSettings(PlayerOwner().Level.PendingServerSettings);
    
    //
    // update the game type, (also loads the available maps)
    //
    MyGameTypeBox.SetIndex(Settings.GameType);

    //
    // Load the selected maps from the ServerSettings
    //
    LoadServerMapList( SelectedMaps, Settings );

    //
    // Select the current map
    //
    SetSelectedMapsIndex( Settings.MapIndex );
    PreviousMap = SelectedMaps.List.GetItemAtIndex(SelectedIndex);

    //
    // if non-admin: Load the map list to the DisplayOnlyMaps list box
    //
    if( ReadOnly )
    {
        LoadServerMapList( DisplayOnlyMaps, Settings );

        DisplayOnlyMaps.SetIndex( Settings.MapIndex );
        UpdateSelectedIndexColoring( DisplayOnlyMaps );
        DisplayLevelSummary( LevelSummary( DisplayOnlyMaps.List.GetObject() ) );
    }

    //
    // Load the rest of the settings
    //
    MyMaxPlayersBox.SetValue(Settings.MaxPlayers, true);
    MyRoundsBox.SetValue(Settings.NumRounds, true);
    MyDeathLimitBox.SetValue(Settings.DeathLimit, true);
    MyPreGameTimeLimitBox.SetValue(Settings.MPMissionReadyTime, true);
    MyPostGameTimeLimitBox.SetValue(Settings.PostGameTimeLimit, true);
    MyTimeLimitBox.SetValue(Settings.RoundTimeLimit, true);
    MyShowTeammatesButton.SetChecked( Settings.bShowTeammateNames );
    MyEnemyFireButton.SetChecked( Settings.EnemyFireAmount == 0.0 );
    MyFriendlyFireSlider.SetValue( Settings.FriendlyFireAmount );
    MyShowEnemyButton.SetChecked( Settings.bShowEnemyNames );
    MyPasswordedButton.bForceUpdate = true;
    MyNoRespawnButton.SetChecked( Settings.bNoRespawn );
    MyQuickResetBox.SetChecked( Settings.bQuickRoundReset );
    MyDesirePrimaryCOOPEntryPoint.SetChecked( Settings.DesiredMPEntryPoint == ET_Primary );

    //
    // Update the general server information/player name
    //
    MyServerNameBox.SetText(Settings.ServerName);
    MyPasswordBox.SetText(Settings.Password);
    MyPasswordedButton.SetChecked( Settings.bPassworded );
    bUseGameSpy = !Settings.bLAN;
    if( bUseGameSpy )
        MyUseGameSpyBox.Find( GAMESPYString );
    else
        MyUseGameSpyBox.Find( LANString );

    MyNameBox.SetText(GC.MPName);
    MyAdminPasswordBox.SetText( GC.AdminPassword );
}

///////////////////////////////////////////////////////////////////////////
// Save Settings
///////////////////////////////////////////////////////////////////////////
function SaveServerSettings()
{
    local int i;
    local float EnemyFireAmount;
    local EEntryType DesiredMPEntryPoint;
    local ServerSettings Settings;

    //
    // Save to the pending server settings
    //
    Settings = ServerSettings(PlayerOwner().Level.PendingServerSettings);

    //
    // Save all maps
    //
    SwatPlayerController(PlayerOwner()).ServerClearMaps( Settings );
    for( i = 0; i < SelectedMaps.Num(); i++ )
    {
        SwatPlayerController(PlayerOwner()).ServerAddMap( Settings, SelectedMaps.List.GetItemAtindex( i ) );
    }

    //
    // Set the ServerSettings as Dirty if any of the following major changes have been made:
    //
    //  - The GameMode
    //  - LAN / Internet
    //  - Selected Map
    //
    if( Settings.GameType != CurGameType ||
        Settings.bLAN != !bUseGameSpy ||
        PreviousMap != SelectedMaps.List.GetItemAtIndex(SelectedIndex) )
    {
        SwatPlayerController(PlayerOwner()).ServerSetDirty( Settings );
    }
    
    

    //
    // Update admin server information
    //
    SwatPlayerController(PlayerOwner()).ServerSetAdminSettings( Settings,
                                MyServerNameBox.GetText(),
                                MyPasswordBox.GetText(),
                                MyPasswordedButton.bChecked,
                                !bUseGameSpy );


    //
    // Update the modifiers based on checkbox value
    //
    if( MyEnemyFireButton.bChecked )
        EnemyFireAmount = 0.0;
    else
        EnemyFireAmount = 1.0;

    if( MyDesirePrimaryCOOPEntryPoint.bChecked )
        DesiredMPEntryPoint = ET_Primary;
    else
        DesiredMPEntryPoint = ET_Secondary;

    //
    // Set the rest of the server settings
    //
    SwatPlayerController(PlayerOwner()).ServerSetSettings( Settings,
                                CurGameType,
                                SelectedIndex,
                                MyRoundsBox.Value,
                                MyMaxPlayersBox.Value,
                                MyDeathLimitBox.Value,
                                MyPostGameTimeLimitBox.Value,
                                MyTimeLimitBox.Value,
                                MyPreGameTimeLimitBox.Value,
                                MyShowTeammatesButton.bChecked,
                                MyShowEnemyButton.bChecked,
                                MyNoRespawnButton.bChecked,
                                MyQuickResetBox.bChecked,
                                MyFriendlyFireSlider.GetValue(),
                                EnemyFireAmount,
                                DesiredMPEntryPoint );
    
    SwatPlayerController(PlayerOwner()).SetName( MyNameBox.GetText() );
    GC.AdminPassword = MyAdminPasswordBox.GetText();
    GC.SaveConfig();    
}


///////////////////////////////////////////////////////////////////////////
// GameMode Updates 
///////////////////////////////////////////////////////////////////////////
function OnGameModeChanged( EMPMode NewMode )
{
    log( self$"::OnGameModeChanged( "$GetEnum(EMPMode,NewMode)$" )" );

    CurGameType = NewMode;

    //load the available map list
    LoadAvailableMaps( NewMode );
    
    //load the Map rotation for the new game mode
    LoadMapList( NewMode );
    
    SetSubComponentsEnabled( bIsAdmin );
    ResetDefaultsForGameMode( NewMode );
    
    RefreshEnabled();
    
    DisplayLevelSummary( LevelSummary( AvailableMaps.List.GetObject() ) );
}

///////////////////////////////////////////////////////////////////////////
// Maplist Management
///////////////////////////////////////////////////////////////////////////
function LoadAvailableMaps( EMPMode NewMode )
{
    local int i, j;
    local LevelSummary Summary;
    
    bUpdatingMapLists = true;

    AvailableMaps.Clear();
    
    for( i = 0; i < FullMapList.ItemCount; i++ )
    {
        Summary = LevelSummary( FullMapList.GetObjectAtIndex(i) );
        
        for( j = 0; j < Summary.SupportedModes.Length; j++ )
        {
            if( Summary.SupportedModes[j] == NewMode )
            {
                AvailableMaps.List.AddElement( FullMapList.GetAtIndex(i) );
                break;
            }
        }
    }

    AvailableMaps.List.Sort();

    bUpdatingMapLists = false;
}

function LoadMapList( EMPMode NewMode )
{
    local int i, j;
    
    bUpdatingMapLists = true;
    
    SelectedMaps.Clear();
    
    for( i = 0; i < GC.MapList[NewMode].NumMaps; i++ )
    {
        AvailableMaps.List.Find( GC.MapList[NewMode].Maps[i] );
        j = AvailableMaps.GetIndex();

        if( j < 0 )
            continue;

        SelectedMaps.List.AddElement( AvailableMaps.List.GetAtIndex(j) );
    }

    SetSelectedMapsIndex( 0 );    

    bUpdatingMapLists = false;
}

function LoadServerMapList( GUIListBox MapListBox, ServerSettings Settings )
{
    local int i, j;
    
    bUpdatingMapLists = true;
    
    MapListBox.Clear();
    
    for( i = 0; i < Settings.NumMaps; i++ )
    {
        AvailableMaps.List.Find( Settings.Maps[i] );
        j = AvailableMaps.GetIndex();

        if( j < 0 )
            continue;

        MapListBox.List.AddElement( AvailableMaps.List.GetAtIndex(j) );
    }

    bUpdatingMapLists = false;
}


function LoadFullMapList()
{
	local LevelSummary Summary;
	local string FileName;

    Controller.OpenWaitDialog( LoadingMaplistString );

    FullMapList.Clear();
    
    foreach FileMatchingPattern( "*.s4m", FileName )
    {
        //skip autoplay files (auto generated by UnrealEd)
        if( InStr( FileName, "autosave" ) != -1 )
            continue;
    
        //remove the extension
        if(Right(FileName, 4) ~= ".s4m")
			FileName = Left(FileName, Len(FileName) - 4);

        Summary = Controller.LoadLevelSummary(FileName$".LevelSummary");
        
        if( Summary == None )
        {
            log( "WARNING: Could not load a level summary for map '"$FileName$".s4m'" );
        }
        else
        {
            FullMapList.Add( FileName, Summary, Summary.Title );
        }
    }
    
    Controller.CloseWaitDialog();
}

///////////////////////////////////////////////////////////////////////////
// MapList delegate handling
///////////////////////////////////////////////////////////////////////////
function OnAddButtonClicked( GUIComponent Sender )
{
    if( AvailableMaps.GetIndex() < 0 )
        return;
        
    SelectedMaps.List.AddElement( AvailableMaps.List.GetElement() );
}

function OnRemoveButtonClicked( GUIComponent Sender )
{
    local int index;
    
    index = SelectedMaps.GetIndex();
    
    if( index < 0 )
        return;

    SelectedMaps.List.Remove( index );

    if( SelectedIndex > index )
        SelectedIndex--;
    else if( SelectedIndex == index )
        SetSelectedMapsIndex( 0 );
}

function OnUpButtonClicked( GUIComponent Sender )
{
    local int index;
    
    index = SelectedMaps.GetIndex();
    
    if( index <= 0 )
        return;
        
    SelectedMaps.List.SwapIndices( index, index-1 );
    SelectedMaps.SetIndex( index-1 );

    if( SelectedIndex == index )
        SelectedIndex--;
    else if( SelectedIndex == index-1 )
        SelectedIndex++;
}

function OnDownButtonClicked( GUIComponent Sender )
{
    local int index;
    
    index = SelectedMaps.GetIndex();
    
    if( index < 0 || index >= SelectedMaps.Num()-1 )
        return;
        
    SelectedMaps.List.SwapIndices( index, index+1 );
    SelectedMaps.SetIndex( index+1 );

    if( SelectedIndex == index )
        SelectedIndex++;
    else if( SelectedIndex == index+1 )
        SelectedIndex--;
}

function OnAvailableMapsChanged( GUIComponent Sender )
{
    if( bUpdatingMapLists )
        return;
        
    DisplayLevelSummary( LevelSummary( AvailableMaps.List.GetObject() ) );

    RefreshEnabled();
}

function OnSelectedMapsChanged( GUIComponent Sender )
{
    if( bUpdatingMapLists )
        return;
        
    MapListOnChange( CurGameType );

    if( SelectedMaps.Num() <= 1 )
        SetSelectedMapsIndex( 0 );

    DisplayLevelSummary( LevelSummary( SelectedMaps.List.GetObject() ) );
    
    RefreshEnabled();
}

function MapListOnChange( EMPMode NewMode )
{
    local int i;
    
    GC.MapList[NewMode].ClearMaps();
    
    for( i = 0; i < SelectedMaps.Num(); i++ )
    {
        GC.MapList[NewMode].AddMap( SelectedMaps.List.GetItemAtIndex(i) );
    }
    
    GC.MapList[NewMode].SaveConfig();
}

function OnSelectedMapsDblClicked( GUIComponent Sender )
{
    SetSelectedMapsIndex( SelectedMaps.GetIndex() );
}

function SetSelectedMapsIndex( int newSelectedIndex )
{
    SelectedIndex = newSelectedIndex;

    UpdateSelectedIndexColoring( SelectedMaps );
}

function UpdateSelectedIndexColoring( GUIListBox MapListBox )
{
    local int i;
    local string CurrentDisplayString;
    
    for( i = 0; i < MapListBox.Num(); i++ )
    {
        CurrentDisplayString = MapListBox.List.GetExtraAtIndex( i );

        if( Left( CurrentDisplayString, /*SelectedIndexColorString.Len()*/ 10 ) == SelectedIndexColorString )
        {
            MapListBox.List.SetExtraAtIndex( i, Mid( CurrentDisplayString, /*SelectedIndexColorString.Len()*/ 10 ) );
        }
    }

    if( MapListBox.Num() <= SelectedIndex )
        return;
    
    CurrentDisplayString = MapListBox.List.GetExtraAtIndex( SelectedIndex );

    if( InStr( CurrentDisplayString, SelectedIndexColorString ) == -1 )
    {
        MapListBox.List.SetExtraAtIndex( SelectedIndex, SelectedIndexColorString$CurrentDisplayString );
    }
}


///////////////////////////////////////////////////////////////////////////
// Display a level summary
///////////////////////////////////////////////////////////////////////////
function DisplayLevelSummary( LevelSummary Summary )
{
    if( Summary == None )
        return;
        
    if( Summary.Screenshot == None )
        MyLevelScreenshot.Image = NoScreenshotAvailableImage;
    else
        MyLevelScreenshot.Image = Summary.Screenshot;
    MyIdealPlayerCount.SetCaption( FormatTextString( IdealPlayerCountString, Summary.IdealPlayerCountMin, Summary.IdealPlayerCountMax ) );
    MyLevelAuthor.SetCaption( FormatTextString( LevelAuthorString, Summary.Author ) );
    MyLevelTitle.SetCaption( FormatTextString( LevelTitleString, Summary.Title ) );
}

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

defaultproperties
{
	OnActivate=InternalOnActivate

    LoadingMaplistString="Searching for available maps..."
    HostCDKeyInvalidString="Invalid CD Key!"	
    StartDedicatedServerQueryString="Quit the game and launch a dedicated server with the current settings?"
	StartServerQueryString="Start the server?"
	ReStartServerQueryString="Restart the server with the current settings?"

	StartButtonString="START SERVER"
	ReStartButtonString="RESTART SERVER"
	BackButtonString="MAIN"
	CancelButtonString="CANCEL"
	QuitButtonString="QUIT"
	AcceptButtonString="APPLY"

	StartButtonHelpString="Start the server with the current settings."
	ReStartButtonHelpString="Restart the server with the current settings."
	BackButtonHelpString="Return to the Main Menu."
	CancelButtonHelpString="Discard changes and return to the previous menu."
	QuitButtonHelpString="Exit the game and return to Windows."
	AcceptButtonHelpString="Apply the current settings and return to the previous menu."

    CannotStartDedicatedServerString="Cannot start dedicated server. A SWAT4 dedicated server is already running on this machine."
    CannotUndercutCurrentPlayersFormatString="Cannot proceed.  The maximum number of players (%1) cannot be less than the current number of players (%2).  Please increase the Max Players value and try again."

	LANString="LAN"
	GAMESPYString="Internet"
    bUseGameSpy=false
    
    LevelTitleString="Map: %1"
    LevelAuthorString="Author: %1"
    IdealPlayerCountString="Recommended Players: %1 - %2"
    
    SelectedIndexColorString="[c=00ff00]"
    
    COOPMaxPlayers=5
}
