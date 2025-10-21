using LunyScratch;
using UnrealSharp.Attributes;
using UnrealSharp.CoreUObject;
using UnrealSharp.Engine;
using UnrealSharp.InputCore;
using static LunyScratch.Blocks;

namespace ManagedScratchTest10
{
	[UClass]
	public class APoliceCarScratch : AScratchPawn
	{
		private Single _turnSpeed = 70f;
		private Single _moveSpeed = 16f;
		private Single _deceleration = 0.85f;
		private Int32 _startTimeInSeconds = 5;

		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Single TurnSpeed { get => _turnSpeed; set => _turnSpeed = value; }
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Single MoveSpeed { get => _moveSpeed; set => _moveSpeed = value; }
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Single Deceleration { get => _deceleration; set => _deceleration = value; }
		[UProperty(PropertyFlags.BlueprintReadWrite)]
		public Int32 StartTimeInSeconds { get => _startTimeInSeconds; set => _startTimeInSeconds = value; }

		protected override void OnScratchReady()
		{
			var progressVar = GlobalVariables["Progress"];
			var scoreVariable = Variables.Set("Score", 0);
			var timeVariable = Variables.Set("Time", _startTimeInSeconds);

			// Handle UI State
			// HUD.BindVariable(scoreVariable);
			// HUD.BindVariable(timeVariable);

			//Run(HideMenu(), ShowHUD());
			//RepeatForever(If(IsKeyJustPressed(Key.Escape), ShowMenu()));

			// must run globally because we Disable() the car and thus all object sequences will stop updating
			// Scratch.When(ButtonClicked("TryAgain"), ReloadCurrentScene());
			// Scratch.When(ButtonClicked("Quit"), QuitApplication());

			// tick down time, and eventually game over
			// RepeatForever(Wait(1), DecrementVariable("Time"),
			// 	If(IsVariableLessOrEqual(timeVariable, 0),
			// 		ShowMenu(), SetCameraTrackingTarget(null), Wait(0.5), DisableComponent()));

			// Use RepeatForeverPhysics for physics-based movement
			var enableBrakeLights = Sequence(Enable("BrakeLight1"), Enable("BrakeLight2"));
			var disableBrakeLights = Sequence(Disable("BrakeLight1"), Disable("BrakeLight2"));
			// RepeatForeverPhysics(
			// 	// Forward/Backward movement
			// 	If(IsKeyPressed(Key.W),
			// 			MoveForward(_moveSpeed), disableBrakeLights)
			// 		.Else(If(IsKeyPressed(Key.S),
			// 				MoveBackward(_moveSpeed), enableBrakeLights)
			// 			.Else(SlowDownMoving(_deceleration), disableBrakeLights)
			// 		),
			//
			// 	// Steering
			// 	If(IsCurrentSpeedGreater(0.1),
			// 		If(IsKeyPressed(Key.A), TurnLeft(_turnSpeed)),
			// 		If(IsKeyPressed(Key.D), TurnRight(_turnSpeed)))
			// );

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

		public override void Tick(Single deltaTime)
		{
			base.Tick(deltaTime);

			var keyW = new FKey { KeyName = "W" };
			var keyA = new FKey { KeyName = "A" };
			var keyS = new FKey { KeyName = "S" };
			var keyD = new FKey { KeyName = "D" };

			var  inputMove = FVector.Zero;
			var  inputTurn = FVector.Zero;

			var root = RootComponent as UPrimitiveComponent;
			var playerController = UGameplayStatics.GetPlayerController(0);
			if (playerController.IsInputKeyDown(keyW))
				inputMove += root.ForwardVector;
			if (playerController.IsInputKeyDown(keyS))
				 inputMove -= root.ForwardVector;
			if (playerController.IsInputKeyDown(keyA))
				inputTurn -= FVector.Up;
			if (playerController.IsInputKeyDown(keyD))
				inputTurn += FVector.Up;

			// var move = GetComponentByClass<UCharacterMovementComponent>();
			// move.AddForce(inputVector * _moveSpeed * 1000);

			//var prim = root.GetChildComponent(0) as UPrimitiveComponent;
			root.AddForce( inputMove * _moveSpeed * 1000000);
			root.AddTorqueInDegrees( inputTurn * _turnSpeed * 100000000);
			//root.AddRelativeLocation(inputVector * _moveSpeed, false, out var _, false);

		}
	}
}
