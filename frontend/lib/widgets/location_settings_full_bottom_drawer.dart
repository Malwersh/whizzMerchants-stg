import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/person_onboarding_service.dart';
import '../screens/merchant_location_picker_screen.dart';
import '../services/merchant_places_service.dart';
import 'package:flutter/material.dart';
import '../core/theme/whizz_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

import '../core/design_system/golden_ratio_constants.dart';
import '../core/design_system/typography_system.dart';

class LocationSettingsFullBottomDrawer extends ConsumerStatefulWidget {
  final Business business;
  final ApiService? api;
  final PersonOnboardingService? onboarding;
  final Future<MerchantLocation?> Function(MerchantLocation?)? pickLocation;

  const LocationSettingsFullBottomDrawer({
    super.key,
    required this.business,
    this.api,
    this.onboarding,
    this.pickLocation,
  });

  @override
  ConsumerState<LocationSettingsFullBottomDrawer> createState() =>
      _LocationSettingsFullBottomDrawerState();

  /// Static method to show the bottom drawer
  static Future<void> show({
    required BuildContext context,
    required Business business,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => LocationSettingsFullBottomDrawer(
        business: business,
      ),
    );
  }
}

class _LocationSettingsFullBottomDrawerState
    extends ConsumerState<LocationSettingsFullBottomDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();

  bool _isLoading = false;
  String? _feedback;
  bool _feedbackError = false;
  double? _latitude, _longitude;
  List<Map<String, dynamic>> _regions = [];
  List<String> _regionPath = [];
  String? _loadError;
  dynamic _locationVersion;

  double? _originalLatitude, _originalLongitude;
  List<String> _originalPath=[];
  String? _pendingId, _pendingSignature;
  bool get _hasSavedLocation => _originalLatitude != null &&
      _originalLongitude != null && _originalLatitude!.isFinite &&
      _originalLongitude!.isFinite && _originalLatitude!.abs() <= 90 &&
      _originalLongitude!.abs() <= 180;
  bool get _moved => _latitude!=_originalLatitude || _longitude!=_originalLongitude || jsonEncode(_regionPath)!=jsonEncode(_originalPath);

  @override
  void initState() {
    super.initState();
    _loadLocationSettings();
  }

  @override
  void dispose() {
    _streetController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final responses = await Future.wait([
        (widget.api ?? ApiService())
            .getBusinessLocationSettings(widget.business.id),
        (widget.onboarding ?? PersonOnboardingService())
            .call('onboarding-regions', authenticated: false),
      ]);
      final data = Map<String, dynamic>.from(responses[0]['settings']);
      if (!mounted) return;
      setState(() {
        _loadError = null;
        _regions = List<Map<String, dynamic>>.from(responses[1]['items']);
        _regionPath = List<String>.from(data['regionPath'] ?? []);
        _latitude = double.tryParse(data['latitude'].toString());
        _longitude = double.tryParse(data['longitude'].toString());
        _locationVersion = data['locationVersion'];
        _originalLatitude=_latitude; _originalLongitude=_longitude; _originalPath=List<String>.from(_regionPath);
        _streetController.text = data['address']?.toString() ?? '';
      });
    } catch (_) {
      if (mounted)
        setState(() => _loadError =
            'تعذر تحميل العنوان المحفوظ أو قائمة المناطق. أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLocation() async {
    final initial = _latitude != null && _longitude != null
        ? MerchantLocation(_latitude!, _longitude!) : null;
    final selected = widget.pickLocation != null
        ? await widget.pickLocation!(initial)
        : await Navigator.of(context).push<MerchantLocation>(
        MaterialPageRoute(
            builder: (_) => MerchantLocationPickerScreen(
                initial: _latitude != null && _longitude != null
                    ? MerchantLocation(_latitude!, _longitude!)
                    : null)));
    if (selected != null && mounted)
      setState(() {
        _feedback = null;
        _latitude = selected.latitude;
        _longitude = selected.longitude;
      });
  }

  Future<void> _saveLocationSettings() async {
    if (_isLoading || _loadError != null) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _feedback = null;
    });

    try {
      final apiService = widget.api ?? ApiService();

      // Create comprehensive location settings object
      if (_loadError != null ||
          _regionPath.length != 4 ||
          _latitude == null ||
          _longitude == null)
        throw Exception('أكمل المنطقة وحدد الموقع على الخريطة.');
      final settings = {
        'latitude': _latitude,
        'longitude': _longitude,
        'regionPath': List<String>.from(_regionPath),
        'locationVersion': _locationVersion,
        'address': _streetController.text.trim(),
      };

      if (_moved) {
        final text = await showDialog<String>(context: context,
          builder: (_) => _LocationReasonDialog(
            businessName: widget.business.name, hasSavedLocation: _hasSavedLocation));
        if (text == null || !mounted) return;
        setState(() => _isLoading = true);
        final proposed={'latitude':_latitude,'longitude':_longitude,'regionPath':List<String>.from(_regionPath),'address':_streetController.text.trim()};
        final signature=jsonEncode([proposed,text]);
        if(signature!=_pendingSignature){_pendingId=const Uuid().v4();_pendingSignature=signature;}
        await (widget.onboarding??PersonOnboardingService()).call('business-changes',body:{
          'businessId':widget.business.id,'requestId':_pendingId,'baseUpdatedAt':_locationVersion,
          'kind':'LOCATION','proposed':proposed,'reason':text});
      } else {
        setState(() => _isLoading = true);
        await apiService.updateBusinessLocationSettings(widget.business.id, settings);
      }

      if (mounted) setState(() {
        _feedbackError = false;
        _feedback = _moved
            ? (_hasSavedLocation
                ? 'تم إرسال طلب تعديل الموقع للمراجعة. الموقع المحفوظ لم يتغير بعد.'
                : 'تم إرسال الموقع الأول للمراجعة. لم يُعتمد بعد.')
            : 'تم حفظ عنوان وموقع هذا الفرع بنجاح.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _feedbackError = true;
        _feedback = 'لم يتم تأكيد الحفظ أو إرسال الطلب. ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(GoldenRatio.radiusXl),
          topRight: Radius.circular(GoldenRatio.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: GoldenRatio.spacing20,
            offset: Offset(0, -GoldenRatio.spacing8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: GoldenRatio.spacing12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WhizzColors.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(GoldenRatio.spacing24),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(GoldenRatio.spacing12),
                      decoration: BoxDecoration(
                        color: WhizzColors.secondary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(GoldenRatio.radiusMd),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: WhizzColors.secondary,
                        size: GoldenRatio.spacing24,
                      ),
                    ),
                    SizedBox(width: GoldenRatio.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('موقع الفرع (GPS)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(widget.business.name),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: WhizzColors.surfaceVariant,
                        foregroundColor: WhizzColors.onSurfaceVariant,
                      ),
                      icon: Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              // Content
              if (_isLoading)
                _buildLoadingState()
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    GoldenRatio.spacing24,
                    0,
                    GoldenRatio.spacing24,
                    GoldenRatio.spacing24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('هذه نقطة استلام الطلبات للفرع المحدد فقط. لكل فرع موقع مستقل؛ لا يؤثر التعديل على الفروع الأخرى.'),
                        const SizedBox(height: 12),
                        Text(_hasSavedLocation
                          ? 'يوجد موقع محفوظ لهذا الفرع. تعديل النقطة يُرسل للمراجعة ويبقى الموقع الحالي فعالاً حتى الموافقة.'
                          : 'هذا أول تحديد لموقع الفرع؛ يُرسل للمراجعة قبل اعتماده.'),
                        const SizedBox(height: 16),
                        // Business Address Section
                        _buildAddressSection(loc),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _pickLocation,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('تعديل الموقع على الخريطة'),
                        ),
                        if (_latitude != null && _longitude != null)
                          Text(
                              'الموقع المحدد: ${_latitude!.toStringAsFixed(7)}, ${_longitude!.toStringAsFixed(7)}',
                              textDirection: TextDirection.ltr),
                        SizedBox(height: GoldenRatio.spacing24),

                        // Keep the result beside the action rather than hiding it behind a closed sheet.
                        if (_feedback != null)
                          Padding(padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(liveRegion: true, child: Text(_feedback!,
                              style: TextStyle(color: _feedbackError ? Colors.red.shade800 : Colors.green.shade800,
                                fontWeight: FontWeight.w600)))),
                        _buildSaveButton(loc),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final loc = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.all(GoldenRatio.spacing24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: WhizzColors.primary,
              strokeWidth: 3,
            ),
            SizedBox(height: GoldenRatio.spacing16),
            Text(
              loc.loadingLocationSettings,
              style: TypographySystem.bodyLarge.copyWith(
                color: WhizzColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(AppLocalizations loc) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadError != null) ...[
            Text(_loadError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(
                onPressed: _loadLocationSettings,
                child: const Text('إعادة المحاولة')),
          ] else ...[
            for (var level = 0; level < 4; level++) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(
                    'location-region-$level-${_regionPath.take(level).join('-')}'),
                initialValue: _regionPath.length > level &&
                        _regions.any((r) =>
                            r['id'] == _regionPath[level] &&
                            r['level'] == level &&
                            (level == 0 ||
                                r['parentId'] == _regionPath[level - 1]))
                    ? _regionPath[level]
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
                  for (final region in _regions.where((r) =>
                      r['level'] == level &&
                      (level == 0 ||
                          (_regionPath.length >= level &&
                              r['parentId'] == _regionPath[level - 1]))))
                    DropdownMenuItem(
                        value: region['id'] as String,
                        child: Text(region['labelAr'] as String))
                ],
                validator: (value) => value == null
                    ? 'اختر ${const [
                        'البلد',
                        'المحافظة',
                        'القضاء',
                        'المنطقة أو الحي'
                      ][level]}'
                    : null,
                onChanged:
                    _isLoading || (level > 0 && _regionPath.length < level)
                        ? null
                        : (value) {
                            if (value == null ||
                                (_regionPath.length > level &&
                                    _regionPath[level] == value)) return;
                            setState(() {
                              _regionPath = [..._regionPath.take(level), value];
                              _latitude = null;
                              _longitude = null;
                            });
                          },
              ),
              const SizedBox(height: 16),
            ],
            _buildModernTextField(
                controller: _streetController,
                label: 'العنوان التفصيلي',
                icon: Icons.streetview,
                color: Colors.grey.shade600,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'أدخل العنوان التفصيلي'
                    : null),
          ],
        ],
      );

  Widget _buildSaveButton(AppLocalizations loc) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WhizzColors.primary,
            WhizzColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.primary.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: WhizzColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading || _loadError != null ? null : _saveLocationSettings,
          borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: GoldenRatio.spacing18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  SizedBox(
                    width: GoldenRatio.spacing20,
                    height: GoldenRatio.spacing20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: WhizzColors.secondary,
                    ),
                  ),
                  SizedBox(width: GoldenRatio.spacing12),
                ] else ...[
                  Icon(
                    Icons.save,
                    color: WhizzColors.secondary,
                    size: GoldenRatio.spacing20,
                  ),
                  SizedBox(width: GoldenRatio.spacing12),
                ],
                Flexible(child: Text(
                  _isLoading ? 'جارٍ الإرسال…' : (_moved ? (_hasSavedLocation ? 'طلب تعديل الموقع' : 'تحديد الموقع لأول مرة') : loc.saveLocationSettings),
                  textAlign: TextAlign.center,
                  style: TypographySystem.titleMedium.copyWith(
                    color: WhizzColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: WhizzColors.surface,
        borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
        border: Border.all(
          color: WhizzColors.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: WhizzColors.secondary.withValues(alpha: 0.08),
            blurRadius: GoldenRatio.spacing8,
            offset: Offset(0, GoldenRatio.spacing4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: TypographySystem.bodyLarge.copyWith(
          color: WhizzColors.onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: label,
          helperText: helperText,
          prefixIcon: Container(
            margin: EdgeInsets.all(GoldenRatio.spacing12),
            padding: EdgeInsets.all(GoldenRatio.spacing8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  WhizzColors.secondary.withValues(alpha: 0.1),
                  WhizzColors.secondary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(GoldenRatio.radiusMd),
              border: Border.all(
                color: WhizzColors.secondary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: WhizzColors.secondary,
              size: GoldenRatio.spacing20,
            ),
          ),
          filled: true,
          fillColor: WhizzColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.secondary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GoldenRatio.radiusLg),
            borderSide: BorderSide(
              color: WhizzColors.error,
              width: 2,
            ),
          ),
          labelStyle: TypographySystem.bodyMedium.copyWith(
            color: WhizzColors.secondary,
            fontWeight: FontWeight.w500,
          ),
          helperStyle: TypographySystem.bodySmall.copyWith(
            color: WhizzColors.onSurfaceVariant,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: GoldenRatio.spacing20,
            vertical: GoldenRatio.spacing16,
          ),
        ),
      ),
    );
  }
}

class _LocationReasonDialog extends StatefulWidget {
  final String businessName;
  final bool hasSavedLocation;
  const _LocationReasonDialog({required this.businessName, required this.hasSavedLocation});
  @override
  State<_LocationReasonDialog> createState() => _LocationReasonDialogState();
}
class _LocationReasonDialogState extends State<_LocationReasonDialog> {
  final form = GlobalKey<FormState>();
  late final reason = TextEditingController(
    text: widget.hasSavedLocation ? '' : 'تحديد موقع الفرع لأول مرة');
  @override
  void dispose() { reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.hasSavedLocation ? 'طلب تعديل موقع فرع ${widget.businessName}' : 'تحديد موقع الفرع لأول مرة'),
    content: SingleChildScrollView(child: Form(key: form, child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Text(widget.hasSavedLocation
          ? 'يوجد موقع محفوظ لهذا الفرع. يبقى فعالاً حتى اعتماد النقطة الجديدة.'
          : 'لا يوجد موقع محفوظ لهذا الفرع. يُرسل التحديد الأول للمراجعة قبل اعتماده.'),
        TextFormField(controller: reason, maxLength: 1000,
          validator: (value) => (value?.trim().length ?? 0) < 5
            ? 'اكتب سبباً من خمسة أحرف على الأقل.' : null,
          decoration: const InputDecoration(labelText: 'سبب تحديد أو تعديل الموقع')),
      ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        if (form.currentState!.validate()) Navigator.pop(context, reason.text.trim());
      }, child: const Text('إرسال للمراجعة')),
    ]);
}
