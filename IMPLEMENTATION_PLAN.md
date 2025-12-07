# Implementation Plan - Common Place Book

This document tracks the active implementation progress for Phase 1 (MVP).

---

## Current Sprint: Testing & Polish

**Goal:** Run code generation, test the app, and fix any issues.

---

## Sprint 1: Foundation - COMPLETED

### 1.1 Flutter Project Initialization
- [x] 1.1.1 Create Flutter project with package name `com.commonplacebook.app`
- [x] 1.1.2 Configure `pubspec.yaml` with project metadata
- [x] 1.1.3 Set up folder structure following clean architecture
- [x] 1.1.4 Configure `analysis_options.yaml` with strict linting

### 1.2 Dependencies Setup
- [x] 1.2.1 Add state management: `flutter_bloc`, `bloc`
- [x] 1.2.2 Add database: `drift`, `drift_flutter`, `sqlite3_flutter_libs`
- [x] 1.2.3 Add routing: `go_router`
- [x] 1.2.4 Add utilities: `uuid`, `intl`, `path_provider`, `path`
- [x] 1.2.5 Add UI: `google_fonts`, `flutter_animate`
- [x] 1.2.6 Add dev dependencies: `drift_dev`, `build_runner`
- [ ] 1.2.7 Run `flutter pub get` and verify dependencies

### 1.3 Platform Configuration
- [ ] 1.3.1 Configure Android: app name, package ID, min SDK
- [ ] 1.3.2 Configure iOS: bundle ID, display name, min iOS
- [ ] 1.3.3 Configure Web: title, favicon, meta tags

### 2.1 Drift Database Setup
- [x] 2.1.1 Create `database.dart` with Drift database class
- [x] 2.1.2 Define `entries` table schema
- [x] 2.1.3 Define `tags` table schema
- [x] 2.1.4 Define `entry_tags` junction table
- [x] 2.1.5 Define `categories` table schema
- [x] 2.1.6 Define `settings` table for user preferences
- [ ] 2.1.7 Run code generation (`dart run build_runner build`)
- [x] 2.1.8 Create database provider for app-wide access

### 2.2 Data Access Objects (DAOs)
- [x] 2.2.1 Create `EntriesDao` with CRUD operations
- [x] 2.2.2 Add query: get all entries (with pagination)
- [x] 2.2.3 Add query: get entries by tag
- [x] 2.2.4 Add query: get random entry
- [x] 2.2.5 Add query: get random entry by tag
- [x] 2.2.6 Add query: search entries by content
- [x] 2.2.7 Add query: get related entries (shared tags)
- [x] 2.2.8 Create `TagsDao` with CRUD operations
- [x] 2.2.9 Add query: get all tags with entry counts
- [x] 2.2.10 Create `CategoriesDao` with CRUD operations
- [x] 2.2.11 Add update `last_viewed_at` and increment `view_count`

---

## Sprint 2: Core UI - COMPLETED

### 3.1 Domain Entities
- [x] 3.1.1 Create `Entry` entity class
- [x] 3.1.2 Create `Tag` entity class
- [x] 3.1.3 Create `Category` entity class
- [x] 3.1.4 Create `EntryWithTags` composite model

### 3.2 Repositories
- [x] 3.2.1 Create `EntryRepository` interface
- [x] 3.2.2 Implement `LocalEntryRepository`
- [x] 3.2.3 Create `TagRepository` interface
- [x] 3.2.4 Implement `LocalTagRepository`

### 5.1 Theme Configuration
- [x] 5.1.1 Define color palette constants (light)
- [x] 5.1.2 Define color palette constants (dark)
- [x] 5.1.3 Configure typography with Google Fonts
- [x] 5.1.4 Create `AppTheme` class with light `ThemeData`
- [x] 5.1.5 Create dark `ThemeData`
- [ ] 5.1.6 Create `ThemeCubit` for theme switching (deferred)

### 6.1 Core Widgets
- [x] 6.1.1 Create `EntryCard` widget
- [x] 6.1.2 Create `TagChip` widget
- [x] 6.1.3 Create `TagSelector` widget
- [x] 6.1.4 Create `EmptyState` widget
- [x] 6.1.5 Create `LoadingIndicator` widget
- [x] 6.1.6 Create `ErrorDisplay` widget

### 7.1 Router Setup
- [x] 7.1.1 Configure `GoRouter` with routes
- [x] 7.1.2-7.1.8 Define all routes

### 8.1 App Initialization
- [x] 8.1.1 Create `main.dart` with app initialization
- [x] 8.1.2 Initialize database on app start
- [x] 8.1.3 Set up dependency injection
- [x] 8.1.4 Create `App` widget with `MaterialApp.router`
- [x] 8.1.5 Wrap app with `MultiBlocProvider`

---

## Sprint 3: Entry Management - COMPLETED

### 4.1-4.4 State Management
- [x] EntriesListCubit - list, filter, search
- [x] EntryDetailCubit - view with related entries
- [x] EntryFormCubit - create/edit form state
- [x] TagsCubit - tag management
- [x] DiscoveryCubit - random discovery

### 9.x Home Screen
- [x] Home screen layout with greeting
- [x] Today's Wisdom random card
- [x] Recent entries horizontal scroll
- [x] By Topic tag list
- [x] FAB for new entry
- [x] Search functionality

### 10.x New Entry Screen
- [x] Form layout
- [x] Content and source fields
- [x] Tag selection with create new
- [x] Save/validation functionality
- [x] Unsaved changes dialog

### 11.x Entry Detail Screen
- [x] Detail layout with quote styling
- [x] Metadata display
- [x] Related entries
- [x] Favorite toggle
- [x] Edit/Delete/Copy actions

### 14.x Discovery Screen
- [x] Random entry display
- [x] Tag filtering
- [x] Shuffle functionality
- [x] Related entries
- [x] Swipe gesture

### 15.x Tags Screen
- [x] Tag list with counts
- [x] Create new tag
- [x] Rename tag
- [x] Delete tag

### 16.x Settings Screen
- [x] Theme selector (UI only)
- [x] About dialog
- [x] Placeholder for export/import/sync

---

## Remaining Tasks

### To Run the App
1. Run `flutter pub get` to install dependencies
2. Run `dart run build_runner build` to generate Drift code
3. Run `flutter run` to start the app

### Platform Configuration (Optional)
- [ ] Android: Update app name in AndroidManifest.xml
- [ ] iOS: Update bundle ID in Xcode
- [ ] Web: Update index.html title

### Testing (Phase 1 Stretch)
- [ ] Unit tests for repositories
- [ ] Unit tests for cubits
- [ ] Widget tests for screens

---

## Progress Log

| Date | Tasks Completed | Notes |
|------|-----------------|-------|
| 2025-12-07 | Sprint 1-3 complete | Full MVP implementation |

---

## Project Statistics

| Metric | Count |
|--------|-------|
| Files created | 35 |
| Lines of code | ~5,100 |
| Features implemented | 6 screens, 5 cubits |
| Database tables | 5 |

---

## Next Steps (Phase 2)

1. Add unit and widget tests
2. Implement ThemeCubit for persistent theme preference
3. Add micro-animations with flutter_animate
4. Implement export/import functionality
5. Consider onboarding flow
