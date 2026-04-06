# GitHub Copilot Instructions for Nha Cua Toi AIoT Project

You are an expert Senior Flutter Engineer. Follow these instructions strictly to keep architecture and implementation consistent.

## 1. Tech Stack and Architecture

- Framework: Flutter (latest stable).
- State management strategy:
  - Use BLoC/Cubit for screen/module business logic and side-effect flows.
  - Use Riverpod for dependency injection and lightweight global state.
- Architecture style: pragmatic Clean Architecture (incremental adoption).
  - Current layout is hybrid and evolving. Respect current structure while moving new code toward cleaner boundaries.
- Real-time communication: `mqtt_client` package through centralized manager and BLoC orchestration.

## 2. Non-Negotiable Architecture Rules

- Do not place API/MQTT/database business logic in UI widgets.
- Do not call REST APIs directly from Riverpod providers in this project.
- Repositories are the only layer allowed to access data sources.
- BLoC handles event-to-state business workflows.
- Riverpod handles lightweight UI/global state and simple persisted UI state.

## 3. BLoC and Riverpod Integration Rules

- Inject repositories/use cases into BLoC via Riverpod or app-level composition.
- Preferred wiring pattern for new code:
  - `final myBloc = MyBloc(repository: ref.read(myRepositoryProvider));`
- Existing app-level BLoCs created in `main.dart` must remain stable unless explicitly refactored.
- When combining both tools in one screen:
  - BLoC owns business data and side effects.
  - Riverpod owns UI helper state and lightweight persistence.

## 4. Coding Standards (Senior Level)

- Immutability:
  - New BLoC events/states should use `@freezed`.
  - Existing `Equatable` modules can remain until planned migration.
- Error handling:
  - Prefer functional return types such as `Either<Failure, Success>` (`dartz` or `fpdart`) at domain/repository boundaries.
- Naming conventions:
  - Events: `[Noun/Verb] + [Requested/Started/Updated]`.
  - States: `[Noun] + [Initial/LoadInProgress/LoadSuccess/LoadFailure]`.
- Concurrency:
  - Handle MQTT and stream-heavy flows with clear event sequencing.
  - Prevent race conditions and duplicate in-flight operations.

## 5. MQTT and Real-Time Requirements

- MQTT client ownership:
  - Use centralized singleton manager (`MQTTManager.instance`) with app-scope lifecycle.
- Reconnection:
  - Implement and preserve exponential backoff.
  - Avoid multiple parallel reconnect loops.
- Parsing:
  - Parse payloads into typed models before emitting BLoC states.
- Resource management:
  - Cancel every `StreamSubscription` in BLoC `close()`.

## 6. UI and Performance Requirements

- Refactor large widgets into smaller components.
- Prefer `const` constructors where possible.
- For real-time and high-frequency states:
  - Use `BlocBuilder` with `buildWhen`.
  - Use `BlocListener` with `listenWhen` when appropriate.
  - Avoid unnecessary rebuilds and expensive widget work in builders.

## 7. Security and Configuration

- Never hardcode broker or API credentials.
- Use `.env` and central config accessors.
- Keep sensitive keys and tokens out of logs where possible.

## 8. Testing Requirements

- Add or update tests for new behavior:
  - Unit tests for BLoC transitions and business logic.
  - Provider tests for Riverpod-based state.
- Mock MQTT streams and external dependencies using `mockito` or `mocktail`.

## 9. Implementation Guidance for New Code

When adding a feature:
1. Classify state ownership first (BLoC vs Riverpod).
2. Add/extend models with explicit parsing.
3. Add repository methods before UI integration.
4. Add BLoC events/states/handlers with predictable transitions.
5. Add tests for both success and failure paths.
6. Validate that no UI layer contains business logic.

## 10. Migration Guidance

- Maintain existing stable flows unless a change is requested.
- Introduce `freezed` and `Either` in new modules first.
- Migrate legacy modules gradually to reduce risk.

---

Note:
When I request new code, always follow these instructions to preserve long-term architecture consistency.