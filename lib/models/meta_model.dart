import 'service_model.dart';

class MetaModel {
  final List<ServiceModel> services;
  final List<String> cities;

  const MetaModel({
    required this.services,
    required this.cities,
  });

  factory MetaModel.fromJson(Map<String, dynamic> json) {
    return MetaModel(
      services: (json['services'] as List? ?? [])
          .map((e) => ServiceModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      cities: (json['cities'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}