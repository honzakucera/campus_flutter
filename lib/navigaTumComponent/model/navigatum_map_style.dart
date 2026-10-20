import 'dart:convert';

/// Adapts NavigaTUM's shared map style for a selected indoor floor.
class NavigaTumMapStyle {
  final Map<String, dynamic> _json;

  NavigaTumMapStyle.fromJson(this._json);

  List<int> get floors {
    final floors = <int>{};
    for (final layer in _json['layers'] as List<dynamic>) {
      final id = layer['id'] as String;
      if (id.startsWith('indoor-raster-floor-')) {
        floors.add(int.parse(id.substring('indoor-raster-floor-'.length)));
      }
    }
    return floors.toList()..sort();
  }

  String forFloor(int? floor) {
    // Keep the cached response intact when multiple maps use different floors.
    final style = jsonDecode(jsonEncode(_json)) as Map<String, dynamic>;
    final sources = style['sources'] as Map<String, dynamic>;
    final indoor = sources['indoor'] as Map<String, dynamic>;
    final uri = Uri.parse(indoor['url'] as String);
    indoor['url'] = uri
        .replace(
          queryParameters: {...uri.queryParameters, 'level': '${floor ?? 0}.0'},
        )
        .toString();

    final layers = style['layers'] as List<dynamic>;
    for (final layer in layers) {
      final id = layer['id'] as String;
      if (layer['source'] == 'indoor' ||
          id.startsWith('indoor-raster-floor-')) {
        final layout = layer['layout'] as Map<String, dynamic>? ?? {};
        layer['layout'] = layout;
        layout['visibility'] =
            floor != null &&
                (layer['source'] == 'indoor' ||
                    id == 'indoor-raster-floor-$floor')
            ? 'visible'
            : 'none';
      }
      if (id == 'indoor-pois') {
        // Room text is rendered separately, without depending on a POI icon.
        layer['layout']['text-field'] = '';
      }
    }
    layers.add({
      'id': 'campus-room-labels',
      'type': 'symbol',
      'source': 'indoor',
      'source-layer': 'indoor_pois',
      'minzoom': 17,
      'filter': [
        'any',
        ['has', 'ref'],
        ['has', 'name'],
      ],
      'layout': {
        'visibility': floor == null ? 'none' : 'visible',
        'text-field': [
          'case',
          [
            'all',
            ['has', 'ref'],
            [
              '!=',
              ['get', 'ref'],
              '',
            ],
          ],
          ['get', 'ref'],
          [
            'coalesce',
            ['get', 'name'],
            '',
          ],
        ],
        'text-font': ['Roboto Regular'],
        'text-size': [
          'interpolate',
          ['linear'],
          ['zoom'],
          17,
          11,
          20,
          15,
        ],
        'text-anchor': 'center',
        'text-max-width': 10,
        'text-padding': 2,
        'text-allow-overlap': false,
      },
      'paint': {
        'text-color': '#072140',
        'text-halo-color': '#ffffff',
        'text-halo-width': 1.5,
      },
    });
    return jsonEncode(style);
  }
}
