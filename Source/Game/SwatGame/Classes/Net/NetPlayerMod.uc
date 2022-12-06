///////////////////////////////////////////////////////////////////////////////
//
// Common base for a network player pawn
//

class NetPlayerMod extends NetPlayer;


replication
{
	reliable if ( Role == ROLE_Authority )
		OnDoorLocked;
}

simulated event PostBeginPlay() 
{
	Super.PostBeginPlay();
	log(self$" PostBeginPlay");
}

simulated event PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
}

simulated function OnDoorLocked( SwatDoor TheDoor )
{
	TheDoor.OnLocked();
}

