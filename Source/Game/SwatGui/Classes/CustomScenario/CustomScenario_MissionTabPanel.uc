class CustomScenario_MissionTabPanel extends CustomScenarioTabPanel;

var(SWATGui) EditInline Config GUIComboBox                  cbo_mission;
var(SWATGui) private EditInline Config GUICheckBoxButton    chk_campaign_objectives;
var(SWATGui) EditInline Config GUIDualSelectionLists        dlist_objectives;
var(SWATGui) private EditInline Config GUILabel             lbl_mission;
var(SWATGui) private EditInline Config GUILabel             lbl_spawn_point;
var(SWATGui) private EditInline Config GUIRadioButton       opt_primary;
var(SWATGui) private EditInline Config GUILabel             lbl_primary;
var(SWATGui) private EditInline Config GUIRadioButton       opt_either;
var(SWATGui) private EditInline Config GUIRadioButton       opt_secondary;
var(SWATGui) private EditInline Config GUICheckBoxButton    chk_time_limit;
var(SWATGui) private EditInline Config GUILabel             lbl_time_limit;
var(SWATGui) private EditInline Config GUILabel             lbl_no_limit;
var(SWATGui) private EditInline Config GUILabel             lbl_either;
var(SWATGui) private EditInline Config GUILabel             lbl_secondary;
var(SWATGui) private EditInline Config GUILabel             lbl_primary_detail;
var(SWATGui) private EditInline Config GUILabel             lbl_secondary_detail;
var(SWATGui) private EditInline Config GUINumericEdit       time_limit;
var(SWATGui) private EditInline Config GUIComboBox          cbo_difficulty;

var MissionObjectives CustomMissionObjectives;  //the set of available objectives for custom scenarios

function InitComponent(GUIComponent MyOwner)
{
    local int i;

	Super.InitComponent(MyOwner);

    Data = CustomScenarioPage.CustomScenarioCreatorData;

    chk_time_limit.OnChange = chk_time_limit_OnChange;

    chk_campaign_objectives.OnChange = chk_campaign_objectives_OnChange;

    cbo_mission.OnChange = cbo_mission_OnListIndexChanged;

    //fill mission combo list
    for (i=0; i<GC.MissionName.length; ++i)
        cbo_mission.AddItem(string(GC.MissionName[i]),, GC.FriendlyName[i]);

    //fill difficulties
    cbo_difficulty.AddItem("Any",, Data.AnyString);
    cbo_difficulty.AddItem("Easy",, Data.EasyString);
    cbo_difficulty.AddItem("Normal",, Data.NormalString);
    cbo_difficulty.AddItem("Hard",, Data.HardString);
    cbo_difficulty.AddItem("Elite",, Data.EliteString);
}

function chk_time_limit_OnChange(GUIComponent Sender)
{
    time_limit.SetEnabled(!chk_time_limit.bChecked);
}

function chk_campaign_objectives_OnChange(GUIComponent Sender)
{
    local CustomScenarioCreatorMissionSpecificData MissionData;

    MissionData = Data.GetMissionData_Slow(name(cbo_mission.List.Get()));

    UpdateSpawnCounts(MissionData);
}

function cbo_mission_OnListIndexChanged(GUIComponent Sender)
{
    local CustomScenarioCreatorMissionSpecificData MissionData;

    MissionData = Data.GetMissionData_Slow(name(cbo_mission.List.Get()));

    UpdateSpawnCounts(MissionData);

    //update entry points

    AssertWithDescription( MissionData.PrimarySpawnPoint != "", "Error! There is no Primary Spawn point available for this Map!" );

    lbl_primary_detail.SetCaption(MissionData.PrimarySpawnPoint);
    opt_primary.EnableComponent();

    if (MissionData.SecondarySpawnPoint != "")
    {
        lbl_secondary_detail.SetCaption(MissionData.SecondarySpawnPoint);
        opt_secondary.EnableComponent();
        opt_either.EnableComponent(); //both options available, either is available
        opt_either.SelectRadioButton(); //both options available, select either by default
    }
    else
    {
        lbl_secondary_detail.SetCaption(Data.UnavailableString);
        opt_secondary.DisableComponent();
        opt_either.DisableComponent(); //both options available, either is un-available
        opt_primary.SelectRadioButton(); //only primary available, select primary by default
    }
}

//update the controls on the Enemies and Hostages tabs, including lbl_count, spin_count_min, and spin_count_max
function UpdateSpawnCounts(CustomScenarioCreatorMissionSpecificData MissionData)
{
    local int NumEnemies, NumHostages;

    //
    //Enemies
    //

    NumEnemies = MissionData.CampaignObjectiveEnemySpawn.length;

    if  (
            chk_campaign_objectives.bChecked
        &&  NumEnemies > 0
        )
    {
        //"Number of enemies, including {#} campiagn objectives."
        CustomScenarioPage.pnl_enemies_pnl_body_lbl_count.SetCaption(
                Data.NumberOfEnemiesString
            $   Data.CommaIncludingString
            $   " "
            $   NumEnemies
            $   " "
            $   Data.CampaignObjectivesString);

        CustomScenarioPage.pnl_enemies_spin_count_min.SetMinValue(NumEnemies);
    }
    else
    {
        //"Number of enemies, including {#} campiagn objectives."
        CustomScenarioPage.pnl_enemies_pnl_body_lbl_count.SetCaption(Data.NumberOfEnemiesString);

        CustomScenarioPage.pnl_enemies_spin_count_min.SetMinValue(0);
    }

    //max'es are the number of spawners
    CustomScenarioPage.pnl_enemies_spin_count_min.SetMaxValue(MissionData.EnemySpawners);
    CustomScenarioPage.pnl_enemies_spin_count_max.SetMaxValue(MissionData.EnemySpawners);

    //
    //Hostages
    //

    NumHostages = MissionData.CampaignObjectiveHostageSpawn.length;

    if  (
            chk_campaign_objectives.bChecked
        &&  NumHostages > 0
        )
    {
        //"Number of hostages, including {#} campiagn objectives."
        CustomScenarioPage.pnl_hostages_pnl_body_lbl_count.SetCaption(
                Data.NumberOfHostagesString
            $   Data.CommaIncludingString
            $   " "
            $   MissionData.CampaignObjectiveHostageSpawn.length
            $   " "
            $   Data.CampaignObjectivesString);

        CustomScenarioPage.pnl_hostages_spin_count_min.SetMinValue(NumHostages);
    }
    else
    {
        //"Number of hostages, including {#} campiagn objectives."
        CustomScenarioPage.pnl_hostages_pnl_body_lbl_count.SetCaption(Data.NumberOfHostagesString);

        CustomScenarioPage.pnl_hostages_spin_count_min.SetMinValue(0);
    }

    //max'es are the number of spawners
    CustomScenarioPage.pnl_hostages_spin_count_min.SetMaxValue(MissionData.HostageSpawners);
    CustomScenarioPage.pnl_hostages_spin_count_max.SetMaxValue(MissionData.HostageSpawners);
}

//reset the state of dlist_objectives to present all potential
//  objectives as "available" and none as "selected"
//This method is used in preparation for populating the data
//  from a Scenario, ie. any objectives specified in the
//  Scenario will be "added".
function InitializeObjectives()
{
    local int i;

    if (CustomMissionObjectives == None)
    {
        CustomMissionObjectives = new (None, "CustomScenario") class'SwatGame.MissionObjectives';
        assert(CustomMissionObjectives != None);
    }

    dlist_objectives.ListBoxA.List.Clear();
    dlist_objectives.ListBoxB.List.Clear();

    for (i=0; i<CustomMissionObjectives.Objectives.length; ++i)
        if (CustomMissionObjectives.Objectives[i].name != 'Automatic_DoNot_Die')
            dlist_objectives.ListBoxA.List.Add(
                    string(CustomMissionObjectives.Objectives[i].name),
                    , 
                    CustomMissionObjectives.Objectives[i].Description);
}

// CustomScenarioTabPanel overrides

function PopulateFieldsFromScenario(bool NewScenario)
{
    local int i;
    local CustomScenario Scenario;
    local string Found;

    Scenario = CustomScenarioPage.GetCustomScenario();

    //mission
    cbo_mission.List.Find(string(Scenario.LevelLabel), true);   //bExact=true.
    //note that GUIList::Find() acutally selects the found item

    //objectives
    InitializeObjectives();
    chk_campaign_objectives.SetChecked(Scenario.UseCampaignObjectives);
    for (i=0; i<Scenario.ScenarioObjectives.length; ++i)
    {
        Found = dlist_objectives.ListBoxA.List.Find(string(Scenario.ScenarioObjectives[i]));
        assertWithDescription(Found != "",
            "[tcohen] CustomScenario_MissionTabPanel::PopulateFieldsFromScenario()"
            $" Couldn't find selected Objective named "$Scenario.ScenarioObjectives[i]
            $" in dlist_objectives.ListBoxA.");
        dlist_objectives.MoveAB(None);  //move the objective from "available" to "selected"
    }

    //entry options
    if (!NewScenario)
    {
        if (Scenario.SpecifyStartPoint)
        {
            if (Scenario.UseSecondaryStartPoint)
                opt_secondary.SelectRadioButton();
            else
                opt_primary.SelectRadioButton();
        }
        else
            opt_either.SelectRadioButton();
    }

    //difficulty
    if (NewScenario)
        cbo_difficulty.SetIndex(0);
    else
        cbo_difficulty.List.Find(Scenario.Difficulty, true);

    //time limit
    chk_time_limit.SetChecked(Scenario.TimeLimit == 0);  //this should trigger chk_time_limit_Onchanged()
    if (Scenario.TimeLimit > 0)
        time_limit.SetValue(Scenario.TimeLimit, true);
    else
        time_limit.SetValue(Data.DefaultTimeLimit, true);
}

function GatherScenarioFromFields()
{
    local int i;
    local CustomScenario Scenario;

    Scenario = CustomScenarioPage.GetCustomScenario();

    Scenario.LevelLabel = name(cbo_mission.List.Get());
    
    //gather Objectives, including TimeLimit

    Scenario.UseCampaignObjectives = chk_campaign_objectives.bChecked;

    //clear mission objectives
    Scenario.ScenarioObjectives.Remove(0, Scenario.ScenarioObjectives.length);
    //add specified objectives
    for (i=0; i<dlist_objectives.ListBoxB.List.Elements.length; ++i)
        Scenario.ScenarioObjectives[i] = name(dlist_objectives.ListBoxB.List.GetItemAtIndex(i));

    Scenario.Difficulty = cbo_difficulty.List.Get();
    
    Scenario.SpecifyStartPoint = !opt_either.bChecked;
    if (!opt_either.bChecked)
        Scenario.UseSecondaryStartPoint = opt_secondary.bChecked;

    if (chk_time_limit.bChecked)
        Scenario.TimeLimit = 0;
    else
        Scenario.TimeLimit = time_limit.Value;
}

event Activate()
{
    Data.SetCurrentMissionDirty();
    Super.Activate();
}
