class GraphicCommandInterface_SP extends GraphicCommandInterfaceMod
    config(PlayerInterface_Command_SP);

defaultproperties
{
    CommandClass=class'Command_SP'
    StaticCommandsClass=class'CommandInterfaceStaticCommands_SP'
    MenuInfoClass=class'CommandInterfaceMenuInfo_SP'
    ContextsListClass=class'CommandInterfaceContextsList_SP'
    ContextClass=class'CommandInterfaceContext_SP'
    DoorRelatedContextClass=class'CommandInterfaceDoorRelatedContext_SP'
}
