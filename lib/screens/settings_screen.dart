import 'package:flutter/material.dart';

import '../main.dart' show AppScope;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = state.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l.settingsPrivacySection,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          SwitchListTile(
            title: Text(l.analyticsToggleTitle),
            subtitle: Text(l.analyticsToggleSubtitle),
            value: state.analyticsEnabled,
            onChanged: state.setAnalyticsEnabled,
          ),
        ],
      ),
    );
  }
}
