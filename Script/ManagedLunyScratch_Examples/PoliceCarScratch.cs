using LunyScratch;
using UnrealSharp.Attributes;
using UnrealSharp.CoreUObject;
using static LunyScratch.Blocks;

namespace ManagedScratchTest10
{
	[UClass]
	public class APoliceCarScratch : AScratchPawn
	{
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Single TurnSpeed { get; set; }
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Single MoveSpeed { get; set; }
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Single Deceleration { get; set; }
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Int32 StartTimeInSeconds { get; set; }

		protected override void OnScratchReady()
		{
			PrintString("PoliceCarScratch.OnScratchReady()", color: FLinearColor.Red);

			var progressVar = GlobalVariables["Progress"];
			var scoreVariable = Variables.Set("Score", 0);
			var timeVariable = Variables.Set("Time", StartTimeInSeconds);

			// Handle UI State
			HUD.BindVariable(scoreVariable);
			HUD.BindVariable(timeVariable);

			Run(HideMenu(), ShowHUD());
			RepeatForever(If(IsKeyJustPressed(Key.Escape), ShowMenu()));

			// must run globally because we Disable() the car and thus all object sequences will stop updating
			Scratch.When(ButtonClicked("TryAgain"), Log("clicked TryAgain"), ReloadCurrentScene());
			Scratch.When(ButtonClicked("Quit"), Log("clicked Quit"), QuitApplication());

			// tick down time, and eventually game over
			RepeatForever(Wait(1), DecrementVariable("Time"),
				If(IsVariableLessOrEqual(timeVariable, 0),
					ShowMenu(), SetCameraTrackingTarget(), Wait(0.5), DisableComponent()));

			// Use RepeatForeverPhysics for physics-based movement
			var enableBrakeLights = Sequence(Enable("BrakeLight1"), Enable("BrakeLight2"));
			var disableBrakeLights = Sequence(Disable("BrakeLight1"), Disable("BrakeLight2"));
			RepeatForeverPhysics(
				// Forward/Backward movement
				If(IsKeyPressed(Key.W),
						MoveForward(MoveSpeed), disableBrakeLights)
					.Else(If(IsKeyPressed(Key.S),
							MoveBackward(MoveSpeed), enableBrakeLights)
						.Else(SlowDownMoving(Deceleration), disableBrakeLights)
					),

				// Steering
				If(IsCurrentSpeedGreater(500),
					If(IsKeyPressed(Key.A), TurnLeft(TurnSpeed)),
					If(IsKeyPressed(Key.D), TurnRight(TurnSpeed)))
			);

			// add score and time on ball collision
			When(CollisionEnter(tag: "CompanionCube"),
				IncrementVariable("Time"),
				// add 'power of three' times the progress to score
				SetVariable(Variables["temp"], progressVar),
				MultiplyVariable(Variables["temp"], progressVar),
				MultiplyVariable(Variables["temp"], progressVar),
				AddVariable(scoreVariable, Variables["temp"]));

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

			// Helpers
			// don't play minicube sound too often
			RepeatForever(DecrementVariable(GlobalVariables["MiniCubeSoundTimeout"]));
			// increment progress every so often
			RepeatForever(IncrementVariable(progressVar), Wait(15), PlaySound());
		}
	}
}
