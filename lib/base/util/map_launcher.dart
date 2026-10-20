import 'package:campus_flutter/base/extensions/context.dart';
import 'package:campus_flutter/base/util/padded_divider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showDirectionsDialog(
  String name,
  LatLng location,
  BuildContext context, {
  String? navigaTumId,
}) async {
  MapLauncher.installedMaps.then((value) {
    if (context.mounted) {
      showModalBottomSheet(
        isDismissible: true,
        showDragHandle: true,
        context: context,
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: context.halfPadding),
                child: Text(context.tr("selectAction")),
              ),
              Card(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    if (index == value.length) {
                      return ListTile(
                        leading: const Icon(Icons.map_outlined, size: 30),
                        title: Text(context.tr("openIn", args: ["NavigaTUM"])),
                        onTap: () => launchUrl(
                          Uri(
                            scheme: 'https',
                            host: 'nav.tum.de',
                            pathSegments: ['room', navigaTumId!],
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                      );
                    }
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SvgPicture.asset(
                          value[index].icon,
                          height: 30,
                          width: 30,
                        ),
                      ),
                      title: Text(
                        context.tr("openIn", args: [value[index].mapName]),
                      ),
                      onTap: () => MapLauncher.showMarker(
                        mapType: value[index].mapType,
                        title: name,
                        coords: Coords(location.latitude, location.longitude),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const PaddedDivider(),
                  itemCount: value.length + (navigaTumId == null ? 0 : 1),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: context.padding,
                  bottom: context.padding * 2,
                ),
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  child: Text(context.tr("cancel")),
                ),
              ),
            ],
          );
        },
      );
    }
  });
}
