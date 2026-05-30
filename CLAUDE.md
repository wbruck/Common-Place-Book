# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Common Place Book is a cross-platform Flutter application (iOS, Android, Web) for storing quotes, ideas, and wisdom. Uses Clean Architecture with feature-based organization, BLoC/Cubit for state management, and Drift (SQLite) for local storage.

## Essential Commands

### Development
```bash
# Install dependencies
flutter pub get

# Generate code (Drift database files)
dart run build_runner build

# Watch mode for code generation during development
dart run build_runner watch

# Run app
flutter run

# Run on specific platform
flutter run -d chrome        # Web (no CORS headers needed, see below)
flutter run -d macos         # macOS
flutter run -d android       # Android
flutter run -d ios           # iOS

# Run on web
flutter run -d chrome

# Run tests
flutter test

# Run specific test
flutter test test/widget_test.dart

# Analyze code
flutter analyze
```

### Code Generation
After modifying any Drift database files (database.dart, DAOs), regenerate with:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Web Database Setup
This project uses **drift's WebAssembly (WASM) backend via `WasmDatabase.open`** for the web platform (see `lib/core/database/connection/web.dart`). Storage is durable: drift picks **OPFS** when the page is cross-origin isolated, otherwise **IndexedDB**.

> Migrated away from the legacy `WebDatabase` (sql.js) backend. That backend serialized the whole DB into a single `localStorage` key, which has a ~5MB cap and silently dropped writes on `QuotaExceededError`, losing data on reload.

**Required files in `web/` directory:**
- `sqlite3.wasm` - sqlite3 compiled to WebAssembly.
- `drift_worker.js` - drift web worker (compiled from `package:drift`).

**How to (re)generate these assets** — they must match the `drift` and `sqlite3` versions in `pubspec.lock`:

```bash
# 1. Compile the drift worker that ships with the drift package to JS.
#    (Look up the resolved drift version, e.g. 2.31.0, and copy its worker entrypoint.)
DRIFT_DIR=$(find ~/.pub-cache -maxdepth 3 -type d -name 'drift-*' | sort | tail -1)
mkdir -p tool/web && cp "$DRIFT_DIR/web/drift_worker.dart" tool/web/drift_worker.dart
dart compile js -O4 -o web/drift_worker.js tool/web/drift_worker.dart
rm -rf tool/web web/drift_worker.js.deps web/drift_worker.js.map

# 2. Download sqlite3.wasm matching the `sqlite3` package version in pubspec.lock
#    (e.g. sqlite3 2.9.4) from the sqlite3.dart GitHub releases:
curl -L -o web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm"
```

**Cloudflare Pages**: `web/_headers` sets `Content-Type: application/wasm` for `*.wasm` so the WASM instantiates. COOP/COEP headers (needed for the OPFS upgrade) are present but commented out, because cross-origin isolation can break non-CORS third-party assets. IndexedDB persistence works without them.

**Why WASM + IndexedDB/OPFS?**
- Supported, non-deprecated drift 2.31 web path.
- Durable persistence with no quota cliff (unlike `localStorage`).
- No CORS/COOP/COEP headers required for the IndexedDB tier.
- Real sqlite3 (full SQL) running in a web worker.

## Architecture

### Clean Architecture Pattern
- **Domain Layer**: Abstract contracts (EntryRepository, TagRepository)
- **Data Layer**: Concrete implementations (LocalEntryRepository, LocalTagRepository)
- **Presentation Layer**: BLoC/Cubit + UI

### Feature Structure
```
lib/features/<feature>/
├── data/
│   ├── mappers/          # Entity <-> Database model conversion
│   └── repositories/     # Concrete repository implementations
├── domain/
│   └── entities/         # Business models
└── presentation/
    ├── bloc/             # State management (Cubit/BLoC)
    └── screens/          # UI screens
```

### Core Components

**Database**: Platform-conditional connections
- `lib/core/database/connection/native.dart` - iOS/Android/Desktop (uses drift_flutter)
- `lib/core/database/connection/web.dart` - Web (uses WASM SQLite)
- `lib/core/database/database.dart` - Table definitions and migration logic
- Current schema version: 2

**State Management**:
- Repositories provided at app level via RepositoryProvider
- Feature Cubits provided via BlocProvider
- EntriesListCubit and TagsCubit are global app-level cubits
- Screen-specific cubits (EntryDetailCubit, EntryFormCubit, DiscoveryCubit) created per-screen

**Routing**: GoRouter in `lib/app/router.dart`
- Named routes for navigation
- Path parameters for dynamic routes (e.g., '/entry/:id')

### Database Schema

**Tables**:
- `entries` - Main content storage with metadata (viewCount, lastViewedAt, isFavorite)
- `tags` - User-created tags with optional colors
- `entry_tags` - Many-to-many junction table (CASCADE delete)
- `categories` - Hierarchical categories with default seeds (Philosophy, Literature, Science, Personal, Wisdom)
- `settings` - Key-value configuration storage

**Important**:
- Default categories are seeded on first run (see `_seedDefaultCategories` in database.dart)
- EntryTags uses ON DELETE CASCADE (schema v2)
- All IDs are UUIDs stored as text

## Code Style & Conventions

### Linting
This project uses strict linting rules (see analysis_options.yaml):
- `strict-casts`, `strict-inference`, `strict-raw-types` enabled
- Prefer single quotes
- Require trailing commas
- Use `prefer_final_locals` and `prefer_final_in_for_each`
- Always declare return types
- Avoid dynamic calls

### Generated Files
Exclude from version control and analysis:
- `**/*.g.dart` (Drift generated files)
- `**/*.freezed.dart`

### Common Patterns
- **Error Handling**: Use `Result<T>` type in `lib/core/utils/result.dart` for operation results
- **Logging**: AppLogger in `lib/core/utils/app_logger.dart`
- **Repository Pattern**: Always program to interfaces (abstract EntryRepository, not LocalEntryRepository)
- **Dependency Injection**: Use context.read<T>() for repositories in Cubits
