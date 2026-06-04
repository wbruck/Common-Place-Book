import 'package:flutter/material.dart';

/// Shows the "About Common Place Book" dialog.
///
/// Used both from Settings (on demand) and as the one-time welcome shown on a
/// user's first visit, so the explanation of what a commonplace book is lives
/// in a single place. [dismissLabel] tailors the action button to how the
/// dialog was reached — "Close" from Settings, "Get started" for the welcome.
Future<void> showAboutCommonPlaceBookDialog(
  BuildContext context, {
  String dismissLabel = 'Close',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        AboutCommonPlaceBookDialog(dismissLabel: dismissLabel),
  );
}

/// The "About Common Place Book" content: what the app is and what a
/// commonplace book is, with the Jonathan Swift epigraph.
class AboutCommonPlaceBookDialog extends StatelessWidget {
  const AboutCommonPlaceBookDialog({
    this.dismissLabel = 'Close',
    super.key,
  });

  /// Label for the single action button that dismisses the dialog.
  final String dismissLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.auto_stories,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          const Text('Common Place Book'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A digital commonplace book for storing and rediscovering golden nuggets of wisdom, quotes, and ideas.',
          ),
          SizedBox(height: 16),
          Text(
            'A commonplace book is a traditional method of compiling knowledge - a personal repository where one stores quotes, ideas, and observations organized by themes for later reflection and retrieval.',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 16),
          Text(
            '"A commonplace book is what a provident poet cannot subsist without, for this proverbial reason, that great wits have short memories."',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
          Text(
            '— Jonathan Swift',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(dismissLabel),
        ),
      ],
    );
  }
}
