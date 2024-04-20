import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:uninav/controllers/map_controller.dart';
import 'package:uninav/data/geo/model.dart';
import 'package:uninav/map.dart';
import 'package:uninav/util/geomath.dart';

List<Widget> renderLevel(int level, {LayerHitNotifier? hitNotifier}) {
  return <Widget>[
    LevelLayer(
        filter: (feature) =>
            feature.level == level && feature.type is LectureHall,
        polyConstructor: (feature) => feature
            .getPolygon(
              constructor: (pts) => Polygon(
                points: pts,
                color: Colors.orange.withOpacity(0.2),
                borderColor: Colors.orange,
                borderStrokeWidth: 2,
                hitValue: feature,
              ),
            )
            .unwrap(),
        markerConstructor: (feature) => Marker(
              width: 50,
              height: 20,
              point: feature.getPoint().unwrap(),
              child: Column(
                children: [
                  Icon(
                    Icons.class_,
                    color: Colors.black,
                  ),
                  Text('${feature.name}'),
                ],
              ),
              alignment: Alignment.center,
            ),
        notifier: hitNotifier),
    LevelLayer(
      filter: (feature) => feature.level == level && feature.type is Room,
      polyConstructor: (feature) => feature
          .getPolygon(
            constructor: (pts) => Polygon(
              points: pts,
              color: Colors.green.withOpacity(1.2),
              borderColor: Colors.green,
              borderStrokeWidth: 2,
              hitValue: feature,
            ),
          )
          .unwrap(),
      notifier: hitNotifier,
    ),
    LevelLayer(
      filter: (feature) => feature.level == level && feature.type is Door,
      markerConstructor: (feature) {
        final point = feature.getPoint().unwrap();
        return Marker(
          width: 21,
          height: 21,
          point: point,
          child: const Icon(
            Icons.door_front_door,
            color: Colors.brown,
          ),
          alignment: Alignment.center,
        );
      },
      notifier: hitNotifier,
    ),
    LevelLayer(
      filter: (feature) => feature.level == level && feature.type is Toilet,
      markerConstructor: (feature) {
        final type = (feature.type as Toilet).toilet_type;
        IconData icon;
        switch (type.toLowerCase()) {
          case 'male':
            icon = Icons.male;
            break;
          case 'female':
            icon = Icons.female;
            break;
          case 'handicap':
            icon = Icons.wheelchair_pickup;
            break;
          default:
            print("WARN: Toilet didn't have recognizable type! "
                "(Level ${feature.level}, Name ${feature.name}, "
                "Location: ${feature.getPoint().unwrap()})");
            icon = Icons.wc;
            break;
        }

        final point = feature.getPoint().unwrap();
        return Marker(
          width: 21,
          height: 21,
          point: point,
          child: Icon(
            icon,
            color: Colors.purple,
          ),
          alignment: Alignment.center,
        );
      },
      notifier: hitNotifier,
    ),
    LevelLayer(
      filter: (feature) =>
          feature.type is Stairs &&
          (feature.type as Stairs).connects_levels.contains(level),
      markerConstructor: (feature) {
        final point = feature.getPoint().unwrap();
        return Marker(
          width: 21,
          height: 21,
          point: point,
          child: Icon(
            Icons.stairs_outlined,
            color: Colors.deepPurple.shade300,
          ),
          alignment: Alignment.center,
        );
      },
      notifier: hitNotifier,
    ),
    LevelLayer(
      filter: (feature) =>
          feature.type is Lift &&
          (feature.type as Lift).connects_levels.contains(level),
      markerConstructor: (feature) {
        final point = feature.getPoint().unwrap();
        return Marker(
          width: 21,
          height: 21,
          point: point,
          child: const Icon(
            Icons.elevator_outlined,
            color: Colors.deepPurple,
          ),
          alignment: Alignment.center,
        );
      },
      notifier: hitNotifier,
    ),
  ];
}

class LevelLayer extends StatelessWidget {
  final bool Function(Feature)? filter;
  final Polygon Function(Feature)? polyConstructor;
  final Marker Function(LatLng, String)? polyCenterMarkerConstructor;
  final Marker Function(Feature)? markerConstructor;
  final int? level;
  final LayerHitNotifier? notifier;

  const LevelLayer({
    this.level,
    this.filter,
    this.polyConstructor,
    this.polyCenterMarkerConstructor,
    this.markerConstructor,
    this.notifier,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final myMapController = Get.find<MyMapController>();

    return Obx(() {
      final List<Polygon> filteredPolygons = [];
      final List<Marker> polygonCenterMarkers = [];
      final List<Marker> filteredMarkers = [];

      for (final feature in myMapController.features) {
        if (filter == null || filter!(feature)) {
          if (feature.isPolygon()) {
            if (polyConstructor != null) {
              filteredPolygons.add(polyConstructor!(feature));
            } else {
              filteredPolygons.add(feature
                  .getPolygon(
                      constructor: (points) => Polygon(
                            points: points,
                            borderColor: Colors.black26,
                            borderStrokeWidth: 2.0,
                            hitValue: feature,
                          ))
                  .unwrap());
            }

            // calculate polygon center
            final center =
                polygonCenterMinmax(feature.getPolygon().unwrap().points);
            if (polyCenterMarkerConstructor != null) {
              polygonCenterMarkers
                  .add(polyCenterMarkerConstructor!(center, feature.name));
            } else {
              polygonCenterMarkers.add(Marker(
                width: 100,
                height: 100,
                point: center,
                child: Center(
                  child: Text(
                    feature.name,
                    style: const TextStyle(
                      color: Colors.black54,
                      // backgroundColor: Colors.white,
                    ),
                  ),
                ),
                alignment: Alignment.center,
              ));
            }
          } else if (feature.isPoint()) {
            if (markerConstructor != null) {
              filteredMarkers.add(markerConstructor!(feature));
            } else {
              final point = feature.getPoint().unwrap();
              filteredMarkers.add(Marker(
                width: 100,
                height: 100,
                point: point,
                child: Center(
                  child: Text(
                    feature.name,
                    style: const TextStyle(
                      color: Colors.black54,
                      // backgroundColor: Colors.white,
                    ),
                  ),
                ),
                alignment: Alignment.center,
              ));
            }
          }
        }
      }
      // print(filteredPolygons.length);
      // print(filteredPolygons);

      // print(filteredPolygons[0].points[0]);
      // print(myMapController.features.length);

      // filteredPolygons.forEach((element) {
      //   print(element.hitValue);
      // });

      final List<Widget> widgets = [];
      if (filteredPolygons.isNotEmpty) {
        if (polyConstructor != null) {
          widgets.add(TranslucentPointer(
            child: PolygonLayer(
              polygons: filteredPolygons,
              hitNotifier: notifier,
            ),
          ));
        } else {
          widgets.add(TranslucentPointer(
            child: PolygonLayer(
              polygons: filteredPolygons,
              hitNotifier: notifier,
            ),
          ));
        }
        widgets.add(TranslucentPointer(
          child: MarkerLayer(
            markers: polygonCenterMarkers,
            rotate: true,
          ),
        ));
      }

      if (filteredMarkers.isNotEmpty) {
        widgets.add(TranslucentPointer(
          child: MarkerLayer(markers: filteredMarkers, rotate: true),
        ));
      }

      return Stack(children: widgets);
    });
  }
}