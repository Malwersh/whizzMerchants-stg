import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const returnConditionLabels = <String, String>{
  'SEALED_INTACT': 'مغلّف وسليم',
  'INTACT_NOT_RESALEABLE': 'سليم ظاهريًا — لا تصريح بإعادة تقديمه',
  'DAMAGED': 'تالف',
  'SPOILED': 'فساد أو خطر سلامة',
  'UNKNOWN': 'الحالة غير مؤكدة وتحتاج مراجعة',
  'MISSING': 'لم تُستلم أي وحدة',
};

class ReturnItemReceiptEditor extends StatefulWidget {
  final Map<String, dynamic> manifest;
  final bool enabled;
  final ValueChanged<List<Map<String, dynamic>>?> onChanged;
  const ReturnItemReceiptEditor(
      {super.key,
      required this.manifest,
      required this.enabled,
      required this.onChanged});
  @override
  State<ReturnItemReceiptEditor> createState() =>
      _ReturnItemReceiptEditorState();
}

class _ReturnItemReceiptEditorState extends State<ReturnItemReceiptEditor> {
  final drafts = <String, Map<String, dynamic>>{};
  late final lines = List<Map<String, dynamic>>.from(widget.manifest['lines']);
  void change(Map<String, dynamic> line, {String? qty, String? condition}) {
    final id = line['lineId'] as String;
    final draft = drafts.putIfAbsent(id, () => {'lineId': id});
    setState(() {
      if (qty != null) {
        draft['receivedQty'] = int.tryParse(qty);
        if (draft['receivedQty'] == 0) {
          draft['condition'] = 'MISSING';
        } else if (draft['condition'] == 'MISSING') {
          draft.remove('condition');
        }
      }
      if (condition != null) draft['condition'] = condition;
    });
    final valid = lines.every((line) {
      final d = drafts[line['lineId']], n = d?['receivedQty'];
      return n is int &&
          n >= 0 &&
          n <= (line['expectedQty'] as num) &&
          d?['condition'] != null;
    });
    widget.onChanged(valid
        ? lines
            .map((line) => Map<String, dynamic>.from(drafts[line['lineId']]!))
            .toList()
        : null);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مطابقة كميات المرتجع',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const Text(
            'سجّل ما استلمته فعليًا لكل صنف. الباقي عهدة غير محسومة؛ لا يثبت فقده أو مسؤولية السائق. استلام الطعام لا يصرح بإعادة تقديمه.'),
        for (final line in lines)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${line['name']} — المتوقع ${line['expectedQty']}'),
                        TextFormField(
                          key: ValueKey('return-qty-${line['lineId']}'),
                          enabled: widget.enabled,
                          decoration: InputDecoration(
                              labelText: 'الكمية المستلمة — ${line['name']}'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4)
                          ],
                          onChanged: (v) => change(line, qty: v),
                        ),
                        if (drafts[line['lineId']]?['receivedQty'] == 0)
                          const Text('لم تُستلم أي وحدة؛ تبقى الكمية للمراجعة')
                        else
                          DropdownButtonFormField<String>(
                            key: ValueKey('return-condition-${line['lineId']}'),
                            initialValue:
                                drafts[line['lineId']]?['condition'] as String?,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'حالة الوحدات المستلمة'),
                            items: returnConditionLabels.entries
                                .where((e) => e.key != 'MISSING')
                                .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: widget.enabled
                                ? (v) => change(line, condition: v)
                                : null,
                          ),
                      ]))),
      ]);
}

class ReturnItemReceiptSummary extends StatelessWidget {
  final Map<String, dynamic> receipt;
  const ReturnItemReceiptSummary({super.key, required this.receipt});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مطابقة الأصناف المحفوظة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final line
            in List<Map<String, dynamic>>.from(receipt['lines'] ?? []))
          ListTile(
              title: Text(line['name'] as String),
              subtitle: Text(
                  'استُلم ${line['receivedQty']} من ${line['expectedQty']} · غير محسوم ${line['unresolvedQty']}\n${returnConditionLabels[line['condition']] ?? 'تحتاج مراجعة'}')),
      ]);
}
