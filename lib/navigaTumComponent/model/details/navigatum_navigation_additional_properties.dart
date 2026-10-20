import 'package:campus_flutter/navigaTumComponent/model/navigatum_navigation_property.dart';
import 'package:campus_flutter/navigaTumComponent/model/navigatum_floor.dart';
import 'package:json_annotation/json_annotation.dart';

part 'navigatum_navigation_additional_properties.g.dart';

@JsonSerializable()
class NavigaTumNavigationAdditionalProperties {
  @JsonKey(name: "computed")
  final List<NavigaTumNavigationProperty> properties;
  @JsonKey(defaultValue: <NavigaTumFloor>[])
  final List<NavigaTumFloor> floors;

  NavigaTumNavigationAdditionalProperties(
    this.properties, {
    this.floors = const [],
  });

  factory NavigaTumNavigationAdditionalProperties.fromJson(
    Map<String, dynamic> json,
  ) => _$NavigaTumNavigationAdditionalPropertiesFromJson(json);

  Map<String, dynamic> toJson() =>
      _$NavigaTumNavigationAdditionalPropertiesToJson(this);
}
