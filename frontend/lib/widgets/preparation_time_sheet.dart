import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<int?> choosePreparationMinutes(BuildContext context, String businessId) async {
  final prefs = await SharedPreferences.getInstance();
  var selected = prefs.getInt('preparation_minutes_$businessId') ?? 20;
  if (!context.mounted) return null;
  return showModalBottomSheet<int>(context: context, isScrollControlled: true,
    showDragHandle: true, builder: (context) => StatefulBuilder(builder: (context, update) =>
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('متى يكون الطلب جاهزًا؟', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('يدخل وقت التحضير في تقدير وصول الطلب للزبون.'),
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: ([...{10,15,20,30,45,60,selected}]..sort()).map((minutes) => ChoiceChip(label: Text('$minutes دقيقة'), selected: selected == minutes, onSelected: (_) => update(() => selected = minutes))).toList()),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.pop(context, selected), child: Text('قبول الطلب • $selected دقيقة')),
      ])))));
}
Future<void> rememberPreparationMinutes(String businessId, int minutes) async {
  try { await (await SharedPreferences.getInstance()).setInt('preparation_minutes_$businessId', minutes); } catch (_) { /* Preference failure must not turn a committed acceptance into failure. */ }
}
