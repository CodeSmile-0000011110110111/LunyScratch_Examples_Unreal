using LunyScratch;
using UnrealSharp.Attributes;
using static LunyScratch.Blocks;

namespace ManagedLunyScratch_Examples
{
	[UClass]
	public class AHitEffectScratch : AScratchActor
	{
		private Double _timeToLiveInSeconds = 3;
		private Double _minVelocityForSound = 3;

		protected override void OnScratchReady()
		{
			Run(Wait(_timeToLiveInSeconds), DestroySelf());

			var globalTimeout = GlobalVariables["MiniCubeSoundTimeout"];
			When(CollisionEnter(),
				If(AND(IsVariableLessThan(globalTimeout, 0), IsCurrentSpeedGreater(_minVelocityForSound)),
					PlaySound(), SetVariable(globalTimeout, 0)));
		}
	}
}
