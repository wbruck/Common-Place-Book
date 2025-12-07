# Common Place Book - Project Plan

A beautiful, minimalist digital commonplace book for storing and rediscovering golden nuggets of wisdom, quotes, and ideas.

---

## Overview

### What is a Commonplace Book?

A commonplace book is a traditional method of compiling knowledge - a personal repository where one stores quotes, ideas, observations, and "golden nuggets of truth" organized by themes and categories for later reflection and retrieval.

### Vision

Create a cross-platform application that digitizes this timeless practice with:
- **Simplicity** - Uncluttered interface that lets users focus on their thoughts
- **Beauty** - Elegant, calming design that invites contemplation
- **Serendipity** - Random retrieval to resurface forgotten wisdom
- **Organization** - Powerful but unobtrusive categorization and search

---

## Core Features

### 1. Entry Management

#### Create New Entry
- **One-tap creation** - Prominent but unobtrusive "+" button
- **Quick capture mode** - Minimal friction to capture a thought
- **Rich text support** - Basic formatting for quotes and notes
- **Source attribution** - Optional field for author/source

#### Entry Metadata (Auto-captured)
| Field | Description |
|-------|-------------|
| `id` | Unique identifier |
| `content` | The quote/idea/note text |
| `source` | Optional author or source attribution |
| `tags` | User-defined subject tags |
| `category` | Primary category |
| `createdAt` | Date/time of creation |
| `updatedAt` | Last modified timestamp |
| `lastViewedAt` | Last time entry was viewed |
| `viewCount` | Number of times viewed |
| `isFavorite` | Starred/favorite flag |

### 2. Organization & Discovery

#### Tagging System
- Flexible tag creation
- Tag suggestions based on content
- Tag management (rename, merge, delete)
- Color-coded tags for visual organization

#### Categories
- Hierarchical categories (optional)
- Default categories provided (Philosophy, Literature, Science, Personal, etc.)
- Custom category creation

#### Search & Filter
- Full-text search across all entries
- Filter by tags, categories, date ranges
- Sort by: date created, last viewed, view count, alphabetical

### 3. Random Discovery

#### "Rediscover" Feature
- **Random from all** - Surface any entry randomly
- **Random from topic** - Random entry from selected tag(s)
- **Random from timeframe** - Entries from specific date range
- **Daily wisdom** - Optional daily notification with random entry

#### Related Entries
- When viewing an entry, show related entries based on:
  - Shared tags
  - Similar content (keyword matching)
  - Same time period

### 4. Personalization

#### Customizable Default View
- Choose default sorting criteria
- Pin favorite tags to quick-access
- Set preferred categories for home view

#### Themes
- Light/Dark mode
- Sepia/Reading mode
- Custom accent colors

---

## Technical Architecture

### Framework: Flutter

**Rationale:**
- Single codebase for iOS, Android, and Web
- Excellent performance on all platforms
- Rich widget library for beautiful UIs
- Strong state management options
- Active community and ecosystem

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── app/
│   ├── app.dart                 # Root app widget
│   ├── router.dart              # Navigation/routing
│   └── theme/
│       ├── app_theme.dart       # Theme definitions
│       ├── colors.dart          # Color palette
│       └── typography.dart      # Text styles
│
├── features/
│   ├── entries/
│   │   ├── data/
│   │   │   ├── models/          # Entry data models
│   │   │   ├── repositories/    # Data repositories
│   │   │   └── datasources/     # Local/remote data sources
│   │   ├── domain/
│   │   │   ├── entities/        # Domain entities
│   │   │   └── usecases/        # Business logic
│   │   └── presentation/
│   │       ├── screens/         # Entry-related screens
│   │       ├── widgets/         # Reusable widgets
│   │       └── bloc/            # State management
│   │
│   ├── tags/
│   │   └── ...                  # Similar structure
│   │
│   ├── discovery/
│   │   └── ...                  # Random/related entries
│   │
│   └── settings/
│       └── ...                  # User preferences
│
├── core/
│   ├── database/
│   │   ├── database.dart        # Database setup
│   │   └── migrations/          # Schema migrations
│   ├── utils/
│   │   ├── date_utils.dart
│   │   └── string_utils.dart
│   └── constants/
│       └── app_constants.dart
│
└── shared/
    ├── widgets/                 # Shared UI components
    └── extensions/              # Dart extensions
```

### State Management: BLoC/Cubit

**Rationale:**
- Clear separation of UI and business logic
- Testable and predictable
- Well-suited for Flutter
- Scales well as app grows

### Local Storage: Drift (SQLite)

**Rationale:**
- Robust local database
- Type-safe queries
- Supports complex queries for filtering/sorting
- Migration support for schema changes
- Reactive streams for UI updates

#### Database Schema

```sql
-- Entries table
CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  content TEXT NOT NULL,
  source TEXT,
  category_id TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  last_viewed_at INTEGER,
  view_count INTEGER DEFAULT 0,
  is_favorite INTEGER DEFAULT 0,
  FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- Tags table
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color TEXT,
  created_at INTEGER NOT NULL
);

-- Entry-Tags junction table
CREATE TABLE entry_tags (
  entry_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (entry_id, tag_id),
  FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE,
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Categories table
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id TEXT,
  icon TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (parent_id) REFERENCES categories(id)
);

-- User settings table
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

### Future: Cloud Sync

Architecture prepared for future cloud integration:
- Repository pattern abstracts data source
- Sync service layer can be added
- Conflict resolution strategy planned
- Options: Firebase, Supabase, custom backend

---

## UI/UX Design Principles

### Design Philosophy

1. **Content First** - The wisdom should be the hero, not the UI
2. **Calm Technology** - Reduce cognitive load, not add to it
3. **Intentional Whitespace** - Let thoughts breathe
4. **Subtle Guidance** - Clear affordances without shouting
5. **Delightful Details** - Micro-animations that feel natural

### Color Palette

```
Primary:     Warm Neutral (#5D5348) - Grounding, like aged paper
Accent:      Soft Gold (#C9A962) - Wisdom, highlight
Background:  Cream (#FAF8F5) - Easy on eyes, book-like
Surface:     White (#FFFFFF) - Cards and elevated elements
Text:        Charcoal (#2D2D2D) - Readable, not harsh
Subtle:      Warm Gray (#9B9389) - Secondary text
```

### Typography

- **Display/Headers:** Serif font (e.g., Lora, Merriweather) - Classic, literary feel
- **Body:** Sans-serif (e.g., Inter, Source Sans Pro) - Clean readability
- **Quotes:** Italic serif - Distinction for quoted material

### Key Screens

#### 1. Home Screen
```
┌─────────────────────────────────┐
│  ☰                    🔍        │
│                                 │
│  Good morning                   │
│                                 │
│  ┌─────────────────────────┐    │
│  │ "Today's Wisdom"        │    │
│  │                         │    │
│  │ [Random entry card]     │    │
│  │                         │    │
│  │          ↻ Shuffle      │    │
│  └─────────────────────────┘    │
│                                 │
│  Recent                    ──→  │
│  ┌─────┐ ┌─────┐ ┌─────┐       │
│  │     │ │     │ │     │       │
│  └─────┘ └─────┘ └─────┘       │
│                                 │
│  By Topic                  ──→  │
│  ┌─────────────────────────┐    │
│  │ Philosophy (12)         │    │
│  │ Literature (8)          │    │
│  │ Personal (24)           │    │
│  └─────────────────────────┘    │
│                                 │
│           [ + ]                 │
└─────────────────────────────────┘
```

#### 2. New Entry Screen
```
┌─────────────────────────────────┐
│  ✕           New Entry    Save  │
│─────────────────────────────────│
│                                 │
│  ┌─────────────────────────┐    │
│  │                         │    │
│  │  What wisdom would you  │    │
│  │  like to capture?       │    │
│  │                         │    │
│  │  [Text input area]      │    │
│  │                         │    │
│  │                         │    │
│  └─────────────────────────┘    │
│                                 │
│  Source (optional)              │
│  ┌─────────────────────────┐    │
│  │ Author or source...     │    │
│  └─────────────────────────┘    │
│                                 │
│  Tags                           │
│  ┌───────┐ ┌────────┐ ┌───┐    │
│  │ + Add │ │ wisdom │ │ ✕ │    │
│  └───────┘ └────────┘ └───┘    │
│                                 │
│  Category                       │
│  ┌─────────────────────────┐    │
│  │ Philosophy            ▼ │    │
│  └─────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

#### 3. Entry Detail Screen
```
┌─────────────────────────────────┐
│  ←                    ⋮  ★      │
│─────────────────────────────────│
│                                 │
│                                 │
│     "The unexamined life is     │
│      not worth living."         │
│                                 │
│              — Socrates         │
│                                 │
│                                 │
│  ┌─────────┐ ┌──────────────┐   │
│  │ wisdom  │ │ philosophy   │   │
│  └─────────┘ └──────────────┘   │
│                                 │
│  Added Dec 7, 2025              │
│  Viewed 12 times                │
│                                 │
│─────────────────────────────────│
│  Related                        │
│  ┌─────────────────────────┐    │
│  │ "Know thyself..."       │    │
│  └─────────────────────────┘    │
│  ┌─────────────────────────┐    │
│  │ "Wisdom begins in..."   │    │
│  └─────────────────────────┘    │
│                                 │
└─────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Foundation (MVP)
**Goal:** Working app with core functionality

- [ ] Project setup and configuration
- [ ] Database schema and models
- [ ] Basic entry CRUD operations
- [ ] Home screen with entry list
- [ ] New entry creation flow
- [ ] Entry detail view
- [ ] Basic tagging system
- [ ] Simple search functionality
- [ ] Light/Dark theme

**Deliverable:** Functional app for personal use

### Phase 2: Discovery & Organization
**Goal:** Enhanced browsing and random discovery

- [ ] Random entry feature
- [ ] Filter by tags/categories
- [ ] Sort options (date, views, etc.)
- [ ] Related entries algorithm
- [ ] Tag management screen
- [ ] Category management
- [ ] Improved search with filters

**Deliverable:** Full organization and discovery features

### Phase 3: Polish & Delight
**Goal:** Refined UX and visual polish

- [ ] Micro-animations and transitions
- [ ] Onboarding flow
- [ ] Daily wisdom notification
- [ ] Export/Import functionality
- [ ] Customizable home view
- [ ] Additional themes
- [ ] Accessibility improvements
- [ ] Performance optimization

**Deliverable:** Polished, delightful user experience

### Phase 4: Cloud & Sync (Future)
**Goal:** Multi-device access

- [ ] User authentication
- [ ] Cloud database setup
- [ ] Sync engine implementation
- [ ] Conflict resolution
- [ ] Offline-first architecture
- [ ] Sharing features

**Deliverable:** Cross-device synchronization

---

## Development Setup

### Prerequisites

```bash
# Install Flutter (latest stable)
# https://docs.flutter.dev/get-started/install

# Verify installation
flutter doctor

# Required: Android Studio or Xcode for mobile
# Required: Chrome for web development
```

### Project Initialization

```bash
# Create Flutter project
flutter create --org com.commonplacebook common_place_book
cd common_place_book

# Add dependencies
flutter pub add flutter_bloc
flutter pub add drift
flutter pub add drift_flutter
flutter pub add sqlite3_flutter_libs
flutter pub add path_provider
flutter pub add path
flutter pub add uuid
flutter pub add intl
flutter pub add go_router
flutter pub add shared_preferences
flutter pub add flutter_animate
flutter pub add google_fonts

# Dev dependencies
flutter pub add --dev drift_dev
flutter pub add --dev build_runner
flutter pub add --dev flutter_lints
```

### Running the App

```bash
# Run on connected device/emulator
flutter run

# Run on web
flutter run -d chrome

# Run on specific platform
flutter run -d ios
flutter run -d android
```

---

## Testing Strategy

### Unit Tests
- Repository layer tests
- BLoC/Cubit state tests
- Utility function tests

### Widget Tests
- Screen rendering tests
- User interaction tests
- Form validation tests

### Integration Tests
- End-to-end user flows
- Database operations
- Cross-feature interactions

---

## Success Metrics

1. **Ease of capture** - Time from thought to saved entry < 10 seconds
2. **Daily engagement** - Users return to read/add entries
3. **Discovery value** - Random feature resurfaces meaningful content
4. **Organization efficiency** - Users can find specific entries quickly

---

## Next Steps

1. **Initialize Flutter project** with proper structure
2. **Set up database** with Drift and create models
3. **Build entry creation** flow (core feature)
4. **Implement home screen** with entry list
5. **Add random discovery** feature
6. **Iterate on design** based on usage

---

*"A commonplace book is what a provident poet cannot subsist without, for this proverbial reason, that great wits have short memories."* — Jonathan Swift
