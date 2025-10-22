using LunyScratch;
using UnrealSharp.Attributes;
using static LunyScratch.Blocks;

namespace ManagedLunyScratch_Examples
{
	[UClass]
	public class AHitEffectScratch : AScratchStaticMeshActor
	{
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Double TimeToLiveInSeconds { get; set; } = 3;
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Double MinVelocityForSound { get; set; } = 3;

		protected override void OnScratchReady()
		{
			Run(Wait(TimeToLiveInSeconds), DestroySelf());

			var globalTimeout = GlobalVariables["MiniCubeSoundTimeout"];
			When(CollisionEnter(),
				If(AND(IsVariableLessThan(globalTimeout, 0), IsCurrentSpeedGreater(MinVelocityForSound)),
					PlaySound(), SetVariable(globalTimeout, 0)));
		}
	}
}
