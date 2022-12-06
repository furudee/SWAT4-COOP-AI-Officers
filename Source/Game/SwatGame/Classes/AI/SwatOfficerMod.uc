///////////////////////////////////////////////////////////////////////////////
class SwatOfficerMod extends SwatOfficer;



simulated event PreBeginPlay()
{
	log("test2 prebeginplay");
	Super.PreBeginPlay();
}

simulated event PostBeginPlay()
{
	log("test2 postbeginplay");
	Super.PostBeginPlay();
	 
	if(Level.NetMode == NM_Client)
	{
		AddToSquads();
		InitLoadOut(OfficerLoadOutType);
	}
}

simulated function PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	log(self$" PostNetBeginPlay");

}

simulated function InitLoadOut( String LoadOutName )
{
	log("test2 initloadout start");
	Super.InitLoadOut(LoadOutName);
	//ReceiveLoadOut();
	log("test2 initloadout end");
}

simulated function ReceiveLoadOut() 
{
	log("test2 receiveloadout start");
	Super.ReceiveLoadOut();
	log("test2 receiveloadout end");

}



///////////////////////////////////////////////////////////////////////////////

defaultproperties
{
    bHavokCharacterCollisions=false

	bAlwaysUseWalkAimErrorWhenMoving=true
	bAlwaysTestPathReachability=true
	//bNoRepMesh=false
	//bReplicateAnimations=true
	//RemoteRole=4
	bAlwaysRelevant=true
}

