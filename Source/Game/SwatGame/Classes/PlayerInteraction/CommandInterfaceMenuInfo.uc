class CommandInterfaceMenuInfo extends Core.Object
    PerObjectConfig
    abstract;

var config CommandInterfaceMod.ECommand            AnchorCommand;
var config bool                                 CascadeUp;
var config localized string                     Text;
var config name                                 OverrideDefaultCommand;

var Command                                     OverrideDefaultCommandObject;

function bool IsAvailable(LevelInfo Level)
{
    return true;
}
