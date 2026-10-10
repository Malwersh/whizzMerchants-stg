import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/business.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../core/design_system/design_system.dart';
import '../core/adaptive/adaptive_widgets.dart';
import '../widgets/kitchen_output_section.dart';

class PosSettingsPage extends ConsumerStatefulWidget {
  final Business business;

  const PosSettingsPage({super.key, required this.business});

  @override
  ConsumerState<PosSettingsPage> createState() => _PosSettingsPageState();
}

class _PosSettingsPageState extends ConsumerState<PosSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiEndpointController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _locationIdController = TextEditingController();

  bool _isLoading = false;
  bool _isEnabled = false;
  bool _testMode = false;
  bool _autoSendOrders = false;
  bool _autoAcceptOrders = true;
  String _systemType = 'genericApi';
  int _timeoutSeconds = 30;

  List<Map<String, String>> _getSystemTypes(AppLocalizations loc) => [
        {'value': 'genericApi', 'label': loc.genericApi},
        {'value': 'square', 'label': loc.squarePos},
        {'value': 'toast', 'label': loc.toastPos},
        {'value': 'clover', 'label': loc.clover},
        {'value': 'shopify', 'label': loc.shopify},
        {'value': 'woocommerce', 'label': loc.woocommerce},
  ];

  @override
  void initState() {
    super.initState();
    _loadPosSettings();
  }

  @override
  void dispose() {
    _apiEndpointController.dispose();
    _apiKeyController.dispose();
    _locationIdController.dispose();
    super.dispose();
  }

  Future<void> _loadPosSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      final settings = await apiService.getPosSettings(widget.business.id);
      
      if (mounted) {
        setState(() {
          _apiEndpointController.text = settings['apiEndpoint'] ?? '';
          _apiKeyController.text = settings['apiKey'] ?? '';
          _locationIdController.text = settings['locationId'] ?? '';
          _isEnabled = settings['enabled'] ?? false;
          _testMode = settings['testMode'] ?? false;
          _autoSendOrders = settings['autoSendOrders'] ?? false;
          _autoAcceptOrders = settings['autoAcceptOrders'] ?? true;
          _systemType = settings['systemType'] ?? 'genericApi';
          _timeoutSeconds = settings['timeoutSeconds'] ?? 30;
        });
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.failedToLoadPosSettings}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePosSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      final settings = {
        'apiEndpoint': _apiEndpointController.text,
        'apiKey': _apiKeyController.text,
        'locationId': _locationIdController.text,
        'enabled': _isEnabled,
        'testMode': _testMode,
        'autoSendOrders': _autoSendOrders,
        'autoAcceptOrders': _autoAcceptOrders,
        'systemType': _systemType,
        'timeoutSeconds': _timeoutSeconds,
      };

      await apiService.updatePosSettings(widget.business.id, settings);
      
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: loc.posSettingsSaved,
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.failedToSavePosSettings}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService();
      final testConfig = {
        'apiEndpoint': _apiEndpointController.text,
        'apiKey': _apiKeyController.text,
        'locationId': _locationIdController.text,
        'systemType': _systemType,
      };

      final result =
          await apiService.testPosConnection(widget.business.id, testConfig);
      
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        final isSuccess = result['success'] ?? false;
        showAdaptiveSnackBar(
          context: context,
          message: isSuccess
              ? loc.connectionTestSuccessful
              : '${loc.connectionTestFailed}: ${result['message'] ?? 'Unknown error'}',
          type: isSuccess
              ? AdaptiveSnackBarType.success
              : AdaptiveSnackBarType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        showAdaptiveSnackBar(
          context: context,
          message: '${loc.connectionTestFailed}: $e',
          type: AdaptiveSnackBarType.error,
        );
      }
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

    return Scaffold(
      backgroundColor: WhizzColors.grey50,
      appBar: AppBar(
        title: Text(loc.posSettings),
        backgroundColor: Colors.white,
        foregroundColor: WhizzColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _savePosSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: AdaptiveLoadingIndicator(),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kitchen printers / display: works without POS integration
                    const KitchenOutputSection(),
                    SizedBox(height: AppSpacing.md),

                    // Enable POS Integration
                    Card(
                      color: WhizzColors.white,
                      elevation: 2,
                      child: SwitchListTile(
                        title: Text(
                          loc.enablePosIntegrationTitle,
                          style: AppTypography.bodyLarge,
                        ),
                        subtitle: Text(
                          loc.enablePosIntegrationSubtitle,
                          style: AppTypography.bodyMedium.copyWith(
                            color: WhizzColors.textSecondary,
                          ),
                        ),
                        value: _isEnabled,
                        activeColor: WhizzColors.secondary,
                        onChanged: (value) {
                          setState(() {
                            _isEnabled = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),

                    if (_isEnabled) ...[
                      // System Type Dropdown
                      Card(
                        color: WhizzColors.white,
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: DropdownButtonFormField<String>(
                            value: _systemType,
                            decoration: InputDecoration(
                              labelText: loc.posSystemTypeLabel,
                              hintText: loc.selectPosSystemHint,
                              prefixIcon: Icon(Icons.computer,
                                  color: WhizzColors.secondary),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppDimensions.borderRadiusMD),
                              ),
                            ),
                            items: _getSystemTypes(loc).map((type) {
                              return DropdownMenuItem<String>(
                                value: type['value'],
                                child: Text(type['label']!),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _systemType = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),

                      // API Configuration Card
                      Card(
                        color: WhizzColors.white,
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.apiConfigurationTitle,
                                style: AppTypography.titleMedium.copyWith(
                                  color: WhizzColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: AppSpacing.sm),

                              // API Endpoint
                              TextFormField(
                                controller: _apiEndpointController,
                                decoration: InputDecoration(
                                  labelText: loc.apiEndpointLabel,
                                  hintText: loc.apiEndpointHint,
                                  prefixIcon: Icon(Icons.link,
                                      color: WhizzColors.secondary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusMD),
                                  ),
                                ),
                                validator: (value) {
                                  if (_isEnabled &&
                                      (value == null || value.isEmpty)) {
                                    return loc.apiEndpointRequired;
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: AppSpacing.md),

                              // API Key
                              TextFormField(
                                controller: _apiKeyController,
                                decoration: InputDecoration(
                                  labelText: loc.apiKeyLabel,
                                  hintText: loc.apiKeyHint,
                                  prefixIcon:
                                      Icon(Icons.key,
                                      color: WhizzColors.secondary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusMD),
                                  ),
                                ),
                                obscureText: true,
                                validator: (value) {
                                  if (_isEnabled &&
                                      (value == null || value.isEmpty)) {
                                    return loc.apiKeyRequired;
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: AppSpacing.md),

                              // Location ID (if applicable)
                              TextFormField(
                                controller: _locationIdController,
                                decoration: InputDecoration(
                                  labelText: loc.locationIdLabel,
                                  hintText: loc.locationIdHint,
                                  prefixIcon: Icon(Icons.location_on,
                                      color: WhizzColors.secondary),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusMD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg),

                      // Settings Card
                      Card(
                        color: WhizzColors.white,
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.posConfigurationTitle,
                                style: AppTypography.titleMedium.copyWith(
                                  color: WhizzColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: AppSpacing.sm),

                              // Test Mode Switch
                              SwitchListTile(
                                title: Text(
                                  loc.testModeTitle,
                                  style: AppTypography.bodyLarge,
                                ),
                                subtitle: Text(
                                  loc.testModeSubtitle,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: WhizzColors.textSecondary,
                                  ),
                                ),
                                value: _testMode,
                                activeColor: WhizzColors.secondary,
                                onChanged: (value) {
                                  setState(() {
                                    _testMode = value;
                                  });
                                },
                              ),

                              // Auto Send Orders
                              SwitchListTile(
                                title: Text(
                                  loc.autoSendOrdersTitle,
                                  style: AppTypography.bodyLarge,
                                ),
                                subtitle: Text(
                                  loc.autoSendOrdersSubtitle,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: WhizzColors.textSecondary,
                                  ),
                                ),
                                value: _autoSendOrders,
                                activeColor: WhizzColors.secondary,
                                onChanged: (value) {
                                  setState(() {
                                    _autoSendOrders = value;
                                  });
                                },
                              ),

                              // Auto Accept Orders
                              SwitchListTile(
                                title: Text(
                                  loc.autoAcceptOrdersTitle,
                                  style: AppTypography.bodyLarge,
                                ),
                                subtitle: Text(
                                  loc.autoAcceptOrdersSubtitle,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: WhizzColors.textSecondary,
                                  ),
                                ),
                                value: _autoAcceptOrders,
                                activeColor: WhizzColors.secondary,
                                onChanged: (value) {
                                  setState(() {
                                    _autoAcceptOrders = value;
                                  });
                                },
                              ),

                              // Timeout Settings
                              ListTile(
                                title: Text(
                                  loc.connectionTimeoutTitle,
                                  style: AppTypography.bodyLarge,
                                ),
                                subtitle: Text(
                                  loc.connectionTimeoutSubtitle(
                                      _timeoutSeconds),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: WhizzColors.textSecondary,
                                  ),
                                ),
                                trailing: SizedBox(
                                  width: 100,
                                  child: Slider(
                                    value: _timeoutSeconds.toDouble(),
                                    min: 10,
                                    max: 120,
                                    divisions: 11,
                                    label: '$_timeoutSeconds s',
                                    activeColor: WhizzColors.secondary,
                                    onChanged: (value) {
                                      setState(() {
                                        _timeoutSeconds = value.round();
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg),

                      // Action Buttons
                      Card(
                        color: WhizzColors.white,
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              // Test Connection Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _isLoading ? null : _testConnection,
                                  icon: Icon(Icons.wifi_protected_setup,
                                      color: WhizzColors.secondary),
                                  label: Text(
                                    loc.testConnectionButton,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: WhizzColors.secondary,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.md),
                                    side: BorderSide(
                                        color: WhizzColors.secondary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.borderRadiusMD),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: AppSpacing.md),

                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isLoading ? null : _savePosSettings,
                                  icon: Icon(Icons.save,
                                      color: WhizzColors.white),
                                  label: Text(
                                    loc.saveSettingsButton,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: WhizzColors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: WhizzColors.secondary,
                                    foregroundColor: WhizzColors.white,
                                    padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.md),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.borderRadiusMD),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
