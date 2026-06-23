import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/discovery/presentation/screens/discovery_screen.dart';
import '../features/entries/presentation/screens/entry_detail_screen.dart';
import '../features/entries/presentation/screens/entry_form_screen.dart';
import '../features/entries/presentation/screens/home_screen.dart';
import '../features/settings/presentation/screens/privacy_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/tags/presentation/screens/tags_screen.dart';

/// Key for GoRouter's root navigator. Exposed so app-level overlays (e.g. the
/// first-run welcome dialog) can obtain a context that sits *below* the
/// navigator — `MaterialApp.router`'s `builder` context sits above it, where
/// `showDialog` cannot find a Navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Matches a URL sitting at the end of the shared text (optionally followed by
/// trailing whitespace). Chrome's "share selected text" appends the page URL
/// after the selection, so we lift it out of the quote and into the source.
final _trailingUrlPattern = RegExp(r'(https?://\S+)\s*$');

/// Strips a text-fragment directive (`:~:text=…`, the scroll-to-text anchor)
/// from a shared URL. Chrome's "share highlighted text" appends one to the page
/// URL, embedding the selected quote in the link itself — so without this the
/// quote ends up duplicated onto the end of the source field. Per the URL
/// fragment-directive spec, `:~:` always delimits the directive, so everything
/// from it onward is dropped; a now-empty `#` fragment is trimmed too.
String _stripFragmentDirective(String url) {
  final marker = url.indexOf(':~:');
  if (marker < 0) return url;
  final stripped = url.substring(0, marker);
  return stripped.endsWith('#')
      ? stripped.substring(0, stripped.length - 1)
      : stripped;
}

/// Computes the router's start location from an Android PWA "share target"
/// launch. The installed web app is registered as a share target in
/// web/manifest.json (method GET), so shared text arrives as query
/// parameters on [Uri.base]. With Flutter's default hash URL strategy these
/// params sit on the base URL (before the fragment), not in GoRouter's
/// location — so we read them here and deep-link into the new-entry form.
/// Returns '/' on non-web or when no shareable text was provided.
String _shareInitialLocation() =>
    kIsWeb ? (shareTargetLocation(Uri.base.queryParameters) ?? '/') : '/';

/// Builds the new-entry deep-link for a share-target launch from the raw query
/// [params] (`text`, `title`, `url`), or null when nothing shareable was sent.
///
/// Chrome appends the page URL to the end of the shared selection, so a
/// trailing URL is stripped out of the quote and used as the entry's source
/// (the "Author / source" field) instead of cluttering the content.
@visibleForTesting
String? shareTargetLocation(Map<String, String> params) {
  var text = params['text']?.trim() ?? '';
  final title = params['title']?.trim() ?? '';
  var url = _stripFragmentDirective(params['url']?.trim() ?? '');

  // Lift a trailing URL out of the selected text into the source field.
  final trailingMatch = _trailingUrlPattern.firstMatch(text);
  if (trailingMatch != null) {
    if (url.isEmpty) url = _stripFragmentDirective(trailingMatch.group(1)!);
    text = text.substring(0, trailingMatch.start).trimRight();
  }

  // The selected/shared text is the quote; fall back to title, then url.
  final content = text.isNotEmpty ? text : (title.isNotEmpty ? title : url);
  if (content.isEmpty) return null;

  // A shared page URL is a sensible source, unless it's all we had and already
  // became the content.
  final source = (url.isNotEmpty && url != content) ? url : '';
  return Uri(
    path: '/entry/new',
    queryParameters: {
      'content': content,
      if (source.isNotEmpty) 'source': source,
    },
  ).toString();
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: _shareInitialLocation(),
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/entry/new',
      name: 'newEntry',
      builder: (context, state) {
        final content = state.uri.queryParameters['content'];
        final source = state.uri.queryParameters['source'];
        return EntryFormScreen(
          initialContent: content,
          initialSource: source,
        );
      },
    ),
    GoRoute(
      path: '/entry/:id',
      name: 'entryDetail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EntryDetailScreen(entryId: id);
      },
    ),
    GoRoute(
      path: '/entry/:id/edit',
      name: 'editEntry',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EntryFormScreen(entryId: id);
      },
    ),
    GoRoute(
      path: '/discover',
      name: 'discover',
      builder: (context, state) {
        final dateParam = state.uri.queryParameters['date'];
        final tagsParam = state.uri.queryParameters['tags'];
        final dateMillis = dateParam != null ? int.tryParse(dateParam) : null;
        final centerDate = dateMillis != null
            ? DateTime.fromMillisecondsSinceEpoch(dateMillis)
            : null;
        final initialTagIds = (tagsParam == null || tagsParam.isEmpty)
            ? <String>{}
            : tagsParam.split(',').toSet();
        return DiscoveryScreen(
          initialTagIds: initialTagIds,
          centerDate: centerDate,
        );
      },
    ),
    GoRoute(
      path: '/tags',
      name: 'tags',
      builder: (context, state) => const TagsScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/privacy',
      name: 'privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
  ],
);
