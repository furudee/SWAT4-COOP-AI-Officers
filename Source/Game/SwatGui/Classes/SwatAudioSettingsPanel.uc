// ====================================================================
//  Class:  SwatGui.SwatAudioSettingsPanel
//  Parent: SwatGUIPage
//
//  Menu to load map from entry screen.
// ====================================================================

class SwatAudioSettingsPanel extends SwatSettingsPanel
     ;

var(SWATGui) private EditInline Config GUISlider MyMusicVolumeSlider;
var(SWATGui) private EditInline Config GUISlider MySoundVolumeSlider;
var(SWATGui) private EditInline Config GUISlider MyVoiceVolumeSlider;

var() private float DefaultMusicVolume;
var() private float DefaultSoundVolume;
var() private float DefaultVoiceVolume;
var() private float DefaultAmbientVolume;

function InitComponent(GUIComponent MyOwner)
{
    //log("SwatAudioSettingsPanel InitComponent()");
	Super.InitComponent(MyOwner);

    MyMusicVolumeSlider.OnChange=OnMusicVolumeChanged;
    MySoundVolumeSlider.OnChange=OnSoundVolumeChanged;
    MyVoiceVolumeSlider.OnChange=OnVoiceVolumeChanged;
}

function SaveSettings()
{
    //log("SwatAudioSettingsPanel SaveSettings()");

    GC.SaveConfig();
}

function LoadSettings()
{
    //log("SwatAudioSettingsPanel LoadSettings()");

	MySoundVolumeSlider.Value = float(PlayerOwner().ConsoleCommand("get alaudio.alaudiosubsystem soundvolume"));
	MyMusicVolumeSlider.Value = float(PlayerOwner().ConsoleCommand("get alaudio.alaudiosubsystem musicvolume"));
	MyVoiceVolumeSlider.Value = float(PlayerOwner().ConsoleCommand("get alaudio.alaudiosubsystem Voicevolume"));
}

private function OnMusicVolumeChanged( GUIComponent Sender )
{
    local float Multiplier;
    Multiplier = GUISlider(Sender).Value;
    
	//Log("Setting Music Volume to "$Multiplier);
	
    Controller.StaticExec("set alaudio.alaudiosubsystem musicvolume "$Multiplier);
}

private function OnSoundVolumeChanged( GUIComponent Sender )
{
    local float Multiplier;
    Multiplier = GUISlider(Sender).Value;
    
	//Log("Setting Sound Volume to "$Multiplier);
	
    Controller.StaticExec("set alaudio.alaudiosubsystem soundvolume "$Multiplier);
    Controller.StaticExec("set alaudio.alaudiosubsystem Ambientvolume "$Multiplier);
}

private function OnVoiceVolumeChanged( GUIComponent Sender )
{
    local float Multiplier;
    Multiplier = GUISlider(Sender).Value;

    //Log("Setting Voice Volume to "$Multiplier);
	
    Controller.StaticExec("set alaudio.alaudiosubsystem Voicevolume "$Multiplier);
}

protected function ResetToDefaults()
{
    //log("SwatAudioSettingsPanel ResetToDefaults()");

    //set the audio defaults here
    MyMusicVolumeSlider.SetValue( DefaultMusicVolume );
    MySoundVolumeSlider.SetValue( DefaultSoundVolume );
    MyVoiceVolumeSlider.SetValue( DefaultVoiceVolume );
}

defaultproperties
{
    ConfirmResetString="Are you sure that you wish to reset all audio settings to their defaults?"
    DefaultMusicVolume=0.9
    DefaultSoundVolume=0.9
    DefaultVoiceVolume=0.9
}