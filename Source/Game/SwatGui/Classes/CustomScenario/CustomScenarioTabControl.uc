class CustomScenarioTabControl extends GUI.GUITabControl;

enum ETabPanels
{
    Tab_Selection,
    Tab_Mission,
    Tab_Squad,
    Tab_Hostages,
    Tab_Enemies,
    Tab_Notes,
    Tab_Save,
};

function OpenTabByIndex( int index )
{
    InternalOpenTabPair( MyTabs[index] );
}

function InternalOpenTabPair( sTabButtonPair theTab )
{
    local int i;
    
    if( theTab == MyTabs[ ETabPanels.Tab_Selection ] && CustomScenarioPage(MenuOwner).CustomScenarioCreatorData.IsCurrentMisisonDirty() )
    {
        CustomScenarioPage(MenuOwner).ConfirmQuitOrSave( "Selection" );
        return;
    }
    
    Super.InternalOpenTabPair( theTab );

    if( theTab == MyTabs[ ETabPanels.Tab_Selection ] )
    {
        for( i = 0; i < ETabPanels.EnumCount; i++ )
        {
            if( i == ETabPanels.Tab_Selection )
                continue;
            MyTabs[i].TabHeader.DisableComponent();
        }
    }
    else if( theTab == MyTabs[ ETabPanels.Tab_Save ] )
    {
        MyTabs[ETabPanels.Tab_Selection].TabHeader.DisableComponent();
    }
    else
    {
        //enable all others
        for( i = 0; i < ETabPanels.EnumCount; i++ )
        {
            if( MyTabs[i] != theTab )
                MyTabs[i].TabHeader.EnableComponent();
        }
    }
}