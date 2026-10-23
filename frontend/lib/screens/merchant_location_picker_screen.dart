import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/merchant_places_service.dart';

class MerchantLocationPickerScreen extends StatefulWidget {
  final MerchantLocation? initial;
  const MerchantLocationPickerScreen({super.key, this.initial});
  @override
  State<MerchantLocationPickerScreen> createState() =>
      _MerchantLocationPickerScreenState();
}

class _MerchantLocationPickerScreenState
    extends State<MerchantLocationPickerScreen> {
  final _search = TextEditingController();
  final _places = MerchantPlacesService();
  GoogleMapController? _map;
  late LatLng _center;
  bool _selected = false,
      _moving = false,
      _loading = false,
      _interacted = false;
  String? _error, _address;
  List<MerchantPlace> _results = [];
  Timer? _debounce;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _center = initial == null
        ? const LatLng(32.0, 44.34)
        : LatLng(initial.latitude, initial.longitude);
    _selected = initial != null;
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _places.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _query(String text) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _results = [];
      _error = null;
      _loading = false;
    });
    if (text.trim().length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        final results = await _places.search(text);
        if (mounted && generation == _generation)
          setState(() {
            _results = results;
            _loading = false;
            if (results.isEmpty)
              _error = 'لا توجد نتائج. جرّب اسم شارع أو معلم قريب.';
          });
      } catch (e) {
        if (mounted && generation == _generation)
          setState(() {
            _loading = false;
            _error = e.toString().replaceFirst('Exception: ', '');
          });
      }
    });
  }

  Future<void> _choose(MerchantPlace place) async {
    _debounce?.cancel();
    final generation = ++_generation;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _results = [];
      _error = null;
    });
    try {
      final point = await _places.details(place.id);
      if (!mounted || generation != _generation) return;
      _search.text = place.label;
      setState(() {
        _address = point.address;
        _selected = true;
        _center = LatLng(point.latitude, point.longitude);
      });
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(_center, 17));
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _current() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('فعّل خدمة الموقع أو ابحث عن العنوان.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        throw Exception('اسمح بالوصول للموقع أو حدد النقطة يدويًا.');
      final point = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _selected = true;
        _address = null;
        _center = LatLng(point.latitude, point.longitude);
      });
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(_center, 17));
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('موقع النشاط على الخريطة')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                  controller: _search,
                  onChanged: _query,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _query,
                  decoration: InputDecoration(
                      hintText: 'ابحث عن عنوان أو معلم في العراق',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : IconButton(
                              tooltip: 'مسح البحث',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _query('');
                              }),
                      border: const OutlineInputBorder()))),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_results.isNotEmpty)
            ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .22),
                child: ListView(shrinkWrap: true, children: [
                  for (final place in _results)
                    ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(place.label),
                        onTap: () => _choose(place))
                ])),
          Expanded(
              child: Stack(children: [
            Listener(
                onPointerDown: (_) {
                  _interacted = true;
                  _address = null;
                },
                child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                        target: _center, zoom: _selected ? 17 : 12),
                    onMapCreated: (controller) => _map = controller,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    onCameraMoveStarted: () => setState(() {
                          _moving = true;
                        }),
                    onCameraMove: (camera) => _center = camera.target,
                    onCameraIdle: () => setState(() {
                          _moving = false;
                          if (_interacted) _selected = true;
                        }),
                    onTap: (point) {
                      setState(() {
                        _center = point;
                        _selected = true;
                        _address = null;
                      });
                      _map?.animateCamera(CameraUpdate.newLatLng(point));
                    })),
            const IgnorePointer(
                child: Center(
                    child: Padding(
                        padding: EdgeInsets.only(bottom: 42),
                        child: Icon(Icons.location_pin,
                            size: 48, color: Colors.red)))),
            Positioned(
                top: 12,
                left: 12,
                child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(children: [
                      IconButton(
                          tooltip: 'تكبير',
                          onPressed: () =>
                              _map?.animateCamera(CameraUpdate.zoomIn()),
                          icon: const Icon(Icons.add)),
                      IconButton(
                          tooltip: 'تصغير',
                          onPressed: () =>
                              _map?.animateCamera(CameraUpdate.zoomOut()),
                          icon: const Icon(Icons.remove)),
                      IconButton(
                          tooltip: 'موقعي الحالي',
                          onPressed: _loading ? null : _current,
                          icon: const Icon(Icons.my_location))
                    ]))),
          ])),
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                              'حرّك الخريطة لوضع الدبوس عند مدخل النشاط، أو اضغط على المكان. استخدم إصبعين للتكبير والتصغير.'),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: !_selected || _moving || _loading
                                  ? null
                                  : () => Navigator.pop(
                                      context,
                                      MerchantLocation(
                                          _center.latitude, _center.longitude,
                                          address: _address)),
                              child: const Text('اعتماد هذا الموقع')),
                        ]))),
        ]),
      ));
}
