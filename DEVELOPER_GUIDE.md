# Data Monitoring Platform - Developer Guide (Architecture and Basic Logic)

This guide reflects the current codebase and defines the target standards for new development.

## 1. Architecture Overview

The project uses a hybrid architecture:
- BLoC/Cubit for business workflows with side effects (API, MQTT, SQLite, pagination, multi-step flows).
- Riverpod for lightweight global UI state, cross-screen helper state, and simple persistence state.
- Repository Pattern as the single gateway for external data sources.

High-level flow:

```text
Screens/Widgets
   |  add events / watch states
   v
BLoC Layer
   |  call repositories
   v
Repository Layer
   |-- REST API
   |-- MQTT manager (singleton)
   '-- Local storage (SQLite / preferences)

Riverpod Layer (parallel to BLoC)
   |-- global UI state
   '-- lightweight persisted state
```

Core rules:
- UI must not contain business logic.
- BLoC must not depend on widget implementation details.
- API/MQTT/DB calls must not be made directly in screens.
- Riverpod must not replace BLoC for complex business flows.

## 2. Current Folder Structure

```text
lib/
  bloc/
    auth/
    device/
    mqtt/
    station/

  core/
    config/
      app_config.dart
    state/
      app_shell_provider.dart
      selected_device_provider.dart
      station_camera_preferences_provider.dart

  database/
  models/
  repository/
    api_service.dart
    mqtt_manager.dart
    scheduler_repository.dart
    user_repository.dart
  screens/
  widgets/
  main.dart
```

Notes:
- `core/error`, `core/network`, and `core/usecases` already exist and should be expanded as features grow.
- The project follows an incremental clean architecture path. Avoid forcing a full big-bang refactor.

## 3. App Bootstrap and Dependency Wiring

In `main.dart`, startup sequence is:
1. `ProviderScope` as Riverpod root.
2. `MyApp` creates shared dependencies (`ApiService`, `UserRepository`, `MQTTManager`, `NotificationService`).
3. `MultiBlocProvider` creates app-scope BLoCs.

Current startup behavior:
- `AuthBloc` performs auth check.
- `DeviceBloc` triggers initial device load.
- `StationBloc` loads station list.
- `MqttBloc` starts MQTT connection.

Rules:
- Do not recreate service instances per screen.
- Do not create app-wide BLoCs inside screen `build()` methods.

## 4. BLoC Conventions

Each BLoC module uses 3 files:
- `<feature>_event.dart`
- `<feature>_state.dart`
- `<feature>_bloc.dart`

### 4.1 Standards for New Code

- Event naming: `[Noun/Verb] + [Requested/Started/Updated]`
- State naming: `[Noun] + [Initial/LoadInProgress/LoadSuccess/LoadFailure]`
- Prefer `@freezed` for new events/states.
- Prefer `Either<Failure, T>` for domain/repository boundaries.

### 4.2 Current Codebase Status

- Existing BLoCs mainly use `Equatable` class-based states/events.
- Keep existing modules stable unless there is a clear reason to refactor.
- New features should follow `freezed + either` standards.
- Refactor legacy modules gradually, feature by feature.

## 5. BLoC vs Riverpod Decision Rules

Use BLoC when:
- API interaction, retries, backoff, pagination, or error mapping is required.
- MQTT stream handling, subscription lifecycle, reconnect, or background processing is required.
- Business logic has multi-step transitions and explicit state machines.

Use Riverpod when:
- State is lightweight global UI state (tab index, selected item, simple toggles).
- State is lightweight key-value persistence for UI support.
- State supports presentation behavior, not business orchestration.

Do not:
- Call API directly from Riverpod providers in this project.
- Read/write SharedPreferences directly inside widgets.

## 6. MQTT Architecture Rules

`MQTTManager` is a singleton and must be managed at application scope.

Required practices:
- Use `MQTTManager.instance`.
- Prefer `ensureConnected()` before subscribe/publish operations.
- Parse MQTT payloads into models before dispatching BLoC events.
- Cancel all `StreamSubscription` objects in BLoC `close()`.

Reconnect strategy:
- Use exponential backoff.
- Prevent parallel reconnect loops and duplicate connect calls.

## 7. Security and Configuration

Sensitive values must be stored in `.env`:
- `API_BASE_URL`
- `MQTT_SERVER`
- `MQTT_PORT`
- `MQTT_USERNAME`
- `MQTT_PASSWORD`
- `PRIVACY_POLICY_URL`

Never hardcode credentials in source code.

## 8. Reference Data Flows

### 8.1 Login Flow

```text
LoginScreen
  -> AuthLoginRequested
  -> AuthBloc calls ApiService + UserRepository
  -> emits AuthLoading/AuthAuthenticated/AuthFailure
  -> UI listens state for navigation/error rendering
```

### 8.2 Device Manage Flow (Paged)

```text
ManageDeviceScreen
  -> DeviceLoadManageList
  -> DeviceBloc calls paged API
  -> DeviceManageLoaded(pageIndex, maxPage, totalItems)
  -> end-of-list scroll triggers DeviceLoadManageNextPage
```

### 8.3 Station Camera Flow (Hybrid)

```text
StationBloc: loads station data from API
Riverpod: stores camera URL preferences by station
UI: combines provider watch + BlocBuilder
```

## 9. New Feature Checklist (Senior Baseline)

1. Decide state strategy first:
   - Business workflow -> BLoC
   - Lightweight UI/persistence state -> Riverpod
2. Define models with explicit parsing (`json_serializable` for complex payloads).
3. Add repository methods; do not call APIs directly from UI.
4. Name events/states using the project conventions.
5. Use dedicated loading states for sensitive screens to avoid cross-screen regressions.
6. Dispose stream subscriptions in `close()`.
7. Add tests:
   - Bloc tests for business flows
   - Provider tests for lightweight state

## 10. Anti-Patterns to Avoid

- Calling MQTT `connect()` directly from screens.
- Reusing one generic loading state for unrelated flows and causing UI flicker.
- Letting widgets call DB/API/SharedPreferences directly.
- Recreating service or BLoC instances on every rebuild.
- Passing route objects without a fallback strategy (prefer selected-state provider or detail reload).

## 11. Refactor Direction

- Move new event/state definitions to `freezed`.
- Introduce shared `Failure` types under `core/error/` and unify with `Either`.
- Add use-case classes under `core/usecases/` where business flows become complex.
- Use `buildWhen` and `listenWhen` for real-time screens to reduce unnecessary rebuilds.

## 12. Quick Start for New Developers

1. Read `main.dart` first to understand startup and state scope.
2. Study one hybrid feature (for example, station camera) end-to-end.
3. Follow the checklist in section 9 when implementing new code.
4. If unsure between BLoC and Riverpod, default to BLoC for safety in business logic.

---

Optional doc split for scale:
- `docs/architecture.md` for layer and flow design.
- `docs/conventions.md` for naming and coding conventions.
- `docs/playbooks/feature-checklist.md` for implementation playbooks.
