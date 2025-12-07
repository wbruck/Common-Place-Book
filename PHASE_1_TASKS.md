# Phase 1: Foundation (MVP) - Detailed Task Breakdown

This document breaks down Phase 1 into granular, actionable tasks organized by feature area with dependencies clearly marked.

---

## Overview

**Goal:** A fully functional app where users can create, view, organize, and randomly discover entries.

**Success Criteria:**
- User can add a new entry in under 10 seconds
- Entries persist across app restarts
- User can browse entries by recency or tag
- Random entry feature works
- App runs on Android, iOS, and Web

---

## Task Legend

| Symbol | Meaning |
|--------|---------|
| `[P0]` | Critical - blocks other work |
| `[P1]` | High priority - core functionality |
| `[P2]` | Medium priority - important but not blocking |
| `[P3]` | Lower priority - nice to have for MVP |
| `→` | Depends on |
| `S` | Small (~1-2 hours) |
| `M` | Medium (~2-4 hours) |
| `L` | Large (~4-8 hours) |
| `XL` | Extra Large (~1-2 days) |

---

## 1. Project Setup & Configuration

### 1.1 Flutter Project Initialization
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 1.1.1 | Create Flutter project with proper package name (`com.commonplacebook.app`) | S | P0 | - |
| 1.1.2 | Configure `pubspec.yaml` with project metadata (description, version) | S | P0 | → 1.1.1 |
| 1.1.3 | Set up folder structure following clean architecture | M | P0 | → 1.1.1 |
| 1.1.4 | Configure analysis options (`analysis_options.yaml`) with strict linting | S | P2 | → 1.1.1 |

### 1.2 Dependencies Setup
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 1.2.1 | Add state management: `flutter_bloc`, `bloc` | S | P0 | → 1.1.2 |
| 1.2.2 | Add database: `drift`, `drift_flutter`, `sqlite3_flutter_libs` | S | P0 | → 1.1.2 |
| 1.2.3 | Add routing: `go_router` | S | P0 | → 1.1.2 |
| 1.2.4 | Add utilities: `uuid`, `intl`, `path_provider`, `path` | S | P1 | → 1.1.2 |
| 1.2.5 | Add UI: `google_fonts`, `flutter_animate` | S | P2 | → 1.1.2 |
| 1.2.6 | Add dev dependencies: `drift_dev`, `build_runner` | S | P0 | → 1.1.2 |
| 1.2.7 | Run `flutter pub get` and verify all dependencies resolve | S | P0 | → 1.2.1-1.2.6 |

### 1.3 Platform Configuration
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 1.3.1 | Configure Android: app name, package ID, minimum SDK (21+) | S | P1 | → 1.1.1 |
| 1.3.2 | Configure iOS: bundle ID, display name, minimum iOS version (12+) | S | P1 | → 1.1.1 |
| 1.3.3 | Configure Web: title, favicon, meta tags | S | P2 | → 1.1.1 |
| 1.3.4 | Add app icons placeholder (can be refined later) | S | P3 | → 1.1.1 |

---

## 2. Database Layer

### 2.1 Drift Setup
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 2.1.1 | Create `database.dart` with Drift database class | M | P0 | → 1.2.7 |
| 2.1.2 | Define `entries` table schema | M | P0 | → 2.1.1 |
| 2.1.3 | Define `tags` table schema | S | P0 | → 2.1.1 |
| 2.1.4 | Define `entry_tags` junction table | S | P0 | → 2.1.2, 2.1.3 |
| 2.1.5 | Define `categories` table schema | S | P1 | → 2.1.1 |
| 2.1.6 | Define `settings` table for user preferences | S | P2 | → 2.1.1 |
| 2.1.7 | Run code generation (`dart run build_runner build`) | S | P0 | → 2.1.2-2.1.6 |
| 2.1.8 | Create database provider/singleton for app-wide access | S | P0 | → 2.1.7 |

### 2.2 Data Access Objects (DAOs)
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 2.2.1 | Create `EntriesDao` with CRUD operations | M | P0 | → 2.1.7 |
| 2.2.2 | Add query: get all entries (with pagination) | S | P0 | → 2.2.1 |
| 2.2.3 | Add query: get entries by tag | S | P1 | → 2.2.1 |
| 2.2.4 | Add query: get random entry | S | P1 | → 2.2.1 |
| 2.2.5 | Add query: get random entry by tag | S | P1 | → 2.2.3 |
| 2.2.6 | Add query: search entries by content | M | P1 | → 2.2.1 |
| 2.2.7 | Add query: get related entries (shared tags) | M | P2 | → 2.2.3 |
| 2.2.8 | Create `TagsDao` with CRUD operations | M | P0 | → 2.1.7 |
| 2.2.9 | Add query: get all tags with entry counts | S | P1 | → 2.2.8 |
| 2.2.10 | Create `CategoriesDao` with CRUD operations | M | P2 | → 2.1.7 |
| 2.2.11 | Add update `last_viewed_at` and increment `view_count` method | S | P1 | → 2.2.1 |

---

## 3. Domain Layer (Models & Repositories)

### 3.1 Domain Entities
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 3.1.1 | Create `Entry` entity class | S | P0 | → 1.2.7 |
| 3.1.2 | Create `Tag` entity class | S | P0 | → 1.2.7 |
| 3.1.3 | Create `Category` entity class | S | P2 | → 1.2.7 |
| 3.1.4 | Create `EntryWithTags` composite model | S | P0 | → 3.1.1, 3.1.2 |

### 3.2 Repositories
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 3.2.1 | Create `EntryRepository` interface | S | P0 | → 3.1.4 |
| 3.2.2 | Implement `LocalEntryRepository` using DAOs | M | P0 | → 3.2.1, 2.2.1 |
| 3.2.3 | Create `TagRepository` interface | S | P0 | → 3.1.2 |
| 3.2.4 | Implement `LocalTagRepository` using DAOs | M | P0 | → 3.2.3, 2.2.8 |
| 3.2.5 | Create `CategoryRepository` interface | S | P2 | → 3.1.3 |
| 3.2.6 | Implement `LocalCategoryRepository` | M | P2 | → 3.2.5, 2.2.10 |

### 3.3 Mappers
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 3.3.1 | Create mappers: Drift table rows ↔ Domain entities | M | P0 | → 3.1.1-3.1.4 |

---

## 4. State Management (BLoC/Cubit)

### 4.1 Entry Management
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 4.1.1 | Create `EntriesListCubit` for home screen entry list | M | P0 | → 3.2.2 |
| 4.1.2 | Define states: loading, loaded, error, empty | S | P0 | → 4.1.1 |
| 4.1.3 | Add load entries with sorting/filtering | M | P0 | → 4.1.1 |
| 4.1.4 | Add refresh functionality | S | P1 | → 4.1.1 |
| 4.1.5 | Create `EntryDetailCubit` for viewing single entry | M | P0 | → 3.2.2 |
| 4.1.6 | Add load related entries | M | P2 | → 4.1.5 |
| 4.1.7 | Add update view count on entry open | S | P1 | → 4.1.5 |

### 4.2 Entry Creation/Editing
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 4.2.1 | Create `EntryFormCubit` for create/edit flow | M | P0 | → 3.2.2 |
| 4.2.2 | Add form validation logic | S | P0 | → 4.2.1 |
| 4.2.3 | Add save entry (create new) | M | P0 | → 4.2.1 |
| 4.2.4 | Add update entry (edit existing) | M | P1 | → 4.2.1 |
| 4.2.5 | Add delete entry with confirmation | S | P1 | → 4.2.1 |

### 4.3 Tags
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 4.3.1 | Create `TagsCubit` for tag management | M | P0 | → 3.2.4 |
| 4.3.2 | Add load all tags | S | P0 | → 4.3.1 |
| 4.3.3 | Add create new tag | S | P0 | → 4.3.1 |
| 4.3.4 | Add delete tag | S | P2 | → 4.3.1 |

### 4.4 Discovery (Random)
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 4.4.1 | Create `DiscoveryCubit` for random entry feature | M | P1 | → 3.2.2 |
| 4.4.2 | Add get random entry (all) | S | P1 | → 4.4.1 |
| 4.4.3 | Add get random entry (by tag filter) | S | P1 | → 4.4.1 |
| 4.4.4 | Add shuffle/get next random | S | P1 | → 4.4.1 |

---

## 5. Theming & Design System

### 5.1 Theme Configuration
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 5.1.1 | Define color palette constants (light theme) | S | P0 | → 1.1.3 |
| 5.1.2 | Define color palette constants (dark theme) | S | P1 | → 5.1.1 |
| 5.1.3 | Configure typography with Google Fonts (Lora, Inter) | M | P0 | → 1.2.5 |
| 5.1.4 | Create `AppTheme` class with light `ThemeData` | M | P0 | → 5.1.1, 5.1.3 |
| 5.1.5 | Create dark `ThemeData` | M | P1 | → 5.1.2, 5.1.3 |
| 5.1.6 | Create `ThemeCubit` for theme switching | S | P1 | → 5.1.4, 5.1.5 |
| 5.1.7 | Persist theme preference to local storage | S | P2 | → 5.1.6 |

### 5.2 Spacing & Layout Constants
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 5.2.1 | Define spacing scale (4, 8, 12, 16, 24, 32, 48) | S | P0 | → 1.1.3 |
| 5.2.2 | Define border radius constants | S | P0 | → 1.1.3 |
| 5.2.3 | Define elevation/shadow constants | S | P2 | → 1.1.3 |

---

## 6. Shared UI Components

### 6.1 Core Widgets
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 6.1.1 | Create `EntryCard` widget for list display | M | P0 | → 5.1.4 |
| 6.1.2 | Create `TagChip` widget | S | P0 | → 5.1.4 |
| 6.1.3 | Create `TagSelector` widget (multi-select) | M | P0 | → 6.1.2, 4.3.1 |
| 6.1.4 | Create `EmptyState` widget with illustration | S | P1 | → 5.1.4 |
| 6.1.5 | Create `LoadingIndicator` widget | S | P0 | → 5.1.4 |
| 6.1.6 | Create `ErrorDisplay` widget with retry button | S | P1 | → 5.1.4 |

### 6.2 Interactive Components
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 6.2.1 | Create `PrimaryButton` styled button | S | P0 | → 5.1.4 |
| 6.2.2 | Create `FloatingAddButton` (FAB) | S | P0 | → 5.1.4 |
| 6.2.3 | Create `SearchBar` widget | M | P1 | → 5.1.4 |
| 6.2.4 | Create `ConfirmationDialog` reusable dialog | S | P1 | → 5.1.4 |

---

## 7. Navigation & Routing

### 7.1 Router Setup
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 7.1.1 | Configure `GoRouter` with initial routes | M | P0 | → 1.2.3 |
| 7.1.2 | Define route: `/` (Home) | S | P0 | → 7.1.1 |
| 7.1.3 | Define route: `/entry/new` (Create Entry) | S | P0 | → 7.1.1 |
| 7.1.4 | Define route: `/entry/:id` (Entry Detail) | S | P0 | → 7.1.1 |
| 7.1.5 | Define route: `/entry/:id/edit` (Edit Entry) | S | P1 | → 7.1.1 |
| 7.1.6 | Define route: `/discover` (Random Discovery) | S | P1 | → 7.1.1 |
| 7.1.7 | Define route: `/tags` (Tag Management) | S | P2 | → 7.1.1 |
| 7.1.8 | Define route: `/settings` (Settings) | S | P2 | → 7.1.1 |
| 7.1.9 | Add navigation transitions (fade/slide) | S | P3 | → 7.1.1 |

---

## 8. App Shell & Main Entry

### 8.1 App Initialization
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 8.1.1 | Create `main.dart` with app initialization | S | P0 | → 2.1.8 |
| 8.1.2 | Initialize database on app start | S | P0 | → 8.1.1, 2.1.8 |
| 8.1.3 | Set up dependency injection (manual or package) | M | P0 | → 8.1.1 |
| 8.1.4 | Create `App` widget with `MaterialApp.router` | S | P0 | → 7.1.1, 5.1.4 |
| 8.1.5 | Wrap app with `MultiBlocProvider` for global state | S | P0 | → 8.1.4 |

---

## 9. Feature: Home Screen

### 9.1 Home Screen Layout
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 9.1.1 | Create `HomeScreen` scaffold with app bar | M | P0 | → 8.1.5 |
| 9.1.2 | Add greeting header with time-based message | S | P2 | → 9.1.1 |
| 9.1.3 | Create "Today's Wisdom" random entry card section | M | P1 | → 9.1.1, 4.4.1 |
| 9.1.4 | Add shuffle button for random card | S | P1 | → 9.1.3 |
| 9.1.5 | Create "Recent Entries" horizontal scroll section | M | P0 | → 9.1.1, 6.1.1 |
| 9.1.6 | Create "By Topic" tag list section | M | P1 | → 9.1.1, 4.3.1 |
| 9.1.7 | Add floating action button for new entry | S | P0 | → 9.1.1, 6.2.2 |
| 9.1.8 | Connect to `EntriesListCubit` and render states | M | P0 | → 9.1.5, 4.1.1 |
| 9.1.9 | Handle empty state (no entries yet) | S | P1 | → 9.1.8, 6.1.4 |
| 9.1.10 | Handle loading state | S | P0 | → 9.1.8, 6.1.5 |
| 9.1.11 | Handle error state | S | P1 | → 9.1.8, 6.1.6 |

### 9.2 Home Screen Navigation
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 9.2.1 | Navigate to entry detail on card tap | S | P0 | → 9.1.5 |
| 9.2.2 | Navigate to new entry on FAB tap | S | P0 | → 9.1.7 |
| 9.2.3 | Navigate to filtered list on tag tap | S | P1 | → 9.1.6 |
| 9.2.4 | Add app bar menu with settings/about | S | P3 | → 9.1.1 |

---

## 10. Feature: Entry Creation

### 10.1 New Entry Screen
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 10.1.1 | Create `NewEntryScreen` scaffold | M | P0 | → 7.1.3 |
| 10.1.2 | Add app bar with close (X) and Save button | S | P0 | → 10.1.1 |
| 10.1.3 | Create content text field (multi-line, auto-focus) | M | P0 | → 10.1.1 |
| 10.1.4 | Add placeholder text: "What wisdom would you like to capture?" | S | P0 | → 10.1.3 |
| 10.1.5 | Create source/attribution text field (optional) | S | P1 | → 10.1.1 |
| 10.1.6 | Integrate `TagSelector` for tag selection | M | P0 | → 10.1.1, 6.1.3 |
| 10.1.7 | Add "create new tag" inline option | S | P1 | → 10.1.6 |
| 10.1.8 | Add category dropdown (optional for MVP) | S | P2 | → 10.1.1 |
| 10.1.9 | Connect to `EntryFormCubit` | M | P0 | → 10.1.3, 4.2.1 |
| 10.1.10 | Implement save action with validation | M | P0 | → 10.1.9 |
| 10.1.11 | Show saving indicator | S | P1 | → 10.1.10 |
| 10.1.12 | Navigate back on successful save | S | P0 | → 10.1.10 |
| 10.1.13 | Show error snackbar on save failure | S | P1 | → 10.1.10 |
| 10.1.14 | Add unsaved changes confirmation dialog | S | P2 | → 10.1.1 |

---

## 11. Feature: Entry Detail View

### 11.1 Entry Detail Screen
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 11.1.1 | Create `EntryDetailScreen` scaffold | M | P0 | → 7.1.4 |
| 11.1.2 | Add app bar with back button, overflow menu | S | P0 | → 11.1.1 |
| 11.1.3 | Add favorite toggle (star icon) in app bar | S | P2 | → 11.1.2 |
| 11.1.4 | Display entry content with quote styling | M | P0 | → 11.1.1 |
| 11.1.5 | Display source/attribution below content | S | P0 | → 11.1.4 |
| 11.1.6 | Display tags as chips | S | P0 | → 11.1.1, 6.1.2 |
| 11.1.7 | Display metadata (created date, view count) | S | P1 | → 11.1.1 |
| 11.1.8 | Connect to `EntryDetailCubit` | M | P0 | → 11.1.1, 4.1.5 |
| 11.1.9 | Update view count on screen open | S | P1 | → 11.1.8 |
| 11.1.10 | Handle loading/error states | S | P0 | → 11.1.8 |

### 11.2 Related Entries Section
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 11.2.1 | Create "Related" section header | S | P2 | → 11.1.1 |
| 11.2.2 | Display related entries as compact cards | M | P2 | → 11.2.1, 4.1.6 |
| 11.2.3 | Navigate to related entry on tap | S | P2 | → 11.2.2 |

### 11.3 Entry Actions
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 11.3.1 | Add edit option in overflow menu | S | P1 | → 11.1.2 |
| 11.3.2 | Add delete option with confirmation | S | P1 | → 11.1.2, 6.2.4 |
| 11.3.3 | Add share option (copy to clipboard) | S | P3 | → 11.1.2 |
| 11.3.4 | Navigate to edit screen on edit tap | S | P1 | → 11.3.1, 7.1.5 |

---

## 12. Feature: Edit Entry

### 12.1 Edit Entry Screen
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 12.1.1 | Create `EditEntryScreen` (reuse NewEntry form) | M | P1 | → 10.1.1 |
| 12.1.2 | Pre-populate form with existing entry data | M | P1 | → 12.1.1 |
| 12.1.3 | Change app bar title to "Edit Entry" | S | P1 | → 12.1.1 |
| 12.1.4 | Implement update action | M | P1 | → 12.1.1, 4.2.4 |
| 12.1.5 | Navigate back on successful update | S | P1 | → 12.1.4 |

---

## 13. Feature: Search & Filter

### 13.1 Search Functionality
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 13.1.1 | Add search icon to home app bar | S | P1 | → 9.1.1 |
| 13.1.2 | Create search delegate or search screen | M | P1 | → 13.1.1 |
| 13.1.3 | Implement search-as-you-type with debounce | M | P1 | → 13.1.2, 2.2.6 |
| 13.1.4 | Display search results as entry list | M | P1 | → 13.1.3 |
| 13.1.5 | Handle no results state | S | P1 | → 13.1.4 |
| 13.1.6 | Navigate to entry detail from search result | S | P1 | → 13.1.4 |

### 13.2 Filtered Entry List
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 13.2.1 | Create `FilteredEntriesScreen` for tag/date filter | M | P1 | → 4.1.1 |
| 13.2.2 | Accept filter parameters (tag ID, date range) | S | P1 | → 13.2.1 |
| 13.2.3 | Display filtered results with filter indicator | M | P1 | → 13.2.1 |
| 13.2.4 | Add sort options (date, views, alpha) | M | P2 | → 13.2.1 |

---

## 14. Feature: Random Discovery

### 14.1 Discovery Screen
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 14.1.1 | Create `DiscoveryScreen` scaffold | M | P1 | → 7.1.6 |
| 14.1.2 | Display random entry in large, centered card | M | P1 | → 14.1.1 |
| 14.1.3 | Add shuffle button with animation | S | P1 | → 14.1.2 |
| 14.1.4 | Add tag filter chips at top | M | P1 | → 14.1.1, 4.3.1 |
| 14.1.5 | Filter random by selected tags | M | P1 | → 14.1.4, 4.4.3 |
| 14.1.6 | Connect to `DiscoveryCubit` | M | P1 | → 14.1.2, 4.4.1 |
| 14.1.7 | Add swipe gesture to shuffle | S | P2 | → 14.1.2 |
| 14.1.8 | Navigate to full entry detail on tap | S | P1 | → 14.1.2 |
| 14.1.9 | Handle "no entries" state | S | P1 | → 14.1.6 |

### 14.2 Home Screen Integration
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 14.2.1 | Link "Today's Wisdom" section to discovery | S | P1 | → 9.1.3 |
| 14.2.2 | Add "Discover" navigation option | S | P1 | → 9.1.1 |

---

## 15. Feature: Basic Tag Management

### 15.1 Tag List Screen
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 15.1.1 | Create `TagsScreen` scaffold | M | P2 | → 7.1.7 |
| 15.1.2 | Display all tags with entry counts | M | P2 | → 15.1.1, 4.3.1 |
| 15.1.3 | Add create new tag option | S | P2 | → 15.1.1, 4.3.3 |
| 15.1.4 | Add delete tag with confirmation | S | P2 | → 15.1.2, 4.3.4 |
| 15.1.5 | Navigate to filtered entries on tag tap | S | P2 | → 15.1.2 |

---

## 16. Settings (Basic)

### 16.1 Settings Screen
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 16.1.1 | Create `SettingsScreen` scaffold | M | P2 | → 7.1.8 |
| 16.1.2 | Add theme toggle (light/dark) | S | P2 | → 16.1.1, 5.1.6 |
| 16.1.3 | Display app version | S | P3 | → 16.1.1 |
| 16.1.4 | Add "About" section with app description | S | P3 | → 16.1.1 |

---

## 17. Testing (MVP Level)

### 17.1 Unit Tests
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 17.1.1 | Test `EntryRepository` CRUD operations | M | P1 | → 3.2.2 |
| 17.1.2 | Test `EntriesListCubit` state transitions | M | P1 | → 4.1.1 |
| 17.1.3 | Test `EntryFormCubit` validation and save | M | P1 | → 4.2.1 |
| 17.1.4 | Test `DiscoveryCubit` random selection | S | P2 | → 4.4.1 |

### 17.2 Widget Tests
| ID | Task | Size | Priority | Dependencies |
|----|------|------|----------|--------------|
| 17.2.1 | Test `EntryCard` renders correctly | S | P2 | → 6.1.1 |
| 17.2.2 | Test `TagSelector` selection behavior | S | P2 | → 6.1.3 |
| 17.2.3 | Test `NewEntryScreen` form submission | M | P2 | → 10.1.1 |

---

## Dependency Graph (Critical Path)

```
1.1.1 Project Setup
  │
  ├── 1.2.* Dependencies
  │     │
  │     └── 2.1.* Database Setup
  │           │
  │           ├── 2.2.* DAOs
  │           │     │
  │           │     └── 3.2.* Repositories
  │           │           │
  │           │           ├── 4.1.* Entry Cubits
  │           │           │     │
  │           │           │     └── 9.* Home Screen
  │           │           │           │
  │           │           │           └── MVP COMPLETE
  │           │           │
  │           │           ├── 4.2.* Form Cubit
  │           │           │     │
  │           │           │     └── 10.* New Entry Screen
  │           │           │
  │           │           └── 4.4.* Discovery Cubit
  │           │                 │
  │           │                 └── 14.* Discovery Screen
  │           │
  │           └── 3.1.* Domain Entities
  │
  ├── 5.* Theming
  │     │
  │     └── 6.* Shared Widgets
  │
  └── 7.* Routing
        │
        └── 8.* App Shell
```

---

## Suggested Implementation Order

### Sprint 1: Foundation
1. Project Setup (1.1, 1.2, 1.3)
2. Database Layer (2.1, 2.2)
3. Domain Models (3.1, 3.2, 3.3)
4. App Shell (8.1)

### Sprint 2: Core UI
5. Theming (5.1, 5.2)
6. Shared Widgets (6.1, 6.2)
7. Navigation (7.1)

### Sprint 3: Entry Management
8. Entry Cubits (4.1, 4.2)
9. Home Screen (9.1, 9.2)
10. New Entry Screen (10.1)
11. Entry Detail Screen (11.1, 11.3)

### Sprint 4: Discovery & Polish
12. Tags Cubit (4.3)
13. Discovery Cubit (4.4)
14. Discovery Screen (14.1, 14.2)
15. Related Entries (11.2)
16. Search (13.1)

### Sprint 5: Refinement
17. Edit Entry (12.1)
18. Tag Management (15.1)
19. Settings (16.1)
20. Testing (17.1, 17.2)

---

## Task Count Summary

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 47 | Critical path - must complete |
| P1 | 48 | High priority - core features |
| P2 | 32 | Medium priority - important polish |
| P3 | 7 | Lower priority - nice to have |
| **Total** | **134** | All Phase 1 tasks |

---

## Checklist for MVP Completion

Before considering Phase 1 complete:

- [ ] User can create new entries with content, source, and tags
- [ ] Entries persist and appear on home screen
- [ ] User can view entry details
- [ ] User can edit existing entries
- [ ] User can delete entries
- [ ] Random entry feature works
- [ ] Search finds entries by content
- [ ] Filter by tag works
- [ ] Light and dark themes work
- [ ] App runs on Android without crashes
- [ ] App runs on iOS without crashes
- [ ] App runs on Web without major issues
- [ ] Core unit tests pass
