///////////////////////////////////////////////////////////////////////////////
// AnimatorIdleAction.uc - AnimatorIdleAction class
// Action class that uses animator driven data to play an animation when Idling

class AnimatorIdleAction extends BaseIdleAction;
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
//
// AnimatorIdleAction variables

var private name AnimationName;
var private int NumTimesPlayed;
var private int NumTimesToPlay;

///////////////////////////////////////////////////////////////////////////////
//
// Selection Heuristic Query

// returns true because the animator idles don't require any resources
// they just happen all of the time
function bool AreResourcesAvailableToIdle(AI_Goal goal)
{
	return true;
}

///////////////////////////////////////////////////////////////////////////////
//
// Initialization

function initAction(AI_Resource r, AI_Goal goal)
{
    super.initAction(r, goal);

//	log(Name $ " initAction");
	NumTimesToPlay = AnimatorIdleDefinition(OurIdleDefinition).GetRandomNumberOfTimeToPlay();

	PlayIdleAnimation();
}

///////////////////////////////////////////////////////////////////////////////
//
// State Code

function PlayIdleAnimation()
{
    // Play the animation and wait for it to finish
    AnimationName = AnimatorIdleDefinition(OurIdleDefinition).AnimationName;
	ISwatAI(m_Pawn).AnimSetIdle(AnimationName, AnimatorIdleDefinition(OurIdleDefinition).AnimationTweenTime);    

	++NumTimesPlayed;

//	if (m_Pawn.logTyrion)
//		log(Name $ " - play idle animation " $ AnimationName $ " on: " $ m_Pawn.Name);
//		log("OurIdleDefinition: " $ OurIdleDefinition $ " OurIdleDefinition.Name is: " $ OurIdleDefinition.Name);
}

state Running
{
Begin:
    assert(m_Pawn != None);
    assert(OurIdleDefinition.IsA('AnimatorIdleDefinition'));

	m_Pawn.FinishAnim();

	// if we haven't played the specified number of times, play it again
	// or if we're not relevant, just keep idling using what we have
	if ((NumTimesPlayed < NumTimesToPlay) || !ISwatAI(m_Pawn).IsRelevantToPlayerOrOfficers())
	{
		PlayIdleAnimation();
		goto('Begin');
	}

	succeed();
}

///////////////////////////////////////////////////////////////////////////////
defaultproperties
{
}