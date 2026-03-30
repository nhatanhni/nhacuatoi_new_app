# Flutter Senior Rules - Clean Architecture + BLoC

## 🎯 General Principles

* Follow Clean Architecture strictly: Presentation → Domain → Data
* Write maintainable, scalable, and testable code
* Avoid quick hacks, always prefer long-term solutions
* Keep code readable and self-explanatory
* Use SOLID principles

---

## 📁 Project Structure

lib/
├── core/
│   ├── error/
│   ├── usecases/
│   ├── utils/
│   └── constants/
│
├── features/
│   └── feature_name/
│       ├── data/
│       │   ├── models/
│       │   ├── datasources/
│       │   └── repositories/
│       │
│       ├── domain/
│       │   ├── entities/
│       │   ├── repositories/
│       │   └── usecases/
│       │
│       └── presentation/
│           ├── bloc/
│           ├── pages/
│           └── widgets/

---

## 🧱 BLoC Rules

* Use flutter_bloc package

* Separate:

  * Event
  * State
  * Bloc

* States must be immutable

* Use Equatable for comparison

* Avoid business logic inside UI

* Bloc only handles logic, not UI

* Naming:

  * LoginBloc
  * LoginEvent
  * LoginState

---

## 📦 Domain Layer

* Pure Dart (NO Flutter imports)

* Contains:

  * Entities
  * Repository interfaces
  * UseCases

* UseCases:

  * Single responsibility
  * Example:

    * GetUserProfile
    * LoginUser

---

## 🗄️ Data Layer

* Implements repository interfaces

* Handles:

  * API calls
  * Local storage

* Use DTO/Model:

  * Model extends Entity or maps to Entity

* Always map Model → Entity

---

## 🎨 Presentation Layer

* UI must be dumb (stateless when possible)

* Use BlocBuilder / BlocListener correctly

* DO NOT:

  * call API directly
  * put logic inside widgets

* Prefer:

  * small reusable widgets
  * const constructors

---

## 🧼 Code Style

* Use const everywhere possible
* Prefer final over var
* Avoid deeply nested widgets
* Extract widgets when > 50 lines
* Use meaningful names

---

## ⚠️ Anti-patterns (STRICTLY FORBIDDEN)

* setState for business logic
* God classes
* Mixing layers
* Direct API calls in UI
* Hardcoded strings (use constants)

---

## 🧪 Testing

* Write unit tests for:

  * UseCases
  * Bloc

* Use mocktail or mockito

---

## 🔥 When generating code

ALWAYS:

* Follow Clean Architecture
* Use BLoC pattern
* Separate files properly
* Add meaningful naming
* Use null safety
* Optimize performance

NEVER:

* Write everything in one file
* Mix UI and logic
* Skip layers

---

## 🧠 Output Expectations

When asked to generate a feature:

* Generate full structure (data/domain/presentation)
* Include:

  * Entity
  * Model
  * Repository
  * UseCase
  * Bloc
  * UI Page

Code must look like written by a senior Flutter developer.
