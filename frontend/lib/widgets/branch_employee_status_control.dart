import 'package:flutter/material.dart';
import '../services/branch_employee_access.dart';
import '../services/branch_device_service.dart';

/// Uses the branch's existing acceptingOrders state with individual device access.
class BranchEmployeeStatusControl extends StatefulWidget {
  final BranchEmployeeAccess access;
  const BranchEmployeeStatusControl({super.key, required this.access});
  @override
  State<BranchEmployeeStatusControl> createState() =>
      _BranchEmployeeStatusControlState();
}

class _BranchEmployeeStatusControlState
    extends State<BranchEmployeeStatusControl> {
  Map<String, dynamic>? _status;
  bool _busy = false;
  int _generation = 0;
  bool get _allowed => widget.access.capabilities['editStatus'] == true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BranchEmployeeStatusControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.access, current = widget.access;
    if (old.token != current.token ||
        old.session != current.session ||
        old.businessId != current.businessId ||
        old.capabilities['editStatus'] != current.capabilities['editStatus']) {
      _generation++;
      _status = null;
      _busy = false;
      _load();
    }
  }

  Future<void> _load({bool? accepting}) async {
    if (!_allowed || _busy) return;
    final access = widget.access, generation = ++_generation;
    setState(() => _busy = true);
    try {
      final result = await access.api.call(
          access.token,
          {
            'action': accepting == null ? 'read_status' : 'set_status',
            if (accepting != null) ...{
              'acceptingOrders': accepting,
              'baseRevision': _status!['revision'],
            },
          },
          session: access.session);
      if (!mounted || generation != _generation || !_allowed) return;
      if (result['businessId'] != access.businessId ||
          result['acceptingOrders'] is! bool ||
          result['revision'] is! String) {
        throw StateError('Invalid branch status');
      }
      setState(() => _status = result);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      // A timeout may follow a committed write. Require a fresh read before retry.
      setState(() => _status = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is BranchDeviceException
              ? error.toString()
              : 'تعذر تأكيد حالة الاستقبال. حدّث الحالة ثم حاول مجددًا.')));
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    if (_busy) {
      return const SizedBox(
          width: 36,
          height: 24,
          child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (_status == null) {
      return IconButton(
          tooltip: 'تحديث حالة الاستقبال',
          onPressed: _load,
          icon: const Icon(Icons.refresh));
    }
    final accepting = _status!['acceptingOrders'] == true;
    return Tooltip(
      message: accepting ? 'استقبال الطلبات متصل' : 'استقبال الطلبات غير متصل',
      child: Switch(
          value: accepting, onChanged: (value) => _load(accepting: value)),
    );
  }
}
