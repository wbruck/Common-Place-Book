# Common Place Book

A beautiful, minimalist digital commonplace book for storing and rediscovering golden nuggets of wisdom, quotes, and ideas.

## What is a Commonplace Book?

A commonplace book is a traditional method of compiling knowledge - a personal repository where one stores quotes, ideas, observations, and "golden nuggets of truth" organized by themes and categories for later reflection and retrieval.

## Features

- **Quick Capture** - Add new wisdom with minimal friction
- **Smart Organization** - Tags and categories keep your thoughts organized
- **Random Discovery** - Resurface forgotten gems with the "Rediscover" feature
- **Related Entries** - See connected ideas alongside each entry
- **Beautiful Design** - Clean, calming interface that lets your wisdom shine
- **Cross-Platform** - Available on iOS, Android, and Web

## Tech Stack

- **Framework:** Flutter
- **State Management:** BLoC/Cubit
- **Local Storage:** Drift (SQLite)
- **Architecture:** Clean Architecture with feature-based organization

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Android Studio / Xcode (for mobile development)
- Chrome (for web development)

### Installation

```bash
# Clone the repository
git clone https://github.com/wbruck/Common-Place-Book.git
cd Common-Place-Book

# Install dependencies
flutter pub get

# Run code generation (for Drift)
dart run build_runner build

# Run the app
flutter run
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── app/                   # App configuration and theming
├── features/              # Feature modules
│   ├── entries/           # Entry management
│   ├── tags/              # Tag management
│   ├── discovery/         # Random and related entries
│   └── settings/          # User preferences
├── core/                  # Core utilities and database
└── shared/                # Shared widgets and extensions
```

## Documentation

See [PROJECT_PLAN.md](./PROJECT_PLAN.md) for the complete project plan including:
- Detailed feature specifications
- UI/UX design guidelines
- Database schema
- Implementation phases

## Roadmap

- [ ] Phase 3: Polish & Delight
- [ ] Phase 4: Cloud & Sync

---

*"A commonplace book is what a provident poet cannot subsist without, for this proverbial reason, that great wits have short memories."* — Jonathan Swift
