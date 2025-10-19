using LunyScratch;
using UnrealSharp.Attributes;
using static LunyScratch.Blocks;

namespace ManagedScratchTest10
{
	[UClass]
	public class APoliceCarScratch : AScratchActor
	{
		protected override void OnComponentReady()
		{
			ActorTickEnabled = true;
			//_car = GetComponentByClass<UPrimitiveComponent>();

			// blinking signal lights
			RepeatForever(
				Enable("RedLight"),
				Wait(0.16),
				Disable("RedLight"),
				Wait(0.12)
			);
			RepeatForever(
				Disable("BlueLight"),
				Wait(0.13),
				Enable("BlueLight"),
				Wait(0.17)
			);
		}
	}
}
