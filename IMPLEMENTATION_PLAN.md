# Implementation Plan - Common Place Book

This document tracks the active implementation progress for Phase 1 (MVP).

---

## Current Sprint: Foundation

**Goal:** Set up project infrastructure, database, and core data layer.

---

## Sprint 1: Foundation

### 1.1 Flutter Project Initialization
- [ ] 1.1.1 Create Flutter project with package name `com.commonplacebook.app`
- [ ] 1.1.2 Configure `pubspec.yaml` with project metadata
- [ ] 1.1.3 Set up folder structure following clean architecture
- [ ] 1.1.4 Configure `analysis_options.yaml` with strict linting

### 1.2 Dependencies Setup
- [ ] 1.2.1 Add state management: `flutter_bloc`, `bloc`
- [ ] 1.2.2 Add database: `drift`, `drift_flutter`, `sqlite3_flutter_libs`
- [ ] 1.2.3 Add routing: `go_router`
- [ ] 1.2.4 Add utilities: `uuid`, `intl`, `path_provider`, `path`
- [ ] 1.2.5 Add UI: `google_fonts`, `flutter_animate`
- [ ] 1.2.6 Add dev dependencies: `drift_dev`, `build_runner`
- [ ] 1.2.7 Run `flutter pub get` and verify dependencies

### 1.3 Platform Configuration
- [ ] 1.3.1 Configure Android: app name, package ID, min SDK
- [ ] 1.3.2 Configure iOS: bundle ID, display name, min iOS
- [ ] 1.3.3 Configure Web: title, favicon, meta tags

### 2.1 Drift Database Setup
- [ ] 2.1.1 Create `database.dart` with Drift database class
- [ ] 2.1.2 Define `entries` table schema
- [ ] 2.1.3 Define `tags` table schema
- [ ] 2.1.4 Define `entry_tags` junction table
- [ ] 2.1.5 Define `categories` table schema
- [ ] 2.1.6 Define `settings` table for user preferences
- [ ] 2.1.7 Run code generation
- [ ] 2.1.8 Create database provider for app-wide access

### 2.2 Data Access Objects (DAOs)
- [ ] 2.2.1 Create `EntriesDao` with CRUD operations
- [ ] 2.2.2 Add query: get all entries (with pagination)
- [ ] 2.2.3 Add query: get entries by tag
- [ ] 2.2.4 Add query: get random entry
- [ ] 2.2.5 Add query: get random entry by tag
- [ ] 2.2.6 Add query: search entries by content
- [ ] 2.2.7 Add query: get related entries (shared tags)
- [ ] 2.2.8 Create `TagsDao` with CRUD operations
- [ ] 2.2.9 Add query: get all tags with entry counts
- [ ] 2.2.10 Create `CategoriesDao` with CRUD operations
- [ ] 2.2.11 Add update `last_viewed_at` and increment `view_count`

### 3.1 Domain Entities
- [ ] 3.1.1 Create `Entry` entity class
- [ ] 3.1.2 Create `Tag` entity class
- [ ] 3.1.3 Create `Category` entity class
- [ ] 3.1.4 Create `EntryWithTags` composite model

### 3.2 Repositories
- [ ] 3.2.1 Create `EntryRepository` interface
- [ ] 3.2.2 Implement `LocalEntryRepository`
- [ ] 3.2.3 Create `TagRepository` interface
- [ ] 3.2.4 Implement `LocalTagRepository`

### 8.1 App Initialization
- [ ] 8.1.1 Create `main.dart` with app initialization
- [ ] 8.1.2 Initialize database on app start
- [ ] 8.1.3 Set up dependency injection
- [ ] 8.1.4 Create `App` widget with `MaterialApp.router`
- [ ] 8.1.5 Wrap app with `MultiBlocProvider`

---

## Sprint 2: Core UI (Next)

### 5.1 Theme Configuration
- [ ] 5.1.1 Define color palette constants (light)
- [ ] 5.1.2 Define color palette constants (dark)
- [ ] 5.1.3 Configure typography with Google Fonts
- [ ] 5.1.4 Create `AppTheme` class with light `ThemeData`
- [ ] 5.1.5 Create dark `ThemeData`
- [ ] 5.1.6 Create `ThemeCubit` for theme switching

### 6.1 Core Widgets
- [ ] 6.1.1 Create `EntryCard` widget
- [ ] 6.1.2 Create `TagChip` widget
- [ ] 6.1.3 Create `TagSelector` widget
- [ ] 6.1.4 Create `EmptyState` widget
- [ ] 6.1.5 Create `LoadingIndicator` widget
- [ ] 6.1.6 Create `ErrorDisplay` widget

### 7.1 Router Setup
- [ ] 7.1.1 Configure `GoRouter` with routes
- [ ] 7.1.2-7.1.8 Define all routes

---

## Sprint 3: Entry Management (Upcoming)

### 4.1-4.2 State Management
- [ ] Entry list cubit
- [ ] Entry detail cubit
- [ ] Entry form cubit

### 9.x Home Screen
- [ ] Home screen layout
- [ ] Entry list display
- [ ] FAB for new entry

### 10.x New Entry Screen
- [ ] Form layout
- [ ] Tag selection
- [ ] Save functionality

### 11.x Entry Detail Screen
- [ ] Detail layout
- [ ] Related entries

---

## Progress Log

| Date | Tasks Completed | Notes |
|------|-----------------|-------|
| | | |

---

## Blockers & Issues

| Issue | Status | Resolution |
|-------|--------|------------|
| | | |
