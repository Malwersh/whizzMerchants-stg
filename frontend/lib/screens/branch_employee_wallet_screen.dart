import 'package:flutter/material.dart';
import 'branch_employee_statement_panel.dart';
import 'branch_employee_transfer_screen.dart';
import '../services/branch_employee_access.dart';
import '../services/branch_employee_wallet_service.dart';

class BranchEmployeeWalletScreen extends StatefulWidget {
  final BranchEmployeeAccess access;
  final BranchEmployeeWalletService? service;
  const BranchEmployeeWalletScreen(
      {super.key, required this.access, this.service});
  @override
  State<BranchEmployeeWalletScreen> createState() => _WalletState();
}

class _WalletState extends State<BranchEmployeeWalletScreen> {
  late final api = widget.service ?? BranchEmployeeWalletService();
  Map<String, dynamic>? balance;
  final transactions = <Map<String, dynamic>>[];
  String? cursor, error;
  bool busy = false, loaded = false;
  int generation = 0;
  @override
  void didUpdateWidget(covariant BranchEmployeeWalletScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.access, current = widget.access;
    if (old.businessId != current.businessId ||
        old.session != current.session ||
        old.token != current.token ||
        old.capabilities['readWalletBalance'] !=
            current.capabilities['readWalletBalance'] ||
        old.capabilities['readWalletTransactions'] !=
            current.capabilities['readWalletTransactions']) {
      generation++;
      balance = null;
      transactions.clear();
      cursor = null;
      busy = false;
      loaded = false;
      error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load(reset: true);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  Future<void> load({bool reset = false}) async {
    if (busy) return;
    final epoch = generation, access = widget.access;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      Map<String, dynamic>? nextBalance, history;
      if (reset && access.capabilities['readWalletBalance'] == true)
        nextBalance = await api.read(access, 'balance');
      if (!mounted || epoch != generation) return;
      if (access.capabilities['readWalletTransactions'] == true)
        history = await api.read(access, 'transactions',
            cursor: reset ? null : cursor);
      if (!mounted || epoch != generation) return;
      setState(() {
        if (reset) {
          balance = nextBalance;
          transactions.clear();
        }
        if (history != null) {
          transactions.addAll(
              List<Map<String, dynamic>>.from(history['transactions'] ?? []));
          cursor = history['nextCursor'];
        }
        loaded = true;
      });
    } catch (e) {
      if (mounted && epoch == generation)
        setState(() {
          error = e.toString();
          balance = null;
          transactions.clear();
          cursor = null;
        });
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('محفظة الفرع',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        TextButton.icon(
            onPressed: busy ? null : () => load(reset: true),
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث المحفظة')),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (widget.access.capabilities['transferFunds'] == true)
          FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BranchEmployeeTransferScreen(
                      initial: widget.access,
                      access: () => mounted ? widget.access : null))),
              child: const Text('تحويل الرصيد')),
        if (balance != null &&
            widget.access.capabilities['readWalletBalance'] == true)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'الرصيد المتاح: ${balance!['availableBalance']} د.ع'),
                        Text(
                            'الرصيد المحجوز: ${balance!['lockedBalance']} د.ع'),
                        if (balance!['status'] == 'SUSPENDED')
                          const Text('المحفظة معلّقة'),
                        Text(
                            'آخر قراءة: ${DateTime.tryParse(balance!['asOf'] ?? '')?.toLocal() ?? ''}'),
                      ]))),
        if (widget.access.capabilities['readSalesReports'] == true &&
            error == null)
          BranchEmployeeStatementPanel(
              access: widget.access, api: api, sales: true),
        if (error == null)
          BranchEmployeeStatementPanel(access: widget.access, api: api),
        if (widget.access.capabilities['readWalletTransactions'] == true) ...[
          const Text('الحركات المالية'),
          if (loaded &&
              !busy &&
              error == null &&
              transactions.isEmpty &&
              cursor == null)
            const Text('لا توجد حركات مالية.'),
          for (final entry in transactions)
            Card(
                child: ListTile(
                    title: Text('${entry['amount']} د.ع'),
                    subtitle: Text(
                        '${entry['description'] ?? ''}\n${entry['createdAt'] ?? entry['timestamp'] ?? ''}'))),
          if (cursor != null)
            TextButton(
                onPressed: busy ? null : load,
                child: const Text('المزيد من الحركات')),
        ],
      ]);
}
