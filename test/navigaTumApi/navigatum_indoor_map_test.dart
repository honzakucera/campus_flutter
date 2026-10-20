import 'dart:convert';

import 'package:campus_flutter/navigaTumComponent/model/details/navigatum_navigation_additional_properties.dart';
import 'package:campus_flutter/navigaTumComponent/model/navigatum_map_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The relevant source/layer structure of NavigaTUM's public basemap.
  Map<String, dynamic> basemap() => {
    'version': 8,
    'sources': {
      'indoor': {
        'type': 'vector',
        'url': 'https://nav.tum.de/martin/indoor_rooms,indoor_pois?level=0.0',
      },
    },
    'layers': [
      {'id': 'outdoor', 'type': 'fill', 'source': 'basemap'},
      {
        'id': 'indoor-rooms',
        'type': 'fill',
        'source': 'indoor',
        'layout': {'visibility': 'visible'},
      },
      {
        'id': 'indoor-pois',
        'type': 'symbol',
        'source': 'indoor',
        'source-layer': 'indoor_pois',
        'layout': {
          'text-field': ['get', 'ref'],
          'icon-image': '',
        },
      },
      for (final floor in [-2, -1, 0, 1, 2, 3, 6])
        {
          'id': 'indoor-raster-floor-$floor',
          'type': 'raster',
          'source': 'floor-$floor',
          'layout': {'visibility': 'none'},
        },
    ],
  };

  Map<String, dynamic> layer(Map<String, dynamic> style, String id) =>
      (style['layers'] as List).cast<Map<String, dynamic>>().singleWhere(
        (layer) => layer['id'] == id,
      );

  test('uses the API floor ID rather than the displayed floor number', () {
    // Theresianum's "2" is level 3 because there is a mezzanine.
    final properties = NavigaTumNavigationAdditionalProperties.fromJson({
      'computed': [
        {'name': 'Floor', 'text': '2 (2nd upper floor + 1 mezzanine)'},
      ],
      'floors': [
        {'id': 3, 'short_name': '2'},
      ],
    });
    final style = jsonDecode(
      NavigaTumMapStyle.fromJson(
        basemap(),
      ).forFloor(properties.floors.single.id),
    );
    expect(properties.floors.single.shortName, '2');
    expect(
      Uri.parse(style['sources']['indoor']['url']).queryParameters['level'],
      '3.0',
    );
    expect(
      layer(style, 'indoor-raster-floor-3')['layout']['visibility'],
      'visible',
    );
    expect(
      layer(style, 'indoor-raster-floor-0')['layout']['visibility'],
      'none',
    );
  });

  test('switches basement floors without mutating the shared style', () {
    final original = basemap();
    final encodedOriginal = jsonEncode(original);
    final mapStyle = NavigaTumMapStyle.fromJson(original);
    expect(mapStyle.floors, [-2, -1, 0, 1, 2, 3, 6]);
    final basement = jsonDecode(mapStyle.forFloor(-1));
    final ground = jsonDecode(mapStyle.forFloor(0));
    expect(
      Uri.parse(basement['sources']['indoor']['url']).queryParameters['level'],
      '-1.0',
    );
    expect(
      Uri.parse(ground['sources']['indoor']['url']).queryParameters['level'],
      '0.0',
    );
    expect(jsonEncode(original), encodedOriginal);
  });

  test(
    'outdoor mode hides every indoor layer, including labels and raster',
    () {
      final style = jsonDecode(
        NavigaTumMapStyle.fromJson(basemap()).forFloor(null),
      );
      for (final entry in style['layers']) {
        if (entry['id'] != 'outdoor') {
          expect(entry['layout']['visibility'], 'none', reason: entry['id']);
        }
      }
      expect(layer(style, 'outdoor').containsKey('layout'), isFalse);
    },
  );

  test('room labels are independent of missing POI icons', () {
    final style = jsonDecode(NavigaTumMapStyle.fromJson(basemap()).forFloor(3));
    final labels = layer(style, 'campus-room-labels');
    expect(labels['source'], 'indoor');
    expect(labels['source-layer'], 'indoor_pois');
    expect(labels['layout']['visibility'], 'visible');
    expect(labels['layout'].containsKey('icon-image'), isFalse);
    expect(labels['layout']['text-field'][2], ['get', 'ref']);
    expect(layer(style, 'indoor-pois')['layout']['text-field'], '');
  });

  test(
    'older room responses without floor metadata do not imply ground floor',
    () {
      final properties = NavigaTumNavigationAdditionalProperties.fromJson({
        'computed': [],
      });
      expect(properties.floors, isEmpty);
    },
  );
}
