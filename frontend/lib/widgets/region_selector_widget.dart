// WizzMerchant - Region Selector Widget with Validation
// Uses Central Platform API for region validation

import 'package:flutter/material.dart';
import '../models/region.dart';
import '../services/region_service.dart';
import '../core/design_system/design_system.dart';
import '../l10n/app_localizations.dart';

class RegionSelectorWidget extends StatefulWidget {
  final Function(Region? governorate, Region? district, Region? neighborhood)
      onRegionSelected;
  final Region? initialGovernorate;
  final Region? initialDistrict;
  final Region? initialNeighborhood;
  final bool isRequired;

  const RegionSelectorWidget({
    Key? key,
    required this.onRegionSelected,
    this.initialGovernorate,
    this.initialDistrict,
    this.initialNeighborhood,
    this.isRequired = true,
  }) : super(key: key);

  @override
  State<RegionSelectorWidget> createState() => _RegionSelectorWidgetState();
}

class _RegionSelectorWidgetState extends State<RegionSelectorWidget> {
  final RegionService _regionService = RegionService();

  // Selected regions
  Region? _selectedGovernorate;
  Region? _selectedDistrict;
  Region? _selectedNeighborhood;

  // Available options
  List<Region> _governorates = [];
  List<Region> _districts = [];
  List<Region> _neighborhoods = [];

  // Loading states
  bool _isLoadingGovernorates = true;
  bool _isLoadingDistricts = false;
  bool _isLoadingNeighborhoods = false;

  // Error states removed - using Mapbox Address Autofill as primary method

  @override
  void initState() {
    super.initState();
    _initializeRegions();
  }

  @override
  void didUpdateWidget(RegionSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if initial values changed from parent (e.g., from Google Places selection)
    if (widget.initialGovernorate != oldWidget.initialGovernorate ||
        widget.initialDistrict != oldWidget.initialDistrict ||
        widget.initialNeighborhood != oldWidget.initialNeighborhood) {
      // Update governorate if changed
      if (widget.initialGovernorate != null &&
          widget.initialGovernorate != _selectedGovernorate) {
        _onGovernorateSelected(widget.initialGovernorate!);
      }

      // Update district if changed (after governorate is set)
      if (widget.initialDistrict != null &&
          widget.initialDistrict != _selectedDistrict &&
          _districts
              .any((d) => d.regionId == widget.initialDistrict!.regionId)) {
        _onDistrictSelected(widget.initialDistrict!);
      }

      // Update neighborhood if changed (after district is set)
      if (widget.initialNeighborhood != null &&
          widget.initialNeighborhood != _selectedNeighborhood &&
          _neighborhoods
              .any((n) => n.regionId == widget.initialNeighborhood!.regionId)) {
        _onNeighborhoodSelected(widget.initialNeighborhood!);
      }
    }
  }

  Future<void> _initializeRegions() async {
    setState(() {
      _isLoadingGovernorates = true;
      // _errorMessage removed - using Mapbox as primary
    });

    try {
      // Load active governorates (PROVINCE type)
      final activeRegions = await _regionService.getActiveRegions();
      final governorates =
          activeRegions.where((r) => r.regionType == 'PROVINCE').toList();

      // Sort alphabetically by Arabic name
      governorates.sort((a, b) => a.nameAr.compareTo(b.nameAr));

      setState(() {
        _governorates = governorates;
        _isLoadingGovernorates = false;
      });

      // If initial values provided, set them
      if (widget.initialGovernorate != null) {
        _onGovernorateSelected(widget.initialGovernorate!);
      }
    } catch (e) {
      // Silently fail - Mapbox Address Autofill is the primary method
      // Region selector is optional fallback, no need to show error
      setState(() {
        _isLoadingGovernorates = false;
        // _errorMessage removed - using Mapbox as primary address method
      });
    }
  }

  Future<void> _onGovernorateSelected(Region governorate) async {
    setState(() {
      _selectedGovernorate = governorate;
      _selectedDistrict = null;
      _selectedNeighborhood = null;
      _districts = [];
      _neighborhoods = [];
      _isLoadingDistricts = true;
    });

    try {
      // Load districts for selected governorate
      final activeRegions = await _regionService.getActiveRegions();
      final districts = activeRegions
          .where((r) =>
              r.regionType == 'DISTRICT' && r.parentId == governorate.regionId)
          .toList();

      // Sort alphabetically
      districts.sort((a, b) => a.nameAr.compareTo(b.nameAr));

      setState(() {
        _districts = districts;
        _isLoadingDistricts = false;
      });

      // Notify parent
      widget.onRegionSelected(_selectedGovernorate, null, null);

      // If initial district provided, set it
      if (widget.initialDistrict != null &&
          districts
              .any((d) => d.regionId == widget.initialDistrict!.regionId)) {
        _onDistrictSelected(widget.initialDistrict!);
      }
    } catch (e) {
      setState(() {
        _isLoadingDistricts = false;
      });
    }
  }

  Future<void> _onDistrictSelected(Region district) async {
    setState(() {
      _selectedDistrict = district;
      _selectedNeighborhood = null;
      _neighborhoods = [];
      _isLoadingNeighborhoods = true;
    });

    try {
      // Load neighborhoods for selected district
      final activeRegions = await _regionService.getActiveRegions();
      final neighborhoods = activeRegions
          .where((r) =>
              r.regionType == 'NEIGHBORHOOD' && r.parentId == district.regionId)
          .toList();

      // Sort alphabetically
      neighborhoods.sort((a, b) => a.nameAr.compareTo(b.nameAr));

      setState(() {
        _neighborhoods = neighborhoods;
        _isLoadingNeighborhoods = false;
      });

      // Notify parent
      widget.onRegionSelected(_selectedGovernorate, _selectedDistrict, null);

      // If initial neighborhood provided, set it
      if (widget.initialNeighborhood != null &&
          neighborhoods
              .any((n) => n.regionId == widget.initialNeighborhood!.regionId)) {
        _onNeighborhoodSelected(widget.initialNeighborhood!);
      }
    } catch (e) {
      setState(() {
        _isLoadingNeighborhoods = false;
      });
    }
  }

  void _onNeighborhoodSelected(Region neighborhood) {
    setState(() {
      _selectedNeighborhood = neighborhood;
    });

    // Notify parent with complete selection
    widget.onRegionSelected(
        _selectedGovernorate, _selectedDistrict, _selectedNeighborhood);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Hide error message - using Mapbox Address Autofill as primary method
    // Region selector is now optional fallback
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Governorate Dropdown
        _buildGovernorateDropdown(loc),
        SizedBox(height: AppSpacing.md),

        // District Dropdown (enabled only if governorate selected)
        _buildDistrictDropdown(loc),
        SizedBox(height: AppSpacing.md),

        // Neighborhood Dropdown (enabled only if district selected)
        _buildNeighborhoodDropdown(loc),

        // Info message for inactive regions
        if (_selectedGovernorate != null &&
            _districts.isEmpty &&
            !_isLoadingDistricts)
          _buildNoActiveRegionsMessage(loc.noDistrictsAvailable),

        if (_selectedDistrict != null &&
            _neighborhoods.isEmpty &&
            !_isLoadingNeighborhoods)
          _buildNoActiveRegionsMessage(loc.noNeighborhoodsAvailable),
      ],
    );
  }

  Widget _buildGovernorateDropdown(AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedGovernorate != null
              ? const Color(0xFF4CAF50)
              : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonFormField<Region>(
        value: _selectedGovernorate,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '${loc.governorate}${widget.isRequired ? " *" : ""}',
          prefixIcon: Icon(
            Icons.location_city,
            color: _selectedGovernorate != null
                ? const Color(0xFF4CAF50)
                : Colors.grey[600],
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        items: _isLoadingGovernorates
            ? []
            : _governorates.map((governorate) {
                return DropdownMenuItem<Region>(
                  value: governorate,
                  child: Text(
                    governorate.nameAr,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
        onChanged: _isLoadingGovernorates
            ? null
            : (Region? value) {
                if (value != null) {
                  _onGovernorateSelected(value);
                }
              },
        validator: widget.isRequired
            ? (value) => value == null ? loc.pleaseSelectGovernorate : null
            : null,
        hint: _isLoadingGovernorates
            ? Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(loc.loading),
                ],
              )
            : Text(loc.selectGovernorate),
      ),
    );
  }

  Widget _buildDistrictDropdown(AppLocalizations loc) {
    final isEnabled = _selectedGovernorate != null && !_isLoadingDistricts;

    return Container(
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedDistrict != null
              ? const Color(0xFF4CAF50)
              : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonFormField<Region>(
        value: _selectedDistrict,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '${loc.district}${widget.isRequired ? " *" : ""}',
          prefixIcon: Icon(
            Icons.map,
            color: _selectedDistrict != null
                ? const Color(0xFF4CAF50)
                : Colors.grey[600],
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        items: _districts.map((district) {
          return DropdownMenuItem<Region>(
            value: district,
            child: Text(
              district.nameAr,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: isEnabled
            ? (Region? value) {
                if (value != null) {
                  _onDistrictSelected(value);
                }
              }
            : null,
        validator: widget.isRequired
            ? (value) => value == null ? loc.pleaseSelectDistrict : null
            : null,
        hint: _isLoadingDistricts
            ? Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(loc.loading),
                ],
              )
            : Text(isEnabled ? loc.selectDistrict : loc.selectGovernorateFirst),
      ),
    );
  }

  Widget _buildNeighborhoodDropdown(AppLocalizations loc) {
    final isEnabled = _selectedDistrict != null && !_isLoadingNeighborhoods;

    return Container(
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedNeighborhood != null
              ? const Color(0xFF4CAF50)
              : Colors.grey[300]!,
        ),
      ),
      child: DropdownButtonFormField<Region>(
        value: _selectedNeighborhood,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '${loc.neighborhood}${widget.isRequired ? " *" : ""}',
          prefixIcon: Icon(
            Icons.location_on,
            color: _selectedNeighborhood != null
                ? const Color(0xFF4CAF50)
                : Colors.grey[600],
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        items: _neighborhoods.map((neighborhood) {
          return DropdownMenuItem<Region>(
            value: neighborhood,
            child: Text(
              neighborhood.nameAr,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: isEnabled
            ? (Region? value) {
                if (value != null) {
                  _onNeighborhoodSelected(value);
                }
              }
            : null,
        validator: widget.isRequired
            ? (value) => value == null ? loc.pleaseSelectNeighborhood : null
            : null,
        hint: _isLoadingNeighborhoods
            ? Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(loc.loading),
                ],
              )
            : Text(
                isEnabled ? loc.selectNeighborhood : loc.selectDistrictFirst),
      ),
    );
  }

  Widget _buildNoActiveRegionsMessage(String message) {
    return Container(
      margin: EdgeInsets.only(top: AppSpacing.sm),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.orange[900],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Removed _buildErrorState() - no longer needed with Mapbox Address Autofill
}
