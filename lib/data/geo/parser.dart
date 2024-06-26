import 'package:anyhow/anyhow.dart';
import 'package:geojson_vi/geojson_vi.dart';
import 'package:uninav/data/geo/model.dart';
import 'package:yaml/yaml.dart';

Result<Feature> parseFeature(
    Map<String, dynamic> properties, GeoJSONGeometry geometry, String id) {
  final name = properties['name'] as String?;
  final description_yaml = properties['description'] as String? ?? '';
  final layer = properties['layer'] as String?;

  int? level;

  // check if layer key contains a digit using \d+ regex

  final layerNum = RegExp(r'\d+').firstMatch(layer ?? '');
  if (layerNum != null) {
    level = int.parse(layerNum.group(0)!);
  }

  // try parse yaml
  if (description_yaml == null) {
    print(
        "warn: Description key is missing for feature $name\n\n$geometry\n\n$properties");
  }

  if (layer == null) {
    return bail(
        "Layer key \'layer\' is missing for feature $name\n\n$geometry\n\n$properties");
  }
  dynamic yaml;
  try {
    yaml = loadYaml(description_yaml);
  } on YamlException catch (e) {
    return bail(
        "Couldn't parse YAML in description for feature $name\n\n$description_yaml\n\nError: $e");
  }

  yaml = yaml as YamlMap? ?? {};
  final description = yaml['description'] as String?;

  // if (description != null) print("================ $description");

  final building = yaml['building'] as String?;

  // print("yaml: $yaml");

  var raw_type = yaml['type'] as String?;
  if (raw_type == null && layer?.toLowerCase() == 'buildings') {
    raw_type = 'building';
  }

  if (raw_type == null) {
    return bail("Type key \'type\' is missing for feature $name");
  }

  FeatureType type;

  try {
    switch (raw_type) {
      case 'building':
        type = FeatureType.building();
      case 'lift':
        final list = getYamlList<int>(yaml, 'connects_levels')
            .expect("Couldn't parse 'connects_levels' for feature $name");
        type = FeatureType.lift(list);
        break;
      case 'stairs':
        final list = getYamlList<int>(yaml, 'connects_levels')
            .expect("Couldn't parse 'connects_levels' for feature $name");
        type = FeatureType.stairs(list);
        break;
      case 'lecture_hall':
        type = FeatureType.lectureHall();
        break;
      case 'seminar_room':
        type = FeatureType.room(getYamlKeyStringify(yaml, 'number')
            .expect("Couldn't parse 'number' for seminar_room feature $name"));
        break;
      case 'pc_pool':
        type = FeatureType.pcPool(getYamlKeyStringify(yaml, 'number')
            .expect("Couldn't parse 'number' for PcPool feature $name"));
        break;
      case 'food_drink':
        type = FeatureType.foodDrink();
        break;
      case 'door':
        final list = getYamlList<String>(yaml, 'connects')
            .expect("Couldn't parse 'connects' for feature $name");
        type = FeatureType.door(list);
        break;
      case 'toilet':
        final toiletType = getYamlKey<String>(yaml, 'toilet_type')
            .expect("Couldn't parse 'toilet_type' for feature $name");
        type = FeatureType.toilet(toiletType);
        break;
      case 'public_transport':
        final busLines = getYamlList<dynamic>(yaml, 'bus_lines').unwrapOr([]);
        final tramLines = getYamlList<dynamic>(yaml, 'tram_lines').unwrapOr([]);

        type = FeatureType.publicTransport(
          stringifyList(busLines)
              .expect('Couldn\'t stringify \'bus_lines\' for feature $name'),
          stringifyList(tramLines)
              .expect('Couldn\'t stringify \'tram_lines\' for feature $name'),
        );
        break;
      default:
        return bail("Unknown feature type $raw_type for feature $name");
    }
  } catch (e) {
    return bail("Failed to parse feature type for feature $name: $e");
  }

  return Ok(Feature(
    name: name ?? 'Unknown',
    type: type,
    description: description,
    geometry: geometry,
    level: level,
    building: building,
    id: id,
  ));
}

Result<List<String>> stringifyList(List<dynamic> tramLines) {
  try {
    return Ok(tramLines.map((e) => e.toString()).toList());
  } catch (e) {
    return bail("Couldn't stringify list: $e");
  }
}

Result<List<T>> getYamlList<T>(YamlMap yaml, String key) {
  try {
    // print('yaml is ${yaml[key]}');
    final val = (yaml[key] as YamlList?);
    if (val == null) {
      return bail("Key $key is missing in yaml");
    }
    return Ok(val.cast<T>());
  } catch (e) {
    return bail("Failed to parse yaml key $key as ${T.toString()}: $e");
  }
}

Result<T> getYamlKey<T>(YamlMap yaml, String key) {
  try {
    final val = yaml[key] as T?;
    if (val == null) {
      return bail("Key $key is missing in yaml");
    }
    return Ok(val);
  } catch (e) {
    return bail("Failed to parse yaml key $key as ${T.toString()}: $e");
  }
}

Result<String> getYamlKeyStringify<T>(YamlMap yaml, String key) {
  try {
    final val = yaml[key] as T?;
    if (val == null) {
      return bail("Key $key is missing in yaml");
    }
    return Ok(val.toString());
  } catch (e) {
    return bail("Failed to parse yaml key $key as ${T.toString()}: $e");
  }
}
