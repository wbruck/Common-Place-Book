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
flutter run -d chrome        # Web
flutter run -d macos         # macOS
flutter run -d android       # Android
flutter run -d ios           # iOS

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
- Default categories are seeded on first run (see database.dart:98-136)
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
