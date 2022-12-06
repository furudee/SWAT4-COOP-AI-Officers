class CustomScenario_EnemiesTabPanel extends CustomScenarioTabPanel;

var(SWATGui) EditInline Config GUICheckBoxButton            chk_campaign;
var(SWATGui) EditInline Config GUIPanel                     pnl_body;
var(SWATGui) EditInline Config GUIImage                     pnl_DisabledOverlay;
var(SWATGui) EditInline Config GUIDualSelectionLists        dlist_archetypes;

var(SWATGui) EditInline Config GUIComboBox                  cbo_primary_type;
var(SWATGui) EditInline Config GUIComboBox                  cbo_primary_specific;
var(SWATGui) EditInline Config GUIComboBox                  cbo_backup_type;
var(SWATGui) EditInline Config GUIComboBox                  cbo_backup_specific;

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
var(SwatGUI) EditInline Config GUIComboBox                  cbo_skill;

function InitComponent(GUIComponent MyOwner)
{
    local int i;

	Super.InitComponent(MyOwner);

    Data = CustomScenarioPage.CustomScenarioCreatorData;

    chk_campaign.OnChange                = chk_campaign_OnChange;

    cbo_primary_type.OnListIndexChanged = cbo_primary_type_OnChanged;
    cbo_primary_type.OnChange           = cbo_primary_type_OnChanged;
    cbo_backup_type.OnListIndexChanged  = cbo_backup_type_OnChanged;
    cbo_backup_type.OnChange            = cbo_backup_type_OnChanged;

    spin_count_min.OnChange             = spin_count_min_OnChange;
    spin_count_max.OnChange             = spin_count_max_OnChange;
    slide_morale_min.OnChange             = slide_morale_min_OnChange;
    slide_morale_max.OnChange             = slide_morale_max_OnChange;

    //fill skills
    cbo_skill.AddItem("Any",, Data.AnyString);
    cbo_skill.AddItem("Low",, Data.LowString);
    cbo_skill.AddItem("Medium",, Data.MediumString);
    cbo_skill.AddItem("High",, Data.HighString);

    //fill weapon types
    cbo_primary_type.AddItem("Any",, Data.AnyString);  //the localized word "Any"
    cbo_Backup_type.AddItem("Any",, Data.AnyString);   //the localized word "Any"
    cbo_primary_type.AddItem("None",, Data.NoneString);  //the localized word "None"
    cbo_Backup_type.AddItem("None",, Data.NoneString);   //the localized word "None"
    for (i=0; i<Data.PrimaryWeaponCategory.length; ++i)
        cbo_primary_type.AddItem(
                string(Data.PrimaryWeaponCategory[i]),
                , 
                Data.PrimaryWeaponCategoryDescription[i]);
    for (i=0; i<Data.BackupWeaponCategory.length; ++i)
        cbo_backup_type.AddItem(
                string(Data.BackupWeaponCategory[i]),
                , 
                Data.BackupWeaponCategoryDescription[i]);
    //specifics are disabled until type changes
    cbo_primary_specific.AddItem("Any",, Data.AnyString);
    cbo_primary_specific.SetEnabled(false);
    cbo_backup_specific.AddItem("Any",, Data.AnyString);
    cbo_backup_specific.SetEnabled(false);
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

function cbo_primary_type_OnChanged(GUIComponent Sender)
{
    local int i;
    local name SelectedType;
    local class<FiredWeapon> WeaponClass;

    SelectedType = name(cbo_primary_type.List.Get());
    
    cbo_primary_specific.Clear();

    switch (SelectedType)
    {
    case 'Any':
        cbo_primary_specific.AddItem("Any",, Data.AnyString);
        cbo_primary_specific.SetEnabled(false);
        break;

    case 'None':
        cbo_primary_specific.AddItem("None",, Data.NoneString);
        cbo_primary_specific.SetEnabled(false);
        break;

    default:
        //TMC TODO prevent None-None weapon selections. Why?
        cbo_primary_specific.AddItem("Any",, Data.AnyString);
        
        //anything else, populate the "specific" list with specific weapons
        for (i=0; i<Data.PrimaryWeapon.length; ++i)
        {
            if (Data.PrimaryWeapon[i].Category == SelectedType)
            {
                WeaponClass = class<FiredWeapon>(DynamicLoadObject(Data.PrimaryWeapon[i].Weapon, class'Class'));
                assertWithDescription(WeaponClass != None,
                    "[tcohen] CustomScenario_EnemiesTabPanel::cbo_primary_type_OnChanged() "
                    $"While populating specific weapon choices for primary weapon type "$SelectedType
                    $", found that PrimaryWeapon["$i
                    $"].Weapon, specified as "$Data.PrimaryWeapon[i].Weapon
                    $" could not be DLO'd.");

                cbo_primary_specific.AddItem(Data.PrimaryWeapon[i].Weapon,, WeaponClass.default.FriendlyName);
            }
        }
        cbo_primary_specific.SetEnabled(true);
    }
}

function cbo_backup_type_OnChanged(GUIComponent Sender)
{
    local int i;
    local name SelectedType;
    local class<FiredWeapon> WeaponClass;

    SelectedType = name(cbo_backup_type.List.Get());
    
    cbo_backup_specific.Clear();

    switch (SelectedType)
    {
    case 'Any':
        cbo_backup_specific.AddItem("Any",, Data.AnyString);
        cbo_backup_specific.SetEnabled(false);
        break;

    case 'None':
        cbo_backup_specific.AddItem("None",, Data.NoneString);
        cbo_backup_specific.SetEnabled(false);
        break;

    default:
        cbo_backup_specific.AddItem("Any",, Data.AnyString);

        //anything else, populate the "specific" list with specific weapons
        for (i=0; i<Data.BackupWeapon.length; ++i)
        {
            if (Data.BackupWeapon[i].Category == SelectedType)
            {
                WeaponClass = class<FiredWeapon>(DynamicLoadObject(Data.BackupWeapon[i].Weapon, class'Class'));
                assertWithDescription(WeaponClass != None,
                    "[tcohen] CustomScenario_EnemiesTabPanel::cbo_backup_type_OnChanged() "
                    $"While populating specific weapon choices for backup weapon type "$SelectedType
                    $", found that BackupWeapon["$i
                    $"].Weapon, specified as "$Data.BackupWeapon[i].Weapon
                    $" could not be DLO'd.");

                cbo_backup_specific.AddItem(Data.BackupWeapon[i].Weapon,, WeaponClass.default.FriendlyName);
            }
        }
        cbo_backup_specific.SetEnabled(true);
    }
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
    local EnemyArchetype Archetype;
    local int i,j;

    Scenario = CustomScenarioPage.GetCustomScenario();

    chk_campaign.SetChecked(Scenario.UseCampaignEnemySettings, true);

    spin_count_min.SetValue(Scenario.EnemyCountRangeCow.Min, true);
    spin_count_max.SetValue(Scenario.EnemyCountRangeCow.Max, true);

    slide_morale_min.SetValue(Scenario.EnemyMorale.Min);
    slide_morale_max.SetValue(Scenario.EnemyMorale.Max);
    
    dlist_archetypes.ListBoxA.Clear();
    dlist_archetypes.ListBoxB.Clear();
    
    //fill archetypes
    for (i=0; i<Data.EnemyArchetype.length; ++i)
    {
        Archetype = new(None, string(Data.EnemyArchetype[i].Archetype)) class'EnemyArchetype';
        //NOTE! We're not calling Archetype.Initialize() because we won't actually use this Archetype
        //  for anything except reading its config data.

        if (NewScenario)
        {
            //when populating a new scenario,
            //  add an archetype to the "Selected" list iff it is ByDefault

            if (Data.EnemyArchetype[i].ByDefault)
                //add to List A: Selected Archetypes
                dlist_archetypes.ListBoxB.List.Add(
                        string(Data.EnemyArchetype[i].Archetype),
                        ,
                        Archetype.Description);
            else
                //add to List B: Available Archetypes
                dlist_archetypes.ListBoxA.List.Add(
                        string(Data.EnemyArchetype[i].Archetype),
                        ,
                        Archetype.Description);
        }
        else    //!NewScenario
        {
            //when populating an existing scenario,
            //  add an archetype to the "Selected" list iff it is selected in the Scenario

            for (j=0; j<Scenario.EnemyArchetypes.length; ++j)
            {
                if (Scenario.EnemyArchetypes[j] == Data.EnemyArchetype[i].Archetype)
                {
                    //add to List A: Selected Archetypes
                    dlist_archetypes.ListBoxB.List.Add(
                            string(Data.EnemyArchetype[i].Archetype),
                            ,
                            Archetype.Description);
                    break;
                }
            }
            if (j == Scenario.EnemyArchetypes.length)  //the Archetype was not found in the Scenario
                //add to List B: Available Archetypes
                dlist_archetypes.ListBoxA.List.Add(
                        string(Data.EnemyArchetype[i].Archetype),
                        ,
                        Archetype.Description);
        }
    }
    
    dlist_archetypes.ListBoxA.SetIndex(0);
    dlist_archetypes.ListBoxB.SetIndex(0);
    
    if (NewScenario)
    {
        cbo_skill.SetIndex(0);

        cbo_primary_type.SetIndex(0);
        cbo_primary_specific.SetIndex(0);
        cbo_backup_type.SetIndex(0);
        cbo_backup_specific.SetIndex(0);
    }
    else
    {
        cbo_skill.List.Find(Scenario.EnemySkill, true);

        cbo_primary_type.List.Find(Scenario.EnemyPrimaryWeaponType, true);   //bExact=true.
        cbo_primary_specific.List.Find(Scenario.EnemyPrimaryWeaponSpecific, true);   //bExact=true.
        cbo_backup_type.List.Find(Scenario.EnemyBackupWeaponType, true);   //bExact=true.
        cbo_backup_specific.List.Find(Scenario.EnemyBackupWeaponSpecific, true);   //bExact=true.
    }
}

function GatherScenarioFromFields()
{
    local CustomScenario Scenario;
    local int i;

    Scenario = CustomScenarioPage.GetCustomScenario();

    Scenario.UseCampaignEnemySettings = chk_campaign.bChecked;

    Scenario.EnemyCountRangeCow.Min = spin_count_min.Value;
    Scenario.EnemyCountRangeCow.Max = spin_count_max.Value;

    Scenario.EnemyMorale.Min = slide_morale_min.Value;
    Scenario.EnemyMorale.Max = slide_morale_max.Value;
    
    //add archetypes
    Scenario.EnemyArchetypes.Remove(0, Scenario.EnemyArchetypes.length);
    for (i=0; i<dlist_archetypes.ListBoxB.List.Elements.length; ++i)
        Scenario.EnemyArchetypes[Scenario.EnemyArchetypes.length] = name(dlist_archetypes.ListBoxB.List.GetItemAtIndex(i));

    Scenario.EnemySkill = cbo_skill.List.Get();
    
    Scenario.EnemyPrimaryWeaponType = cbo_primary_type.List.Get();
    Scenario.EnemyPrimaryWeaponSpecific = cbo_primary_specific.List.Get();
    GatherWeaponsOfType(
            Scenario.EnemyPrimaryWeaponType, 
            Scenario.EnemyPrimaryWeaponSpecific, 
            Data.PrimaryWeapon,
            Scenario.EnemyPrimaryWeaponOptions);

    Scenario.EnemyBackupWeaponType = cbo_backup_type.List.Get();
    Scenario.EnemyBackupWeaponSpecific = cbo_backup_specific.List.Get();
    GatherWeaponsOfType(
            Scenario.EnemyBackupWeaponType, 
            Scenario.EnemyBackupWeaponSpecific, 
            Data.BackupWeapon,
            Scenario.EnemyBackupWeaponOptions);
}

function GatherWeaponsOfType(
        string Type, 
        string Specific, 
        array<CustomScenarioCreatorData.WeaponPresentation> WeaponOptions,
        out array<string> WeaponSelections)
{
    local int i;

    WeaponSelections.Remove(0, WeaponSelections.length);

    if (Type == "None")     //no weapon
        return;
    else
    if (Specific != "Any")  //a specific weapon was supplied
        WeaponSelections[WeaponSelections.length] = Specific;
    else
    if (Type == "Any")      //any weapon at all
        for (i=0; i<WeaponOptions.length; ++i)
            WeaponSelections[WeaponSelections.length] = WeaponOptions[i].Weapon;
    else                    //all weapons of the Type
        for (i=0; i<WeaponOptions.length; ++i)
            if (string(WeaponOptions[i].Category) == Type)
                WeaponSelections[WeaponSelections.length] = WeaponOptions[i].Weapon;
}
