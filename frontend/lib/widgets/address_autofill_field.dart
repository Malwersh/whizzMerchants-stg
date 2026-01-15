import 'package:flutter/material.dart';
import '../services/address_autofill_service.dart';
import '../core/design_system/design_system.dart';

/// Address Autofill Text Field Widget
/// Provides real-time address suggestions using Google Places API
/// Supports both iOS and Android platforms
class AddressAutofillField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final Function(AddressComponents) onAddressSelected;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final bool enabled;

  const AddressAutofillField({
    Key? key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.onAddressSelected,
    this.prefixIcon = Icons.location_on,
    this.validator,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<AddressAutofillField> createState() => _AddressAutofillFieldState();
}

class _AddressAutofillFieldState extends State<AddressAutofillField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<GooglePlace> _suggestions = [];
  bool _isLoading = false;
  final FocusNode _focusNode = FocusNode();
  bool _isProcessingSelection =
      false; // Prevent multiple simultaneous selections

  // Cost optimization: Debouncing to reduce API calls
  DateTime? _lastSearchTime;
  String? _lastSearchQuery;
  static const _searchDebounceMs = 500; // Wait 500ms after user stops typing

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    // Don't remove overlay if we're in the middle of processing a selection
    if (!_focusNode.hasFocus && !_isProcessingSelection) {
      // Longer delay to ensure tap is registered before overlay removal
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!_focusNode.hasFocus && !_isProcessingSelection && mounted) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    // Don't search if we're processing a selection
    if (_isProcessingSelection) {
      return;
    }

    final query = widget.controller.text;

    if (query.length < 3) {
      _removeOverlay();
      return;
    }

    // Cost optimization: Debounce search requests
    _debouncedSearch(query);
  }

  void _debouncedSearch(String query) {
    // Cancel previous search if user is still typing
    _lastSearchTime = DateTime.now();
    _lastSearchQuery = query;

    Future.delayed(Duration(milliseconds: _searchDebounceMs), () {
      // Only search if this is still the latest query and enough time has passed
      if (_lastSearchQuery == query &&
          _lastSearchTime != null &&
          DateTime.now().difference(_lastSearchTime!).inMilliseconds >=
              _searchDebounceMs) {
        _searchAddresses(query);
      }
    });
  }

  Future<void> _searchAddresses(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await AddressAutofillService.searchAddresses(
        query: query,
      );

      if (!mounted) return;

      setState(() {
        _suggestions = results;
        _isLoading = false;
      });

      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _suggestions = [];
      });
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey[200],
                  ),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return InkWell(
                      onTap: () {
                        // Prevent multiple simultaneous taps
                        if (_isProcessingSelection) return;

                        // Immediately set processing flag and remove overlay
                        _isProcessingSelection = true;
                        _focusNode.removeListener(_onFocusChanged);
                        _onSuggestionSelected(suggestion);
                      },
                      splashColor: const Color(0xFF4CAF50).withOpacity(0.1),
                      highlightColor: const Color(0xFF4CAF50).withOpacity(0.05),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: const Color(0xFF4CAF50),
                              size: 24,
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestion.mainText ??
                                        suggestion.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  if (suggestion.secondaryText != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      suggestion.secondaryText!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSuggestionSelected(GooglePlace place) async {
    // Set processing flag FIRST to prevent text change listener from firing
    _isProcessingSelection = true;

    // Immediately remove overlay to prevent multiple taps
    _removeOverlay();

    // Remove focus listener to prevent interference
    _focusNode.removeListener(_onFocusChanged);

    // Unfocus to hide keyboard immediately
    _focusNode.unfocus();

    // Show loading while fetching details
    setState(() {
      _isLoading = true;
      _suggestions = [];
    });

    try {
      final components =
          await AddressAutofillService.getPlaceDetails(place.placeId);

      if (!mounted) return;

      // Update text field (won't trigger search because _isProcessingSelection is true)
      widget.controller.text = components.fullAddress;
      widget.onAddressSelected(components);

      setState(() {
        _isLoading = false;
      });

      // Re-add focus listener and reset processing flag after a delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _focusNode.addListener(_onFocusChanged);
          _isProcessingSelection = false;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Re-add focus listener and reset processing flag
      _focusNode.addListener(_onFocusChanged);
      _isProcessingSelection = false;

      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في جلب تفاصيل العنوان'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          prefixIcon: Icon(
            widget.prefixIcon,
            color: const Color(0xFF4CAF50),
          ),
          suffixIcon: _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF4CAF50),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
        validator: widget.validator,
      ),
    );
  }
}
