import 'dart:convert';
import 'package:flutter/material.dart';

class BranchOptionsEditor extends StatelessWidget {
  final List<Map<String, dynamic>> value;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final bool enabled;
  const BranchOptionsEditor(
      {super.key,
      required this.value,
      required this.onChanged,
      this.enabled = true});
  static int _sequence = 0;
  String _id() => 'opt_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
  void _change(void Function(List<dynamic>) edit) {
    final copy = jsonDecode(jsonEncode(value)) as List;
    edit(copy);
    onChanged(copy.map((v) => Map<String, dynamic>.from(v)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String t(String en, String arabic) => ar ? arabic : en;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('Branch options', 'خيارات الفرع'),
          style: Theme.of(context).textTheme.titleMedium),
      Text(t('Prices and availability apply to this branch only.',
          'الأسعار والتوفر خاصان بهذا الفرع فقط.')),
      for (var g = 0; g < value.length; g++)
        Card(
            key: ValueKey(value[g]['id']),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextFormField(
                    key: ValueKey('title_${value[g]['id']}'),
                    initialValue: value[g]['title'],
                    enabled: enabled,
                    decoration: InputDecoration(
                        labelText: t('Group name', 'اسم المجموعة')),
                    validator: (v) =>
                        v == null || v.trim().isEmpty || v.length > 150
                            ? t('Enter a group name (max 150 characters)',
                                'أدخل اسم المجموعة (150 حرفاً كحد أقصى)')
                            : null,
                    onChanged: (v) => _change((rows) => rows[g]['title'] = v)),
                CheckboxListTile(
                    title: Text(t('Selection required', 'الاختيار مطلوب')),
                    value: value[g]['required'] == true,
                    onChanged: enabled
                        ? (v) => _change((rows) => rows[g]['required'] = v)
                        : null),
                Row(children: [
                  Expanded(
                      child: Text(t(
                          'Maximum choices: ${value[g]['maxSelections']}',
                          'أقصى عدد للاختيارات: ${value[g]['maxSelections']}'))),
                  IconButton(
                      tooltip: t('Fewer choices', 'تقليل الاختيارات'),
                      icon: const Icon(Icons.remove),
                      onPressed: enabled && value[g]['maxSelections'] > 1
                          ? () => _change((rows) => rows[g]['maxSelections']--)
                          : null),
                  IconButton(
                      tooltip: t('More choices', 'زيادة الاختيارات'),
                      icon: const Icon(Icons.add),
                      onPressed: enabled &&
                              value[g]['maxSelections'] <
                                  (value[g]['options'] as List).length
                          ? () => _change((rows) => rows[g]['maxSelections']++)
                          : null),
                ]),
                for (var o = 0; o < (value[g]['options'] as List).length; o++)
                  Padding(
                      key: ValueKey(value[g]['options'][o]['id']),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(children: [
                        TextFormField(
                            key: ValueKey(
                                'name_${value[g]['options'][o]['id']}'),
                            initialValue: value[g]['options'][o]['name'],
                            enabled: enabled,
                            decoration: InputDecoration(
                                labelText: t('Option name', 'اسم الخيار')),
                            validator: (v) => v == null ||
                                    v.trim().isEmpty ||
                                    v.length > 150
                                ? t('Enter an option name', 'أدخل اسم الخيار')
                                : null,
                            onChanged: (v) => _change(
                                (rows) => rows[g]['options'][o]['name'] = v)),
                        TextFormField(
                            key: ValueKey(
                                'price_${value[g]['options'][o]['id']}'),
                            initialValue:
                                value[g]['options'][o]['extraPrice'].toString(),
                            enabled: enabled,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: t('Extra price (IQD)',
                                    'السعر الإضافي (د.ع)')),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              return n == null ||
                                      !n.isFinite ||
                                      n < 0 ||
                                      n > 1e9 ||
                                      !RegExp(r'^\d+(?:\.\d{1,3})?$')
                                          .hasMatch(v!)
                                  ? t('Enter a valid price; zero is allowed',
                                      'أدخل سعراً صالحاً؛ الصفر مسموح')
                                  : null;
                            },
                            onChanged: (v) => _change((rows) => rows[g]
                                    ['options'][o]['extraPrice'] =
                                double.tryParse(v) ?? -1)),
                        Row(children: [
                          Expanded(
                              child: SwitchListTile(
                                  title: Text(t('Available', 'متاح')),
                                  value: value[g]['options'][o]
                                          ['isAvailable'] ==
                                      true,
                                  onChanged: enabled
                                      ? (v) => _change((rows) => rows[g]
                                          ['options'][o]['isAvailable'] = v)
                                      : null)),
                          IconButton(
                              tooltip: t('Remove option', 'حذف الخيار'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: enabled &&
                                      (value[g]['options'] as List).length > 1
                                  ? () => _change((rows) {
                                        rows[g]['options'].removeAt(o);
                                        if (rows[g]['maxSelections'] >
                                            rows[g]['options'].length)
                                          rows[g]['maxSelections'] =
                                              rows[g]['options'].length;
                                      })
                                  : null),
                        ]),
                      ])),
                Row(children: [
                  Expanded(
                      child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: Text(t('Add option', 'إضافة خيار')),
                          onPressed: enabled &&
                                  (value[g]['options'] as List).length < 40
                              ? () => _change((rows) => rows[g]['options'].add({
                                    'id': _id(),
                                    'name': '',
                                    'extraPrice': 0,
                                    'isAvailable': true
                                  }))
                              : null)),
                  TextButton(
                      onPressed: enabled
                          ? () => _change((rows) => rows.removeAt(g))
                          : null,
                      child: Text(t('Remove group', 'حذف المجموعة'))),
                ]),
              ]),
            )),
      TextButton.icon(
          icon: const Icon(Icons.add),
          label: Text(t('Add option group', 'إضافة مجموعة خيارات')),
          onPressed: enabled && value.length < 20
              ? () => _change((rows) => rows.add({
                    'id': _id(),
                    'title': '',
                    'required': false,
                    'maxSelections': 1,
                    'options': [
                      {
                        'id': _id(),
                        'name': '',
                        'extraPrice': 0,
                        'isAvailable': true
                      }
                    ]
                  }))
              : null),
    ]);
  }
}
