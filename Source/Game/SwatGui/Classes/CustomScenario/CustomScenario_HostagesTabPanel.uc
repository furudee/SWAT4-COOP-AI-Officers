class CustomScenario_HostagesTabPanel extends CustomScenarioTabPanel;

var(SWATGui) EditInline Config GUICheckBoxButton            chk_campaign;
var(SWATGui) EditInline Config GUIPanel                     pnl_body;
var(SWATGui) EditInline Config GUIImage                     pnl_DisabledOverlay;
var(SWATGui) EditInline Config GUIDualSelectionLists        dlist_archetypes;

var(SwatGUI) EditInline Config GUILabel                     lbl_count;
var(SwatGUI) EditInline Config GUINumericEdit               spin_count_min;
var(SwatGUI) EditInline Config GUILabel                     lbl_count_min;
var(SwatGUI) EditInline Config GUILabel                     lbl_count_max;
var(SwatGUI) EditInline Config GUINumericEdit               spin_count_max;
var(SwatGUI) EditInline Config GUILabel                     lbl_morale;
var(SwatGUI) EditInline Config GUISlider                    slide_morale_min;
var(SwatGUI) EditInline Config GUILabel                     lbl_morale_min;
var(SwatGUI) EditInline Config GUILabel                     lbl_morale_max;
var(SwatGUI) EditInline Config GUISlider                    slide_morale_max;

function InitComponent(GUIComponent MyOwner)
{
	Super.InitComponent(MyOwner);

    Data = CustomScenarioPage.CustomScenarioCreatorData;

    chk_campaign.OnChange = chk_campaign_OnChange;
    
    spin_count_min.OnChange             = spin_count_min_OnChange;
    spin_count_max.OnChange             = spin_count_max_OnChange;
    slide_morale_min.OnChange             = slide_morale_min_OnChange;
    slide_morale_max.OnChange             = slide_morale_max_OnChange;
}


event Activate()
{
    Super.Activate();
    
    SetPanelActive();
}

private function SetPanelActive()
{
    pnl_body.SetActive( !chk_campaign.bChecked );
    pnl_DisabledOverlay.SetVisibility( chk_campaign.bChecked );
}

function chk_campaign_OnChange(GUIComponent Sender)
{
    SetPanelActive();
}

function spin_count_min_OnChange(GUIComponent Sender)
{
    if (spin_count_max.Value < spin_count_min.Value)
        spin_count_max.SetValue(spin_count_min.Value);
}

function spin_count_max_OnChange(GUIComponent Sender)
{
    if (spin_count_min.Value > spin_count_max.Value)
        spin_count_min.SetValue(spin_count_max.Value);
}

function slide_morale_min_OnChange(GUIComponent Sender)
{
    if( slide_morale_max.Value < slide_morale_min.Value )
        slide_morale_max.SetValue(slide_morale_min.Value);
}

function slide_morale_max_OnChange(GUIComponent Sender)
{
    if( slide_morale_min.Value > slide_morale_max.Value )
        slide_morale_min.SetValue(slide_morale_max.Value);
}

// CustomScenarioTabPanel overrides

function PopulateFieldsFromScenario(bool NewScenario)
{
    local CustomScenario Scenario;
    local HostageArchetype Archetype;
    local int i,j;

    Scenario = CustomScenarioPage.GetCustomScenario();

    chk_campaign.SetChecked(Scenario.UseCampaignHostageSettings, true);

    spin_count_min.SetValue(Scenario.HostageCountRangeCow.Min, true);
    spin_count_max.SetValue(Scenario.HostageCountRangeCow.Max, true);

    slide_morale_min.SetValue(Scenario.HostageMorale.Min);
    slide_morale_max.SetValue(Scenario.HostageMorale.Max);
    
    dlist_archetypes.ListBoxA.Clear();
    dlist_archetypes.ListBoxB.Clear();
    
    //fill archetypes
    for (i=0; i<Data.HostageArchetype.length; ++i)
    {
        Archetype = new(None, string(Data.HostageArchetype[i].Archetype)) class'HostageArchetype';
        //NOTE! We're not calling Archetype.Initialize() because we won't actually use this Archetype
        //  for anything except reading its config data.

        if (NewScenario)
        {
            //when populating a new scenario,
            //  add an archetype to the "Selected" list iff it is ByDefault

            if (Data.HostageArchetype[i].ByDefault)
                //add to List A: Selected Archetypes
                dlist_archetypes.ListBoxB.List.Add(
                        string(Data.HostageArchetype[i].Archetype),
                        ,
                        Archetype.Description);
            else
                //add to List B: Available Archetypes
                dlist_archetypes.ListBoxA.List.Add(
                        string(Data.HostageArchetype[i].Archetype),
                        ,
                        Archetype.Description);
        }
        else    //!NewScenario
        {
            //when populating an existing scenario,
            //  add an archetype to the "Selected" list iff it is selected in the Scenario

            for (j=0; j<Scenario.HostageArchetypes.length; ++j)
            {
                if (Scenario.HostageArchetypes[j] == Data.HostageArchetype[i].Archetype)
                {
                    //add to List A: Selected Archetypes
                    dlist_archetypes.ListBoxB.List.Add(
                            string(Data.HostageArchetype[i].Archetype),
                            ,
                            Archetype.Description);
                    break;
                }
            }
            if (j == Scenario.HostageArchetypes.length)  //the Archetype was not found in the Scenario
                //add to List B: Available Archetypes
                dlist_archetypes.ListBoxA.List.Add(
                        string(Data.HostageArchetype[i].Archetype),
                        ,
                        Archetype.Description);
        }
    }
    
    dlist_archetypes.ListBoxA.SetIndex(0);
    dlist_archetypes.ListBoxB.SetIndex(0);

    //TMC TODO Set count_min/max captions from mission specific spawning data (iff Scenario.UseCampaignObjectives)
}

function GatherScenarioFromFields()
{
    local CustomScenario Scenario;
    local int i;

    Scenario = CustomScenarioPage.GetCustomScenario();

    Scenario.UseCampaignHostageSettings = chk_campaign.bChecked;

    Scenario.HostageCountRangeCow.Min = spin_count_min.Value;
    Scenario.HostageCountRangeCow.Max = spin_count_max.Value;

    Scenario.HostageMorale.Min = slide_morale_min.Value;
    Scenario.HostageMorale.Max = slide_morale_max.Value;
    
    //add archetypes
    Scenario.HostageArchetypes.Remove(0, Scenario.HostageArchetypes.length);
    for (i=0; i<dlist_archetypes.ListBoxB.List.Elements.length; ++i)
        Scenario.HostageArchetypes[Scenario.HostageArchetypes.length] = name(dlist_archetypes.ListBoxB.List.GetItemAtIndex(i));
}
