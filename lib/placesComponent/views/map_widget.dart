import 'dart:async';
import 'dart:developer';
import 'package:campus_flutter/base/extensions/context.dart';
import 'package:campus_flutter/navigaTumComponent/model/navigatum_map_style.dart';
import 'package:campus_flutter/navigaTumComponent/services/navigatum_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:campus_flutter/placesComponent/model/maps/marker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapWidget extends ConsumerStatefulWidget {
  factory MapWidget.fullPadding({
    required Set<Marker> markers,
    LatLng? latLng,
    double? zoom,
    double? aspectRatio,
    bool aspectRatioNeeded = true,
    bool roundedCorners = true,
    Widget? mapLegend,
    bool indoor = false,
    bool showFloorSelector = false,
    int? initialFloor = 0,
  }) {
    return MapWidget._(
      markers: markers,
      latLng: latLng,
      zoom: zoom,
      aspectRatio: aspectRatio,
      aspectRatioNeeded: aspectRatioNeeded,
      roundedCorners: roundedCorners,
      mapLegend: mapLegend,
      indoor: indoor,
      showFloorSelector: showFloorSelector,
      initialFloor: initialFloor,
    );
  }

  factory MapWidget.noPadding({
    required Set<Marker> markers,
    LatLng? latLng,
    double? zoom,
    double? aspectRatio,
    bool aspectRatioNeeded = true,
    bool roundedCorners = true,
    Widget? mapLegend,
    bool indoor = false,
    bool showFloorSelector = false,
    int? initialFloor = 0,
  }) {
    return MapWidget._(
      markers: markers,
      latLng: latLng,
      zoom: zoom,
      aspectRatio: aspectRatio,
      padding: EdgeInsets.zero,
      aspectRatioNeeded: aspectRatioNeeded,
      roundedCorners: roundedCorners,
      mapLegend: mapLegend,
      indoor: indoor,
      showFloorSelector: showFloorSelector,
      initialFloor: initialFloor,
    );
  }

  factory MapWidget.customPadding({
    required Set<Marker> markers,
    required EdgeInsets padding,
    LatLng? latLng,
    double? zoom,
    double? aspectRatio,
    bool aspectRatioNeeded = true,
    bool roundedCorners = true,
    Widget? mapLegend,
    bool indoor = false,
    bool showFloorSelector = false,
    int? initialFloor = 0,
  }) {
    return MapWidget._(
      markers: markers,
      padding: padding,
      latLng: latLng,
      zoom: zoom,
      aspectRatio: aspectRatio,
      aspectRatioNeeded: aspectRatioNeeded,
      roundedCorners: roundedCorners,
      mapLegend: mapLegend,
      indoor: indoor,
      showFloorSelector: showFloorSelector,
      initialFloor: initialFloor,
    );
  }

  const MapWidget._({
    required this.markers,
    this.latLng,
    this.zoom,
    this.aspectRatio,
    this.padding,
    required this.aspectRatioNeeded,
    required this.roundedCorners,
    this.mapLegend,
    this.indoor = false,
    this.showFloorSelector = false,
    this.initialFloor = 0,
  });

  final Set<Marker> markers;
  final LatLng? latLng;
  final double? zoom;
  final double? aspectRatio;
  final bool aspectRatioNeeded;
  final bool roundedCorners;
  final EdgeInsets? padding;
  final Widget? mapLegend;
  final bool indoor;
  final bool showFloorSelector;
  final int? initialFloor;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> {
  MapLibreMapController? _mapController;
  bool isMapVisible = false;
  NavigaTumMapStyle? _indoorStyle;
  String? _styleString;
  late int? _floor;
  bool _styleLoadFailed = false;

  final Set<String> _loadedImages = {};

  @override
  void initState() {
    super.initState();
    _floor = widget.initialFloor;
    if (widget.indoor) _loadIndoorStyle();
  }

  Future<void> _loadIndoorStyle() async {
    setState(() => _styleLoadFailed = false);
    try {
      final style = await NavigaTumService.mapStyle();
      if (!mounted) return;
      setState(() {
        _indoorStyle = style;
        _styleString = style.forFloor(_floor);
      });
    } catch (error, stackTrace) {
      log('Unable to load indoor map', error: error, stackTrace: stackTrace);
      if (mounted) setState(() => _styleLoadFailed = true);
    }
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFloor != oldWidget.initialFloor) {
      _selectFloor(widget.initialFloor, zoomIn: false);
    }
    if (_mapController != null &&
        isMapVisible &&
        widget.markers != oldWidget.markers) {
      _updateMarkers(_mapController!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          widget.padding ??
          EdgeInsets.only(
            left: context.padding,
            right: context.padding,
            bottom: context.padding,
            top: context.halfPadding,
          ),
      child: ClipRRect(
        borderRadius: widget.roundedCorners
            ? BorderRadius.circular(15.0)
            : BorderRadius.zero,
        child: widget.aspectRatioNeeded
            ? AspectRatio(
                aspectRatio: widget.aspectRatio ?? 1.0,
                child: _buildMapStack(),
              )
            : _buildMapStack(),
      ),
    );
  }

  Widget _buildMapStack() {
    if (widget.indoor && _styleString == null) {
      return Center(
        child: _styleLoadFailed
            ? TextButton.icon(
                onPressed: _loadIndoorStyle,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('tryAgain')),
              )
            : const CircularProgressIndicator.adaptive(),
      );
    }
    return AnimatedOpacity(
      curve: Curves.fastOutSlowIn,
      opacity: isMapVisible ? 1.0 : 0.01,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        children: [
          MapLibreMap(
            styleString:
                _styleString ??
                "https://nav.tum.de/martin/style/navigatum-basemap.json",
            trackCameraPosition: true,
            // Native synchronous updates used for dragging cause symbol artifacts
            // in MapLibre 0.26.1. Campus/room markers normally stay fixed.
            dragEnabled: widget.markers.any(
              (marker) => marker.draggable == true,
            ),
            initialCameraPosition: CameraPosition(
              target:
                  // mapLibre and Google Maps have different latLng classes. This converts between them and also provides a default location. - Nathan
                  LatLng(
                    widget.latLng?.latitude ?? 48.26307794976663,
                    widget.latLng?.longitude ?? 11.668018668778569,
                  ),
              zoom: widget.zoom ?? 10,
            ),
            gestureRecognizers: {
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
            rotateGesturesEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: true,
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.compass,
            onMapCreated: (controller) {
              _mapController = controller;
              _setupSymbolHandler(controller);
            },
            onStyleLoadedCallback: () => _onStyleLoaded(),
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          ),

          if (widget.showFloorSelector && _indoorStyle != null)
            Positioned(
              top: context.padding,
              left: context.padding,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                color: context.theme.cardColor,
                child: PopupMenuButton<String>(
                  tooltip: context.tr('selectFloor'),
                  enabled: isMapVisible,
                  initialValue: _floor?.toString() ?? 'outdoors',
                  onSelected: (value) => _selectFloor(int.tryParse(value)),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'outdoors',
                      child: Text(context.tr('outdoorMap')),
                    ),
                    for (final floor in _indoorStyle!.floors.reversed)
                      PopupMenuItem(
                        value: floor.toString(),
                        child: Text(_floorLabel(floor)),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_outlined),
                        const SizedBox(width: 6),
                        Text(_floorLabel(_floor)),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (widget.mapLegend != null)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(context.padding),
                child: widget.mapLegend!,
              ),
            ),

          Positioned(
            right: context.padding,
            bottom: context.padding,
            child: FloatingActionButton(
              shape: const CircleBorder(),
              heroTag: "geolocation_button",
              backgroundColor: context.theme.cardColor,
              elevation: 6,
              onPressed: _onLocateMePressed,
              child: Image.asset(
                "assets/images/map/locate.webp",
                height: 36,
                width: 36,
                color: context.theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;

    // A floor change reloads the style, including its images and symbols.
    _loadedImages.clear();
    await _loadMarkerImages(controller);
    await _updateMarkers(controller);

    if (mounted) {
      setState(() {
        isMapVisible = true;
      });
    }
  }

  String _floorLabel(int? floor) => floor == null
      ? context.tr('outdoorMap')
      : floor == 0
      ? context.tr('groundFloor')
      : context.tr('floorNumber', args: ['$floor']);

  void _selectFloor(int? floor, {bool zoomIn = true}) {
    if (_floor != floor) {
      setState(() {
        _floor = floor;
        _styleString = _indoorStyle?.forFloor(floor);
        isMapVisible = false;
      });
    }
    final controller = _mapController;
    if (zoomIn &&
        floor != null &&
        controller != null &&
        (controller.cameraPosition?.zoom ?? 0) < 17) {
      controller.animateCamera(CameraUpdate.zoomTo(17));
    }
  }

  Future<void> _loadMarkerImages(MapLibreMapController controller) async {
    Future<void> load(String name, String path) async {
      if (_loadedImages.contains(name)) return;
      try {
        final ByteData data = await rootBundle.load(path);
        await controller.addImage(name, data.buffer.asUint8List());
        _loadedImages.add(name);
      } catch (e) {
        log("Error loading map asset $path: $e");
      }
    }

    await load("pin_blue", "assets/images/map/pin_blue.webp");
    await load("pin_red", "assets/images/map/pin_red.webp");
  }

  Future<void> _updateMarkers(MapLibreMapController controller) async {
    await controller.clearSymbols();

    await controller.symbolManager?.setIconAllowOverlap(true);
    await controller.symbolManager?.setIconIgnorePlacement(true);
    await controller.symbolManager?.setTextAllowOverlap(true);
    await controller.symbolManager?.setTextIgnorePlacement(true);
    // The annotation manager defaults to fonts not served by NavigaTUM.
    for (final layer in controller.symbolManager?.layerIds ?? <String>[]) {
      await controller.setLayerProperties(
        layer,
        const SymbolLayerProperties(textFont: ['Roboto Regular']),
      );
    }

    List<SymbolOptions> options = [];
    List<Map<String, dynamic>> data = [];

    for (var marker in widget.markers) {
      options.add(
        SymbolOptions(
          iconSize: 3,
          iconImage: marker.isRed ? "pin_red" : "pin_blue",
          iconRotate: marker.rotation,
          iconOffset: const Offset(0, -5),
          textField: marker.infoWindow?.title,
          textOffset: const Offset(0, -3),
          iconOpacity: marker.alpha,
          geometry: LatLng(marker.position.latitude, marker.position.longitude),
          zIndex: marker.zIndex,
          draggable: marker.draggable,
          fontNames: ["Roboto Regular"],
          textColor: "#000000",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 3.0, // magic number (done by eye)
          textHaloBlur: 0,
          textOpacity: 0, // Starts hidden (handled on tap)
          textMaxWidth: -1, // No limit
        ),
      );

      // Symbol data is sent to native MapLibre as JSON, so keep callbacks in Dart.
      data.add({"id": marker.id});
    }

    for (int i = 0; i < options.length; i++) {
      await controller.addSymbol(options[i], data[i]);
    }
  }

  void _setupSymbolHandler(MapLibreMapController controller) {
    controller.onSymbolTapped.add((symbol) {
      // display text on tapped symbol & remove text from other symbols
      // if text is already displayed and item has onTap callback, callback is executed
      final onTap = widget.markers
          .where((marker) => marker.id == symbol.data?["id"])
          .firstOrNull
          ?.infoWindow
          ?.onTap;

      if (symbol.options.textOpacity == 1 && onTap is void Function()) {
        onTap();
      }

      for (var s in controller.symbols) {
        if (s.options.textOpacity == 1) {
          controller.updateSymbol(s, const SymbolOptions(textOpacity: 0));
        }
      }

      controller.updateSymbol(symbol, const SymbolOptions(textOpacity: 1));

      if (symbol.options.geometry != null) {
        controller.animateCamera(
          CameraUpdate.newLatLng(
            symbol.options.geometry!,
          ), // something will have gone very wrong if it goes to 0,0
          duration: const Duration(seconds: 1), // magic number (felt right)
        );
      }
    });
  }

  void _onLocateMePressed() async {
    if (_mapController == null) return;

    final myLoc = await _mapController!.requestMyLocationLatLng();

    final target = myLoc != null
        ? LatLng(myLoc.latitude, myLoc.longitude)
        : const LatLng(
            48.26307794976663,
            11.668018668778569,
          ); // Default to TUM Garching campus

    _mapController!.animateCamera(
      CameraUpdate.newLatLng(target),
      duration: const Duration(seconds: 1),
    );
  }
}
