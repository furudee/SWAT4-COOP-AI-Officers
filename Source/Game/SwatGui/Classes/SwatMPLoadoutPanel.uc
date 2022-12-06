// ====================================================================
//  Class:  SwatGui.SwatMPLoadoutPanel
//  Parent: SwatGUIPanel
//
//  Menu to load map from entry screen.
// ====================================================================

class SwatMPLoadoutPanel extends SwatLoadoutPanel
    ;

///////////////////////////
// Initialization & Page Delegates
///////////////////////////
function InitComponent(GUIComponent MyOwner)
{
	Super.InitComponent(MyOwner);
	SwatGuiController(Controller).SetMPLoadoutPanel(self);
}

function LoadMultiPlayerLoadout()
{
    //create the loadout & send to the server, then destroy it
    SpawnLoadouts();
    DestroyLoadouts();
}

protected function SpawnLoadouts() 
{
    LoadLoadOut( "CurrentMultiplayerLoadOut", true );
}

protected function DestroyLoadouts() 
{
    if( MyCurrentLoadOut != None )
        MyCurrentLoadOut.destroy();
    MyCurrentLoadOut = None;
}

///////////////////////////
//Utility functions used for managing loadouts
///////////////////////////
function LoadLoadOut( String loadOutName, optional bool bForceSpawn )
{
    Super.LoadLoadOut( loadOutName, bForceSpawn );

//    MyCurrentLoadOut.ValidateLoadOutSpec();
    SwatGUIController(Controller).SetMPLoadOut( MyCurrentLoadOut );
}

function ChangeLoadOut( Pocket thePocket )
{
    local class<actor> theItem;
//log("[dkaplan] changing loadout for pocket "$GetEnum(Pocket,thePocket) );
    Super.ChangeLoadOut( thePocket );
    SaveLoadOut( "CurrentMultiPlayerLoadout" ); //save to current loadout

    switch (thePocket)
    {
        case Pocket_PrimaryWeapon:
        case Pocket_PrimaryAmmo:
            SwatGUIController(Controller).SetMPLoadOutPocketWeapon( Pocket_PrimaryWeapon, MyCurrentLoadOut.LoadOutSpec[Pocket.Pocket_PrimaryWeapon], MyCurrentLoadOut.LoadOutSpec[Pocket.Pocket_PrimaryAmmo] );
            break;
        case Pocket_SecondaryWeapon:
        case Pocket_SecondaryAmmo:
            SwatGUIController(Controller).SetMPLoadOutPocketWeapon( Pocket_SecondaryWeapon, MyCurrentLoadOut.LoadOutSpec[Pocket.Pocket_SecondaryWeapon], MyCurrentLoadOut.LoadOutSpec[Pocket.Pocket_SecondaryAmmo] );
            break;
        case Pocket_Breaching:
            SwatGUIController(Controller).SetMPLoadOutPocketItem( Pocket.Pocket_Breaching, MyCurrentLoadOut.LoadOutSpec[Pocket.Pocket_Breaching] );
            SwatGUIController(Controller).SetMPLoadOutPocketItem( Pocket.Pocket_HiddenC2Charge1, MyCurrentLoadOut.LoadOutSpec[Pocket.Pocket_HiddenC2Charge1] );
            SwatGUIController(Controller).SetMPLoadOutPocketItem( Pocket.Pocket_HiddenC2Charge2, MyCurrentLoadOut.LoadOutSpec[Pocket.Pocket_HiddenC2Charge2] );
            break;
        default:
            theItem = class<actor>(EquipmentList[thePocket].GetObject());
            SwatGUIController(Controller).SetMPLoadOutPocketItem( thePocket, theItem );
            break;
    }
}

function bool CheckValidity( eNetworkValidity type )
{
    return (type == NETVALID_MPOnly) || (Super.CheckValidity( type ));
}

defaultproperties
{
}
