class LessLethalSG extends Shotgun
    config(SwatEquipment);

// Copied from StingGrenadeProjectile to allow a designer to mess with these values...
//damage - Damage should be applied constantly over DamageRadius
var config float Damage;
var config float DamageRadius;

//karma impulse - Karma impulse should be applied linearly from KarmaImpulse.Max to KarmaImpulse.Min over KarmaImpulseRadius
var config Object.Range KarmaImpulse;
var config float KarmaImpulseRadius;

//Sting
var config float StingRadius;
var config float PlayerStingDuration;
var config float HeavilyArmoredPlayerStingDuration;
var config float AIStingDuration;
var config float MoraleModifier;

simulated function DealDamage(Actor Victim, int Damage, Pawn Instigator, Vector HitLocation, Vector MomentumVector, class<DamageType> DamageType )
{
    // Don't deal damage for pawns, instead make them effected by the sting grenade
    if ( Victim.IsA( 'Pawn' ) )
    {
        IReactToStingGrenade(Victim).ReactToStingGrenade(
			None,  // when the grenade arg is None, the effect knows that it's
			// the less lethal shotgun (vs. the Sting grenade)
			Pawn(owner),
			0, 
			DamageRadius, 
			KarmaImpulse, 
			KarmaImpulseRadius, 
			StingRadius, 
			PlayerStingDuration, 
			HeavilyArmoredPlayerStingDuration, 
			AIStingDuration, 
			MoraleModifier);

        mplog("Called ReactToStingGrenade on: "$Victim );
    } 
    // Otherwise deal damage, cept for ExplodingStaticMesh that is....
    else if ( !Victim.IsA('ExplodingStaticMesh') )
    {
        Super.DealDamage( Victim, Damage, Instigator, HitLocation, MomentumVector, DamageType );
    }
}

// Less-lethal should never spawn blood effects
simulated function bool  ShouldSpawnBloodForVictim( Pawn PawnVictim, int Damage )
{
    return false;
}
    
    
defaultproperties
{
    Slot=Slot_Invalid
}
