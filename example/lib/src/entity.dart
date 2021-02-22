import 'dart:core';

// The things we store in the database
class Entity {
  final int? id;
  final String name;
  final String position;
  final String? hometown;

  Entity(this.id, this.name, this.position, [this.hometown]);
}
