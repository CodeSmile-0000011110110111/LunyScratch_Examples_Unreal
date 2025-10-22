using LunyScratch;
using UnrealSharp.Attributes;
using static LunyScratch.Blocks;

namespace ManagedLunyScratch_Examples
{
	[UClass]
	public class ACompanionCubeScratch : AScratchStaticMeshActor
	{
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Single MinVelocityForSound { get; set; } = 5f;

		protected override void OnScratchReady()
		{
			var progressVar = GlobalVariables["Progress"];
			var counterVar = Variables["Counter"];

			// increment counter to be able to hit the ball again
			RepeatForever(AddVariable(counterVar, 5), Wait(1));

			Run(Disable("Lights"));

			When(CollisionEnter(tag: "Police"),
				// play bump sound unconditionally and make cube glow
				PlaySound(),
				Enable("Lights"),
				// count down from current progress value to spawn more cube instances the longer the game progresses
				RepeatWhileTrue(() =>
				{
					if (counterVar.Number > progressVar.Number)
						counterVar.Set(Math.Clamp(progressVar.Number, 1, 50));
					counterVar.Subtract(1);
					return counterVar.Number >= 0;
				}, CreateInstance("Prefabs/HitEffect")),
				Wait(1),
				Disable("Lights"));

			// play sound when ball bumps into anything
			When(CollisionEnter(),
				If(IsCurrentSpeedGreater(MinVelocityForSound),
					PlaySound()));
		}
	}
}
