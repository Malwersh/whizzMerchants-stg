import '../widgets/iraqi_phone_field.dart';
import '../services/app_auth_service.dart';
import '../services/merchant_places_service.dart';
import 'merchant_location_picker_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../services/onboarding_config_service.dart';
import '../services/person_onboarding_service.dart';

class MerchantBranchDraftScreen extends StatefulWidget {
  final Map<String, dynamic>? draft;
  final PersonOnboardingService? service;
  final OnboardingConfigService? configService;
  const MerchantBranchDraftScreen(
      {super.key, this.draft, this.service, this.configService});
  @override
  State<MerchantBranchDraftScreen> createState() =>
      _MerchantBranchDraftScreenState();
}

class _MerchantBranchDraftScreenState extends State<MerchantBranchDraftScreen> {
  final _form = GlobalKey<FormState>();
  late final _api = widget.service ?? PersonOnboardingService();
  late final _configService = widget.configService ?? OnboardingConfigService();
  final _name = TextEditingController(),
      _address = TextEditingController(),
      _phone = TextEditingController(),
      _description = TextEditingController(),
      _latitude = TextEditingController(),
      _longitude = TextEditingController();
  Map<String, dynamic>? _draft;
  OnboardingConfig? _config;
  List<Map<String, dynamic>>? _regions;
  final List<String> _path = [];
  late List<Map<String, dynamic>> _hours;
  String? _type, _error;
  List<Map<String, dynamic>> _brands = [];
  String? _selectedBrand;
  bool _busy = false;
  int _typeRequest = 0;
  bool get _editable =>
      _draft == null ||
      ['DRAFT', 'NEEDS_INFORMATION', 'REJECTED']
          .contains(_draft!['reviewStatus']);
  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    final d = _draft ?? {};
    _name.text = d['name'] ?? '';
    _address.text = d['address'] ?? '';
    _phone.text = d['contactPhone'] ?? '';
    _description.text = d['description'] ?? '';
    _latitude.text = d['latitude']?.toString() ?? '';
    _longitude.text = d['longitude']?.toString() ?? '';
    _type = d['businessTypeId'];
    _path.addAll(List<String>.from(d['regionPath'] ?? []));
    _hours = d['openingHours'] is List
        ? List<Map<String, dynamic>>.from(d['openingHours'])
        : List.generate(
            7,
            (i) => {
                  'day': i,
                  'closed': true,
                  'periods': <Map<String, dynamic>>[]
                });
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _phone,
      _description,
      _latitude,
      _longitude
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait([_loadTypes(), _loadRegions(), _loadBrands()]);
  }

  Future<void> _loadBrands() async {
    try {
      final response = await _api.call('branch-drafts');
      final brands = <String, Map<String, dynamic>>{};
      for (final row
          in List<Map<String, dynamic>>.from(response['items'] ?? [])) {
        if (row['reviewStatus'] == 'APPROVED' &&
            row['brandId'] != null &&
            row['organizationId'] != null) {
          brands.putIfAbsent(row['brandId'] as String, () => row);
        }
      }
      if (mounted) setState(() => _brands = brands.values.toList());
    } catch (_) {
      // Existing drafts remain editable if this independent list fails to load.
    }
  }

  Future<void> _loadRegions() async {
    try {
      final r = await _api.call('onboarding-regions', authenticated: false);
      if (mounted)
        setState(() => _regions = List<Map<String, dynamic>>.from(r['items']));
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذر تحميل مناطق العمل. أعد المحاولة.');
    }
  }

  Future<void> _loadTypes() async {
    final request = ++_typeRequest;
    try {
      final c = await _configService.load(
          regionId: _path.length == 4 ? _path.last : null);
      if (mounted && request == _typeRequest) setState(() => _config = c);
    } catch (_) {
      if (mounted && request == _typeRequest)
        setState(() => _error = 'تعذر تحميل أنواع الأنشطة.');
    }
  }

  Future<void> _perform(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double? _coordinate(String s) => double.tryParse(s
      .replaceAllMapped(
          RegExp('[٠-٩]'), (m) => (m[0]!.codeUnitAt(0) - 1632).toString())
      .replaceAll('٫', '.')
      .trim());
  Future<Map<String, dynamic>> _persist() async {
    if (!_form.currentState!.validate())
      throw Exception('تحقق من البيانات المطلوبة.');
    final response = await _api.call('branch-drafts', body: {
      if (_draft != null) ...{
        'draftId': _draft!['draftId'],
        'baseVersion': _draft!['version']
      },
      if (_selectedBrand != null) ...{
        'brandId': _selectedBrand,
        'organizationId': _brands.firstWhere(
            (b) => b['brandId'] == _selectedBrand)['organizationId'],
      },
      'name': _name.text.trim(),
      'businessTypeId': _type,
      'address': _address.text.trim(),
      'contactPhone': _phone.text.trim().isEmpty
          ? ''
          : AppAuthService.normalizeIraqiPhone(_phone.text),
      'description': _description.text.trim(),
      'regionPath': List<String>.from(_path),
      'openingHours': _hours,
      'latitude': _coordinate(_latitude.text),
      'longitude': _coordinate(_longitude.text),
      'registrationCertificateAssetId':
          _draft?['registrationCertificateAssetId'],
      'businessPhotoAssetId': _draft?['businessPhotoAssetId']
    });
    final saved = Map<String, dynamic>.from(response['draft']);
    if (mounted) setState(() => _draft = saved);
    return saved;
  }

  Future<bool> _confirm(String title, String text, String accept) async {
    if (!mounted) return false;
    return await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                    title: Text(title),
                    content: SingleChildScrollView(child: Text(text)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: Text(accept))
                    ])) ??
        false;
  }

  Future<void> _submit() async {
    await _perform(() async {
      if (_path.length != 4 ||
          _coordinate(_latitude.text) == null ||
          _coordinate(_longitude.text) == null ||
          _address.text.trim().isEmpty ||
          _hours.every((r) => r['closed'] == true))
        throw Exception(
            'أكمل منطقة العمل والموقع والعنوان وساعات العمل قبل التقديم.');
      var draft = await _persist();
      var config =
          await _api.call('branch-drafts/config?draftId=${draft['draftId']}');
      if (config['updateAvailable'] == true) {
        final yes = await _confirm(
            'تحديث متطلبات التقديم',
            'توجد نسخة أحدث لإعدادات التسجيل والاتفاقية. ستُحفظ بيانات المسودة، ثم يعرض نص الاتفاقية قبل التقديم.',
            'تحديث المسودة');
        if (!yes) return;
        final response = await _api.call('branch-drafts/rebase', body: {
          'draftId': draft['draftId'],
          'baseVersion': draft['version'],
          'targetConfigVersion': config['currentConfigVersion']
        });
        draft = Map<String, dynamic>.from(response['draft']);
        if (mounted) setState(() => _draft = draft);
        config =
            await _api.call('branch-drafts/config?draftId=${draft['draftId']}');
      }
      if (config['partnershipReady'] != true)
        throw Exception(
            'اتفاقية الشراكة غير جاهزة حاليًا. حُفظت مسودتك لتكمل التقديم لاحقًا.');
      if (!await _confirm('اتفاقية الشراكة',
          config['agreementTextAr'] as String, 'أوافق وأقدّم للمراجعة')) return;
      await _api.call('branch-drafts/submit', body: {
        'draftId': draft['draftId'],
        'baseVersion': draft['version'],
        'agreementVersion': config['agreementVersion']
      });
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _upload(String kind) async {
    // Save and validate before opening the picker so a selected photo cannot
    // look attached when the unfinished draft prevented uploading it.
    Map<String, dynamic>? savedDraft;
    await _perform(() async { savedDraft = await _persist(); });
    if (savedDraft == null || !mounted) return;
    final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000);
    if (selected == null) return;
    await _perform(() async {
      final bytes = await selected.readAsBytes();
      if (bytes.length > 3 * 1024 * 1024)
        throw Exception('الحد الأقصى للمرفق 3 ميغابايت.');
      final png = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80;
      final jpeg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216;
      if (!png && !jpeg) throw Exception('اختر صورة JPEG أو PNG.');
      final draft = savedDraft!;
      final result = await _api.call('branch-assets', body: {
        'draftId': draft['draftId'],
        'assetId': const Uuid().v4(),
        'kind': kind,
        'contentType': png ? 'image/png' : 'image/jpeg',
        'base64Data': base64Encode(bytes)
      });
      if (mounted)
        setState(() => _draft = Map<String, dynamic>.from(result['draft']));
    });
  }

  Future<void> _preview(String id) async {
    await _perform(() async {
      final file = await _api.call('branch-assets?assetId=$id');
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
                  title: const Text('المرفق الخاص'),
                  content: Image.network(file['url'] as String,
                      errorBuilder: (_, __, ___) => const Text(
                          'تعذر عرض المرفق. أعد فتحه لتجديد الرابط.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('إغلاق'))
                  ]));
    });
  }

  Widget _asset(String field, String kind, String label) {
    final id = _draft?[field];
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('JPEG أو PNG، حتى 3 ميغابايت'),
                  if (id != null)
                    TextButton(
                        onPressed: _busy ? null : () => _preview(id as String),
                        child: const Text('عرض المرفق')),
                  if (_editable)
                    Wrap(children: [
                      TextButton(
                          onPressed: _busy ? null : () => _upload(kind),
                          child: Text(
                              id == null ? 'إرفاق صورة' : 'استبدال المرفق')),
                      if (id != null)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => _perform(() async {
                                      final previous = _draft;
                                      setState(() =>
                                          _draft = {..._draft!, field: null});
                                      try {
                                        await _persist();
                                      } catch (_) {
                                        if (mounted)
                                          setState(() => _draft = previous);
                                        rethrow;
                                      }
                                    }),
                            child: const Text('إزالة المرفق'))
                    ])
                ])));
  }

  Future<void> _map() async {
    final lat = _coordinate(_latitude.text), lng = _coordinate(_longitude.text);
    final selected = await Navigator.push<MerchantLocation>(
        context,
        MaterialPageRoute(
            builder: (_) => MerchantLocationPickerScreen(
                initial: lat != null && lng != null
                    ? MerchantLocation(lat, lng)
                    : null)));
    if (selected != null && mounted)
      setState(() {
        _latitude.text = selected.latitude.toStringAsFixed(7);
        _longitude.text = selected.longitude.toStringAsFixed(7);
        if (_address.text.trim().isEmpty && selected.address != null)
          _address.text = selected.address!;
      });
  }

  Future<void> _gps() async {
    await _perform(() async {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception('اسمح بالوصول إلى الموقع أو حدد النقطة على الخريطة.');
      final p = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 20));
      if (mounted)
        setState(() {
          _latitude.text = p.latitude.toStringAsFixed(7);
          _longitude.text = p.longitude.toStringAsFixed(7);
        });
    });
  }

  Future<void> _time(int day, String field) async {
    final periods = List<Map<String, dynamic>>.from(_hours[day]['periods']);
    final current = (periods.first[field] as String).split(':');
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: int.parse(current[0]), minute: int.parse(current[1])));
    if (time != null)
      setState(() {
        periods.first[field] =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        _hours[day]['periods'] = periods;
      });
  }

  Widget _field(TextEditingController c, String label,
          {bool required = false, int lines = 1, TextInputType? keyboard}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: c,
              enabled: _editable && !_busy,
              keyboardType: keyboard,
              maxLines: lines,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
              validator: required
                  ? ((v) =>
                      v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null)
                  : null));
  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
          appBar: AppBar(
              title:
                  Text(_editable ? 'إعداد النشاط والفرع' : 'حالة طلب النشاط')),
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_editable)
                          Text('الحالة: ${_draft!['reviewStatus']}'),
                        if (_draft?['review']?['reason'] != null)
                          Text(
                              'ملاحظات المراجعة: ${_draft!['review']['reason']}'),
                        const Text(
                            'يمكن حفظ المسودة واستكمالها لاحقًا. لا يستقبل الفرع طلبات قبل مراجعته وتجهيزه.'),
                        const SizedBox(height: 24),
                        if (_draft == null && _brands.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBrand ?? '',
                            decoration: const InputDecoration(
                                labelText: 'العلامة التجارية'),
                            items: [
                              const DropdownMenuItem(
                                  value: '', child: Text('إنشاء علامة جديدة')),
                              ..._brands.map((b) => DropdownMenuItem(
                                  value: b['brandId'] as String,
                                  child: Text('فرع جديد — ${b['name']}'))),
                            ],
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _selectedBrand =
                                    value == '' ? null : value),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _field(_name, 'اسم النشاط أو الفرع', required: true),
                        if (_regions == null)
                          TextButton(
                              onPressed: _loadRegions,
                              child: const Text('إعادة تحميل المناطق'))
                        else
                          for (var level = 0; level < 4; level++) ...[
                            DropdownButtonFormField<String>(
                                key: ValueKey(
                                    'region-$level-${_path.take(level).join('-')}'),
                                initialValue: _path.length > level &&
                                        _regions!.any((r) =>
                                            r['id'] == _path[level] &&
                                            r['level'] == level &&
                                            (level == 0 ||
                                                r['parentId'] ==
                                                    _path[level - 1]))
                                    ? _path[level]
                                    : null,
                                decoration: InputDecoration(
                                    labelText: const [
                                      'البلد',
                                      'المحافظة',
                                      'القضاء',
                                      'المنطقة أو الحي'
                                    ][level],
                                    border: const OutlineInputBorder()),
                                items: [
                                  for (final r in _regions!.where((r) =>
                                      r['level'] == level &&
                                      (level == 0 ||
                                          (_path.length >= level &&
                                              r['parentId'] ==
                                                  _path[level - 1]))))
                                    DropdownMenuItem(
                                        value: r['id'] as String,
                                        child: Text(r['labelAr'] as String))
                                ],
                                onChanged: !_editable ||
                                        _busy ||
                                        (level > 0 && _path.length < level)
                                    ? null
                                    : (v) {
                                        if (v == null) return;
                                        setState(() {
                                          if (_path.length > level)
                                            _path.removeRange(
                                                level, _path.length);
                                          _path.add(v);
                                          _latitude.clear();
                                          _longitude.clear();
                                        });
                                        _loadTypes();
                                      }),
                            const SizedBox(height: 16)
                          ],
                        if (_config == null)
                          TextButton(
                              onPressed: _loadTypes,
                              child: const Text('تحميل أنواع الأنشطة'))
                        else ...[
                          DropdownButtonFormField<String>(
                              key: ValueKey(
                                  'type-${_config!.configVersion}-${_path.join('-')}'),
                              initialValue: _type,
                              decoration: const InputDecoration(
                                  labelText: 'نوع النشاط',
                                  border: OutlineInputBorder()),
                              items: [
                                for (final t in _config!.types)
                                  DropdownMenuItem(
                                      value: t['id'] as String,
                                      child: Text(t['labelAr'] as String)),
                                if (_type != null &&
                                    !_config!.types
                                        .any((t) => t['id'] == _type))
                                  DropdownMenuItem(
                                      value: _type,
                                      child: const Text(
                                          'النوع المحفوظ — غير متاح للتسجيل الجديد'))
                              ],
                              onChanged: _busy || !_editable
                                  ? null
                                  : (v) => setState(() => _type = v),
                              validator: (_) =>
                                  _type == null ? 'اختر نوع النشاط' : null),
                          const SizedBox(height: 16)
                        ],
                        _field(_address, 'العنوان التفصيلي', lines: 2),
                        IraqiPhoneField(
                            controller: _phone, enabled: _editable && !_busy),
                        _field(_description, 'الوصف — اختياري', lines: 3),
                        if (_editable)
                          Wrap(spacing: 12, children: [
                            OutlinedButton.icon(
                                onPressed: _busy ? null : _map,
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('تحديد الموقع على الخريطة')),
                            TextButton(
                                onPressed: _busy ? null : _gps,
                                child: const Text('موقعي الحالي'))
                          ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: _field(_latitude, 'خط العرض',
                                  keyboard:
                                      const TextInputType.numberWithOptions(
                                          decimal: true, signed: true))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _field(_longitude, 'خط الطول',
                                  keyboard:
                                      const TextInputType.numberWithOptions(
                                          decimal: true, signed: true)))
                        ]),
                        _asset(
                            'registrationCertificateAssetId',
                            'REGISTRATION_CERTIFICATE',
                            'شهادة التسجيل — اختياري'),
                        _asset('businessPhotoAssetId', 'BUSINESS_PHOTO',
                            'صورة النشاط — اختياري'),
                        const Text('ساعات العمل',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        for (var day = 0; day < 7; day++)
                          Card(
                              child: Column(children: [
                            SwitchListTile(
                                title: Text(const [
                                  'الأحد',
                                  'الاثنين',
                                  'الثلاثاء',
                                  'الأربعاء',
                                  'الخميس',
                                  'الجمعة',
                                  'السبت'
                                ][day]),
                                subtitle: Text(_hours[day]['closed'] == true
                                    ? 'مغلق'
                                    : 'مفتوح'),
                                value: _hours[day]['closed'] != true,
                                onChanged: !_editable || _busy
                                    ? null
                                    : (open) => setState(() => _hours[day] = {
                                          'day': day,
                                          'closed': !open,
                                          'periods': open
                                              ? [
                                                  {
                                                    'open': '09:00',
                                                    'close': '23:00'
                                                  }
                                                ]
                                              : <Map<String, dynamic>>[]
                                        })),
                            if (_hours[day]['closed'] != true)
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    for (final field in ['open', 'close'])
                                      TextButton(
                                          onPressed: _editable && !_busy
                                              ? () => _time(day, field)
                                              : null,
                                          child: Text(
                                              '${field == 'open' ? 'من' : 'إلى'} ${_hours[day]['periods'][0][field]}'))
                                  ])
                          ])),
                        const SizedBox(height: 20),
                        if (_editable) ...[
                          FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _perform(() async {
                                        await _persist();
                                        if (mounted)
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text('حُفظت المسودة.')));
                                      }),
                              child:
                                  Text(_busy ? 'جارٍ الحفظ…' : 'حفظ المسودة')),
                          const SizedBox(height: 12),
                          OutlinedButton(
                              onPressed: _busy ? null : _submit,
                              child: const Text(
                                  'متابعة إلى الاتفاقية وتقديم للمراجعة'))
                        ],
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                      ])))));
}
