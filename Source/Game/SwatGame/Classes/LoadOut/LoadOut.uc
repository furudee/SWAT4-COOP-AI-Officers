class LoadOut extends LoadOutValidationBase
    native
    abstract
    perObjectConfig
    dependsOn(SwatEquipmentSpec)
    Config(StaticLoadout);

import enum EquipmentSlot from Engine.HandheldEquipment;
import enum Pocket from Engine.HandheldEquipment;
import enum eEquipmentType from SwatGame.SwatEquipmentSpec;
import enum eNetworkValidity from SwatGame.SwatGUIConfig;

// The Actual Equipment
var(DEBUG) protected Actor PocketEquipment[Pocket.EnumCount];

// Cached reference to the GuiConfig
var(DEBUG) SwatGUIConfig GC;

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Completely initialize a loadout.  The procedure is as follows:
// 
// - Replace any static spec data with valid Dynamic spec data
// - Validate entire loadout.  Replace any invalid equipment with the pocket's defaults
// - Spawn the equipment from the LoadoutSpec
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated function Initialize(DynamicLoadOutSpec DynamicSpec)
{
    GC = SwatRepo(level.GetRepo()).GuiConfig;
    Assert( GC != None );

 	if (Level.GetEngine().EnableDevTools)
	    log(self.Name$" >>> Initialize( "$DynamicSpec$" )");

//     if( DynamicSpec != None )
//     {
//         log(self.Name$" ... Dynamic Loadout spec:");
//         DynamicSpec.PrintLoadOutSpecToMPLog();
//     }
    
//     log(self.Name$" ... Static Loadout spec:");
//     PrintLoadOutSpecToMPLog();

    if( DynamicSpec != None )
    {
        MutateLoadOutSpec( DynamicSpec );

        //log(self.Name$" ... After mutation:");
        //PrintLoadOutSpecToMPLog();
    }
    
    ValidateLoadOutSpec();

    //log(self.Name$" ... After validation:");
    //PrintLoadOutSpecToMPLog();

    SpawnEquipmentFromLoadOutSpec();

    //log(self.Name$" ... Spawned equipment:");
    //PrintLoadOutToMPLog();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Mutate the static loadout with the given dynamic loadout.  
//      Ignore any invalid equipment in the dynamic loadout
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated protected function MutateLoadOutSpec(DynamicLoadOutSpec DynamicSpec)
{
    local int i;
    
    // The VIP may have no dynamic part, and, in cases like that, no mutation
    // is necessary.
    if ( DynamicSpec == None )
        return;

    for( i = 0; i <= Pocket.Pocket_HiddenC2Charge2; i++ )
    {
        if ( i == Pocket.Pocket_Detonator || i == Pocket.Pocket_Cuffs || i == Pocket.Pocket_IAmCuffed )
            continue;

        if( ValidateEquipmentForPocket( Pocket(i), DynamicSpec.LoadOutSpec[i] ) &&
            ValidForLoadoutSpec( DynamicSpec.LoadOutSpec[i], Pocket(i) ) )
            LoadOutSpec[i] = DynamicSpec.LoadOutSpec[i];
        else
        {
            warn("Dynamic LoadOut is invalid: Failed to validate equipment class "$DynamicSpec.LoadOutSpec[i]$" specified for pocket "$GetEnum( Pocket, i )$" in DyanicSpec "$DynamicSpec.name );
            AssertWithDescription( false, self.Name$":  Failed to validate equipment class "$DynamicSpec.LoadOutSpec[i]$" specified for pocket "$GetEnum( Pocket, i )$" in DyanicSpec "$DynamicSpec.name);
        }
    }

    for( i = 0; i < MaterialPocket.EnumCount; i++ )
    {
        if( DynamicSpec.MaterialSpec[i] != None )
            MaterialSpec[i] = DynamicSpec.MaterialSpec[i];
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Validate the final loadout spec.  
//      Replace any invalid equipment in the loadout spec with the defaults for that pocket.
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated function bool ValidateLoadOutSpec()
{
    local int i;
    
    for( i = 0; i < Pocket.EnumCount; i++ )
    {
        if( !ValidateEquipmentForPocket( Pocket(i), LoadOutSpec[i] ) ||
            !ValidForLoadoutSpec( LoadOutSpec[i], Pocket(i) ) )
        {
            warn("Failed to validate equipment class "$LoadOutSpec[i]$" specified in DynamicLoadout.ini for pocket "$GetEnum( Pocket, i ) );
            AssertWithDescription( false, self.Name$":  Failed to validate equipment class "$LoadOutSpec[i]$" specified in DynamicLoadout.ini for pocket "$GetEnum( Pocket, i ));
            
            //replace with default for pocket
            LoadOutSpec[i] = DLOClassForPocket( Pocket(i), 0 );
        }
    }
    
    return true;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Validate a single piece of quipment in a given pocket.  
//      Returns true iff the equipment class is valid in the current game mode
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated protected function bool ValidateEquipmentForPocket( Pocket pock, class<Actor> CheckClass )
{
    local int i;
    local class<Actor> EquipClass;
    local int NumEquipment;
    local bool Valid;

    NumEquipment = GC.AvailableEquipmentPockets[pock].EquipmentClassName.Length;
    
    if( CheckClass == None && NumEquipment == 0)
        return true;
        
    for( i = 0; i < NumEquipment; i++ )
    {
        EquipClass = DLOClassForPocket( pock, i );
                
        //did we find it?
        if( CheckClass == EquipClass )
        {
            Valid = CheckValidity( GC.AvailableEquipmentPockets[pock].Validity[i] );
            break;
        }
    }
    
    return Valid;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Utility: DLO's a class for the pocket spec of the given pocket at the given index
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated private function class<actor> DLOClassForPocket( Pocket pock, int index )
{
    local string ClassName;
    local class<actor> DLOClass;
    
    ClassName = GC.AvailableEquipmentPockets[pock].EquipmentClassName[index];
    
    if( ClassName == "None" || ClassName == "" )
        return None;

    DLOClass = class<Actor>(DynamicLoadObject(ClassName,class'class'));
    AssertWithDescription( DLOClass != None, self.Name$":  Could not DLO invalid equipment class "$ClassName$" specified in the pocket specifications section of SwatEquipment.ini." );

    return DLOClass;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Utility: Check the validity given the current game mode
//      Returns true iff the current game mode matches the input validity
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated protected function bool CheckValidity( eNetworkValidity type )  //may be further subclassed
{
    if(type == NETVALID_All)
        return true;
    if(type == NETVALID_None)
        return false;
    
    return ( ( type == NETVALID_MPOnly ) == 
             ( GC.SwatGameRole == GAMEROLE_MP_Host ||
               GC.SwatGameRole == GAMEROLE_MP_Client ) );
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Spawn the actual equipment from the final loadout spec.  
//      Do not spawn any equipment that has already been created or that cannot be spawned 
//          (such as POCKET_Invalid, the ammunition pockets).
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated protected function SpawnEquipmentFromLoadOutSpec()
{
    local int i;

    for( i = 0; i < Pocket.EnumCount; i++ )
    {
        if( !GC.AvailableEquipmentPockets[i].bSpawnable )
            continue;
            
        SpawnEquipmentForPocket( Pocket(i), LoadOutSpec[i] );
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Spawn a piece of equipment in the given pocket from the final loadout spec.  
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated protected function SpawnEquipmentForPocket( Pocket i, class<actor> EquipmentClass )
{
    //mplog( self$"---LoadOut::SpawnEquipmentForPocket(). Pocket="$i$", class="$EquipmentClass );

    if( PocketEquipment[i] != None )
        PocketEquipment[i].Destroy();

    if( EquipmentClass == None )
        return;
        
    PocketEquipment[i] = Owner.Spawn(EquipmentClass, Owner);
    
    assertWithDescription(PocketEquipment[i] != None,
        "LoadOut "$name$" failed to spawn PocketEquipment item in pocket "$GetEnum(Pocket,i)$" of class "$EquipmentClass$".");

    //mplog( "...Spawned equipment="$PocketEquipment[i] );
    
    if( GC.AvailableEquipmentPockets[i].TypeOfEquipment == EQUIP_Weaponry )
    {
        Assert( GC.AvailableEquipmentPockets[i].DependentPocket != Pocket_Invalid );
        
        switch( i )
        {
            case Pocket_PrimaryWeapon:
                FiredWeapon( PocketEquipment[i] ).SetSlot( EquipmentSlot.Slot_PrimaryWeapon );
                break;
            case Pocket_SecondaryWeapon:
                FiredWeapon( PocketEquipment[i] ).SetSlot( EquipmentSlot.Slot_SecondaryWeapon );
                break;
            default:
                Assert( false );
        }

        FiredWeapon( PocketEquipment[i] ).AmmoClass = class<Ammunition>(LoadOutSpec[GC.AvailableEquipmentPockets[i].DependentPocket]);
    }

    // Set the pocket on the newly spawned item
    if( HandheldEquipment( PocketEquipment[i] ) != None )
        HandheldEquipment( PocketEquipment[i] ).SetPocket( i );
    
    // Trigger notification that this equipment has been spawned for this loadout
    if( Equipment( PocketEquipment[i] ) != None )
        Equipment( PocketEquipment[i] ).OnGivenToOwner();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Add an existing item to the LoadOut - intended for Pickups
// 
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated protected function AddExistingItemToPocket( Pocket i, Actor Item )
{
    if( PocketEquipment[i] != None )
        PocketEquipment[i].Destroy();

    assert(Item != None);
        
    PocketEquipment[i] = Item;
    
    if( GC.AvailableEquipmentPockets[i].TypeOfEquipment == EQUIP_Weaponry )
    {
        Assert( GC.AvailableEquipmentPockets[i].DependentPocket != Pocket_Invalid );
        
        switch( i )
        {
            case Pocket_PrimaryWeapon:
                FiredWeapon( PocketEquipment[i] ).SetSlot( EquipmentSlot.Slot_PrimaryWeapon );
                break;
            case Pocket_SecondaryWeapon:
                FiredWeapon( PocketEquipment[i] ).SetSlot( EquipmentSlot.Slot_SecondaryWeapon );
                break;
            default:
                Assert( false );
        }
    }

    // Set the pocket on the newly spawned item
    if( HandheldEquipment( PocketEquipment[i] ) != None )
        HandheldEquipment( PocketEquipment[i] ).SetPocket( i );
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Log Loadout Utility
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated function PrintLoadOutToMPLog()
{
    local int i;
 
    mplog( "LoadOut "$self$" contains:" );
    log( "LoadOut "$self$" contains:" );

    for ( i = 0; i < Pocket.EnumCount; i++ )
    {
        mplog( "...PocketEquipment["$GetEnum(Pocket,i)$"]="$PocketEquipment[i] );
        log( "...PocketEquipment["$GetEnum(Pocket,i)$"]="$PocketEquipment[i] );
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Accessors
/////////////////////////////////////////////////////////////////////////////////////////////////////

// Returns the first handheld equipment corresponding to the given slot
simulated function HandheldEquipment GetItemAtSlot(EquipmentSlot Slot)
{
    local int i;
    local HandheldEquipment Item;
    local HandheldEquipment Candidate;

    assert(Owner.IsA('ICanUseC2Charge'));
    if( Slot == SLOT_Breaching && ICanUseC2Charge(Owner).GetDeployedC2Charge() != None )
        return GetItemAtSlot( Slot_Detonator );

    for( i = 0; i < Pocket.EnumCount; i++ )
    {
        Item = HandheldEquipment(PocketEquipment[i]);
        if  (
                Item != None
            &&  Item.GetSlot() == Slot
            &&  Item.IsAvailable()
            )
        {
            Candidate = Item;

            //tcohen, fix 5480: Can never equip second PepperSpray
            //  this is the only case of LoadOut containing more than one instance
            //of any FiredWeapon class.  if one has empty ammo and another does not,
            //then we want to select the one that is not empty, regardless of order.
            if (!Candidate.IsA('FiredWeapon') || !FiredWeapon(Candidate).Ammo.IsEmpty())
                return Item;
            //else, Candidate IsA 'FiredWeapon' && Candidate's Ammo IsEmpty()
                //continue looking for an instance that isn't empty
        }
    }
    
    if (Level.NetMode != NM_Standalone ) // ckline: this was bogging down SP performance
    {
	 	if (Level.GetEngine().EnableDevTools)
		{
			mplog( self$"---LoadOut::GetItemAtSlot(). Slot="$Slot );
			mplog( "...Returning None because no item was found for that slot." );
			PrintLoadOutToMPLog();
        }
    }

    //if we never found a match, or if we only found an empty FiredWeapon, the return that
    return Candidate;
}

// Returns the contents of the given pocket
simulated function Actor GetItemAtPocket( Pocket ThePocket )
{
    assert(ThePocket != Pocket_Invalid);

    return PocketEquipment[ThePocket];
}

simulated function FiredWeapon GetPrimaryWeapon()
{
    return FiredWeapon(PocketEquipment[Pocket.Pocket_PrimaryWeapon]);
}

simulated function FiredWeapon GetBackupWeapon()
{
    return FiredWeapon(PocketEquipment[Pocket.Pocket_SecondaryWeapon]);
}

simulated function Material GetMaterial( MaterialPocket pock )
{
    return MaterialSpec[pock];
}


simulated function Material GetNameMaterial()
{
    return MaterialSpec[MaterialPocket.MATERIAL_Name];
}

simulated function Material GetFaceMaterial()
{
    return MaterialSpec[MaterialPocket.MATERIAL_Face];
}

simulated function Material GetVestMaterial()
{
    if ( HasHeavyArmor() )
        return MaterialSpec[MaterialPocket.MATERIAL_HeavyVest];
    else
        return MaterialSpec[MaterialPocket.MATERIAL_Vest];
}

simulated function Material GetPantsMaterial()
{
    if ( HasHeavyArmor() )
        return MaterialSpec[MaterialPocket.MATERIAL_HeavyPants];
    else
        return MaterialSpec[MaterialPocket.MATERIAL_Pants];
}

simulated function bool HasHeavyArmor()
{
    if ( PocketEquipment[Pocket.Pocket_BodyArmor] != None )
        return PocketEquipment[Pocket.Pocket_BodyArmor].IsA('HeavyBodyArmor');
    else
        return false; // The VIP has no armor in Pocket_BodyArmor.
}

//returns the item, if any, that was replaced
function HandheldEquipment FindItemToReplace(HandheldEquipment PickedUp)
{
    local int i;

    for( i = 0; i < Pocket.EnumCount; i++ )
        if( ValidateEquipmentForPocket( Pocket(i), PickedUp.class ) )
            return HandheldEquipment(PocketEquipment[i]);

    AssertWithDescription(false,
        "[tcohen] LoadOut::FindItemToReplace() The PickedUp class "$PickedUp.class.name
        $" failed to validate for any Pocket.");
}

simulated function OnPickedUp(HandheldEquipment Item)
{
    AddExistingItemToPocket(FindItemToReplace(Item).GetPocket(), Item);
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Destroyed, Clean up all spawned equipment
/////////////////////////////////////////////////////////////////////////////////////////////////////
simulated event Destroyed()
{
    local int i;

    Super.Destroyed();

    for( i = 0; i < Pocket.EnumCount; i++ )
        if( PocketEquipment[i] != None )
            PocketEquipment[i].Destroy();
}

/////////////////////////////////////////////////////////////////////////////////////////////////////
// cpptext
/////////////////////////////////////////////////////////////////////////////////////////////////////
cpptext
{
    UBOOL HasA(FName HandheldEquipmentName);
}


/////////////////////////////////////////////////////////////////////////////////////////////////////
// DefProps
/////////////////////////////////////////////////////////////////////////////////////////////////////
defaultproperties
{
    Physics=PHYS_None
    bStasis=true
    bHidden=true
	bDisableTick=true
    RemoteRole=ROLE_None
}
