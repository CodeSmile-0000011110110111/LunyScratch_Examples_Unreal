# LunyScratch Core Guidelines

Purpose
- This document summarizes conventions and patterns used by the LunyScratch API to keep the Core framework engine-agnostic and consistent across Unity, Godot, and Unreal (via UnrealSharp). Use it when adding new blocks/APIs or writing example scripts.

Key Principles
- Engine-agnostic Core: Anything not engine-specific must live in the Core layer. Only thin integration layers may reference engine SDKs (Unity, Godot, Unreal).
- Core classes wrapping internal logic should be marked internal. Internals are visible to Engine-specific implementation assembly. Examples: BlockRunner, GameEngine, NullScratchContext.
- Context-driven access: Blocks obtain engine objects via IScratchContext. Callers never pass engine references.
- Simple-by-default API: Public API favors simple static methods returning IScratchBlock. Power users may get optional lambda overloads.
- Public API methods should use Double instead of Single types so that users needn't specify the 'f' in values like '1.234'.
- Composition-first: Scripts compose behavior from small, single-purpose blocks.
- Safety and clarity: Prefer sealed, private block implementations, no side caches in blocks; context manages caching.
- Objects only query themselves and their children / child components, never parents or siblings.

Developer Usage (scripts)
- Always import blocks with: using static LunyScratch.Blocks;
- Compose behavior from blocks inside a ScratchBehaviour-derived component (or other IScratchRunner host).
- Prefer engine-agnostic blocks; Core provides context-aware helpers (Enable/Disable by name, motion via IRigidbody, etc.).

Example (Unity, see PoliceCarScratch.cs)
- Input-driven physics loop and lights using context-aware blocks:
  RepeatForeverPhysics(
  If(IsKeyPressed(Key.W), MoveForward(_moveSpeed))
  .Else(If(IsKeyPressed(Key.S), MoveBackward(_moveSpeed))
  .Else(SlowDownMoving(_deceleration))),
  If(IsKeyPressed(Key.A), TurnLeft(_turnSpeed)),
  If(IsKeyPressed(Key.D), TurnRight(_turnSpeed))
  );
  RepeatForever(
  Enable("BlueLight"), Disable("RedLight"), Wait(0.15),
  Disable("BlueLight"), Enable("RedLight"), Wait(0.12)
  );

Public API Design (Core)
- Namespace: LunyScratch
- Class: public static partial class Blocks (split per domain: Blocks.Motion.cs, Blocks.Control.cs, Blocks.Input.cs, etc.).
- Public surface returns IScratchBlock for composability:
  public static IScratchBlock MoveForward(Single speed);
  public static IfBlock If(Func<Boolean> condition, params IScratchBlock[] blocks);
  public static IScratchBlock RepeatForever(params IScratchBlock[] blocks);
- Optional lambda overloads for power users:
  public static IScratchBlock RepeatForever(Action block) => RepeatForever(new ExecuteBlock(block));
  // Provide lambda forms only where it improves ergonomics; default to IScratchBlock variants.
- Do not require engine references in method parameters. Acquire them via IScratchContext inside block implementations.

Block Implementation Pattern
- Visibility & type: private sealed class <Name>Block : IScratchBlock inside Blocks.* file that declares the public factory method.
- Construction: Store simple immutable parameters (e.g., speed, names). No engine objects.
- Execution:
  void Run(IScratchContext context, Double deltaTimeInSeconds)
  {
  var rb = context?.GetRigidbody();
  if (rb == null) return;
  // perform action using abstractions (IRigidbody/ITransform/IEngineObject)
  }
  Boolean IsComplete() => true; // for instantaneous blocks
- Context access only through IScratchContext:
    - Rigidbody: context.GetRigidbody() -> IRigidbody
    - Transform: context.GetTransform() -> ITransform
    - Find child by name: context.FindChild(string) -> IEngineObject
    - Timing comes from BlockRunner via deltaTimeInSeconds; do not query engine time directly.
- Caching: Do not cache engine objects in the block. Context is responsible for caching/lookups.

Control/Flow Blocks
- Wait(Double seconds): time-based pause handled by BlockRunner.
- If/Else and loop blocks return composable types:
    - If(Func<Boolean> or ConditionBlock, params IScratchBlock[] thenBlocks)
    - IfBlock supports .Else(params IScratchBlock[] elseBlocks)
    - RepeatForever / RepeatWhileTrue / RepeatUntilTrue support both Func<Boolean> and ConditionBlock forms.

Input Blocks
- Expose input queries as ConditionBlock or Func<Boolean> delegates, e.g. IsKeyPressed(Key key).
- Input blocks/conditions must be engine-agnostic; Unity/Godot/Unreal implementations live behind the Core abstraction and the engine context.

Motion/Transform Blocks
- Work exclusively via IRigidbody and/or ITransform from the context.
- Examples: MoveForward, MoveBackward, TurnLeft/Right, StopMoving/Turning, SlowDownMoving/Turning.
- Use SI-friendly naming and units stated in XML docs and tooltips. E.g., angles per second in degrees where indicated; convert to radians for IRigidbody as needed.

Enable/Disable and Object Access
- Two overload families:
    - Direct object (engine-agnostic abstraction): Enable(IEngineObject obj) / Disable(IEngineObject obj)
    - Context-aware by name: Enable(string childName) / Disable(string childName)
- All object operations use IEngineObject/IEngineComponent abstractions.

Coding Conventions
- Files
    - One feature area per Blocks.<Area>.cs file (partial Blocks).
- Naming
    - Public factory methods: PascalCase verbs (MoveForward, TurnLeft, Wait, Enable). Verify public factory methods are not semantically identical with public methods exposed by Unity MonoBehaviour, Godot Node, Unreal AActor, UActorComponent, USceneComponent, UPrimitiveComponent classes.
    - Private block classes: <Verb>NounBlock, sealed.
    - Interfaces: I-prefix (IScratchBlock, IScratchContext, IRigidbody, ITransform, IEngineObject).
    - Fields: private readonly/protected use _camelCase with leading underscore.
- Types & .NET
    - Use System primitives with explicit aliases (Single, Double, Boolean, String) in Core for consistency across engines.
    - Avoid engine structs in Core. Use Core abstractions (vectors, quaternions) via interfaces, or map engine types inside engine adapters.
- API Style
    - Public API methods are pure factories; no side effects beyond returning IScratchBlock.
    - Prefer params IScratchBlock[] for composition.
    - Provide optional overloads accepting Action or Func where ergonomic.
- Comments & Docs
    - XML docs summarize behavior, units, and expectations (e.g., degrees per second).
    - Document that blocks are context-aware and should not cache engine objects.

Code Organization
- Core (engine-agnostic):
  Packages/de.codesmile.lunyscratch_unity/Runtime/Core/
    - Blocks/ (Control, Motion, Input, Looks, Sound, etc.)
    - Engine/ (IEngineObject, IRigidbody, ITransform, IEngineComponent, etc.)
    - Runtime primitives, runners (BlockRunner, SequenceBlock, RepeatForeverBlock, IfBlock, ConditionBlock, etc.)
  - Keep block implementation classes in separate files in subfolder matching their factory method. Example: Blocks/Motion/Blocks.Motion.cs => Blocks/Motion/MoveForwardBlock.cs etc
- Engine Integrations:
  Packages/de.codesmile.lunyscratch_unity/Runtime/Unity/
    - UnityGameObjectContext, Unity types (UnityTransform, UnityGameObject), ScratchBehaviour host, ScratchRuntime, adapters.
      Godot/Unreal: analogous contexts and adapters in their respective packages.
- Examples and game code live under project Assets (Unity) or corresponding engine project folders, referencing only the public Core API.

ScratchBehaviour & Runners (Unity example)
- ScratchBehaviour constructs UnityGameObjectContext and BlockRunner; forwards Update/FixedUpdate to ProcessUpdate/ProcessPhysicsUpdate.
- IScratchRunner methods for convenience:
    - Run/RunPhysics(params IScratchBlock[])
    - RepeatForever/RepeatForeverPhysics(params IScratchBlock[])
    - RepeatWhileTrue / RepeatUntilTrue with Func<Boolean> conditions
- Derive from ScratchBehaviour and override OnBehaviourAwake()/OnBehaviourDestroy() instead of Awake/OnDestroy.

Extending the API
- Add a new block factory to the appropriate Blocks.<Area>.cs file.
- Implement a private sealed IScratchBlock class inside the same file.
- Use IScratchContext to access engine abstractions; never pass engine objects through public Core APIs.
- Provide a lambda overload only if it significantly improves ergonomics and composes with existing patterns.
- Include XML docs and unit/usage examples (where applicable) in example projects.

Compatibility Expectations
- Unity, Godot, Unreal should require zero code changes in Core; only context/adapters differ.
- Scripts in all engines should be able to: using static LunyScratch.Blocks; and compose blocks identically.

Checklist for New Blocks
- [ ] Lives in Core under the correct Blocks.* file (partial Blocks).
- [ ] Public factory returns IScratchBlock (or specialized control type like IfBlock).
- [ ] No engine references in public API.
- [ ] Implementation accesses engine via IScratchContext.
- [ ] Sealed private class, no caching of engine objects.
- [ ] Units and behavior documented.
- [ ] Optional lambda overload provided only if valuable.

---

Addendum: Variable Blocks, Table, and Logging Updates

Context
- The Core now exposes a weakly-typed Variable struct and a Table container (array + dictionary hybrid) for script variables. Variable blocks compose through the public Blocks API and delegate creation/type logic to Table.

Public API (Core)
- Namespace: LunyScratch
- Class: public static partial class Blocks (file: Runtime/Core/Blocks/Variable/Blocks.Variable.cs)
- Factory methods:
  - IScratchBlock SetVariable(String name, Variable value)
  - IScratchBlock IncrementVariable(String name) // increments by +1
  - IScratchBlock IncrementVariable(String name, Variable value)
  - IScratchBlock ChangeVariable(String name, Variable initialValue, Double changeValue)

Behavior
- SetVariable: sets the named variable to the provided value. If the variable does not exist, it is created. The variable’s type changes to match the assigned value.
- IncrementVariable: delegates to Table.Increment(name, amount). Table creates the variable if missing (initialized to 0) and performs numeric checks/warnings internally.
- ChangeVariable: delegates to Table.Change(name, initialValue, delta). Table creates the variable if missing and performs numeric checks/warnings internally.

Implementation Pattern
- Private sealed classes per block under Runtime/Core/Blocks/Variable:
  - SetVariableBlock.cs
  - IncrementVariableBlock.cs
  - ChangeVariableBlock.cs
- Each implements IScratchBlock and performs logic in Run(IScratchContext context, Double deltaTimeInSeconds).
- Access variables via context.Runner.Variables (Table).
- Warnings/errors are logged through GameEngine.Actions logging API (see below).

Table
- Hybrid array + dictionary container. Provides Get/Set for array (1-indexed) and dictionary keys.
- Dictionary Set(String key, Variable value) lazily creates the key if it does not exist.
- Increment(String key, Variable amount): Creates the variable if missing (initialized to 0). If the current value is non-numeric (e.g., String), emits a warning and does not change the value.
- Change(String key, Variable initialValue, Double delta): If missing, initializes from initialValue; for strings, warns and does not change numerically.
- ToString(): returns "Table(arr=<arrayCount>, dict=<dictCount>)".

Variable
- Weakly typed value wrapper supporting Boolean, Number, String.
- Properties and conversions:
  - Type (ValueType enum)
  - IsNumeric / IsBoolean / IsString
  - AsNumber / AsString / AsBoolean
  - Set(Double/Boolean/String)
  - Increment(Double) and Increment(Variable)
- Operators:
  - Arithmetic: +, -, *, /, % (numeric-only; no-ops if incompatible)
  - Unary + and - (numeric-only for -)
  - Equality: == and != (numeric compare for numeric types; ordinal for strings)
  - Implicit conversions from Int32, Single, Double, Boolean, String to Variable
- Equality support:
  - IEquatable<Variable>, IEquatable<Int32>, IEquatable<Single>, IEquatable<Double>, IEquatable<Boolean>, IEquatable<String>
- ToString(): returns e.g., "Number(3.14)", "String(hello)", "Boolean(True)".

Logging API (Engine Actions)
- IEngineActions exposes severity-specific methods:
  - void LogInfo(String message)
  - void LogWarn(String message)
  - void LogError(String message)
- Unity implementation maps to UnityEngine.Debug.Log/LogWarning/LogError.
- All diagnostics and Table/Variable warnings should use the appropriate severity method (do not prefix message text with [WARN]/[ERROR]).

Coding Conventions (recap for Variable blocks)
- Public factories live in partial Blocks class; implementations are sealed classes in the same feature folder.
- Public API uses System primitives (Double, Boolean, String) and returns IScratchBlock for composability.
- No engine SDK types in Core; blocks interact with engine only via IScratchContext.

File Locations
- Core blocks and primitives live under: Packages/de.codesmile.lunyscratch_unity/Runtime/Core/
  - Blocks/Variable/Blocks.Variable.cs
  - Blocks/Variable/SetVariableBlock.cs
  - Blocks/Variable/IncrementVariableBlock.cs
  - Blocks/Variable/ChangeVariableBlock.cs
  - Variable.cs, Table.cs
- Engine-specific logging and contexts live under: Packages/de.codesmile.lunyscratch_unity/Runtime/Unity/

Usage Example
- When(CollisionEnter(tag:"CompanionCube"),
    Say("Police collided with cube!"),
    IncrementVariable("Score"));



# LunyScratch Core – Local Guidelines Update (2025-10-14)

Ambient execution context is forbidden
- Do not use any ambient/thread-static execution context (e.g., ScratchExecution.CurrentContext) to access IScratchContext.
- All blocks must receive IScratchContext only through method parameters provided by the runner (Run/OnEnter/OnExit) or through delegates that accept IScratchContext.

Condition and flow evaluation
- Condition blocks must be implemented as dedicated IScratchBlock classes (do not inline new ConditionBlock(...) in public factories). Provide private sealed classes per condition for better debugging. 
- Execute blocks must also be implemented as dedicated IScratchBlock classes (avoid new ExecuteBlock(...) in public factories); expose factory methods returning IScratchBlock.
- Conditions that need context must evaluate during Run using the provided IScratchContext. Avoid any global state.
- If/Else branching must evaluate conditions when IScratchContext is available (during Run), not in OnEnter without context.

Coding style for conditions
- Do not write single-line condition lambdas. Prefer multi-line blocks for clarity and easier breakpointing.
- Keep comparisons explicit (no ternary or expression-bodied lambdas for non-trivial checks).

General
- Keep Core engine-agnostic and free of engine SDK types.
- Prefer explicit Double/Boolean/String types in public APIs.
- Do not cache engine objects inside blocks; use IScratchContext for lookups/caching.
