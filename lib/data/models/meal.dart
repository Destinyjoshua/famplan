import 'package:famplan/data/models/profile.dart';

class MealIngredient {
  const MealIngredient({
    required this.name,
    this.qty,
    this.unit,
  });

  final String name;
  final String? qty;
  final String? unit;

  factory MealIngredient.fromJson(Map<String, dynamic> json) {
    return MealIngredient(
      name: json['name'] as String,
      qty: json['qty'] as String?,
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'unit': unit,
      };
}

class MealSlot {
  const MealSlot({
    required this.id,
    required this.mealPlanId,
    required this.familyId,
    required this.dayOfWeek,
    required this.mealType,
    this.mealName,
    this.cookId,
    this.ingredients = const [],
    this.cook,
  });

  final String id;
  final String mealPlanId;
  final String familyId;
  final int dayOfWeek;
  final String mealType;
  final String? mealName;
  final String? cookId;
  final List<MealIngredient> ingredients;
  final Profile? cook;

  MealSlot copyWith({
    String? mealName,
    String? cookId,
    List<MealIngredient>? ingredients,
  }) {
    return MealSlot(
      id: id,
      mealPlanId: mealPlanId,
      familyId: familyId,
      dayOfWeek: dayOfWeek,
      mealType: mealType,
      mealName: mealName ?? this.mealName,
      cookId: cookId ?? this.cookId,
      ingredients: ingredients ?? this.ingredients,
      cook: cook,
    );
  }

  factory MealSlot.fromJson(Map<String, dynamic> json) {
    return MealSlot(
      id: json['id'] as String,
      mealPlanId: json['meal_plan_id'] as String,
      familyId: json['family_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      mealType: json['meal_type'] as String,
      mealName: json['meal_name'] as String?,
      cookId: json['cook_id'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => MealIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      cook: json['cook'] != null
          ? Profile.fromJson(json['cook'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'meal_plan_id': mealPlanId,
        'family_id': familyId,
        'day_of_week': dayOfWeek,
        'meal_type': mealType,
        'meal_name': mealName,
        'cook_id': cookId,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
      };
}

class MealPlan {
  const MealPlan({
    required this.id,
    required this.familyId,
    required this.weekStartDate,
    required this.createdBy,
    required this.updatedAt,
    this.slots = const [],
  });

  final String id;
  final String familyId;
  final DateTime weekStartDate;
  final String createdBy;
  final DateTime updatedAt;
  final List<MealSlot> slots;

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      weekStartDate: DateTime.parse(json['week_start_date'] as String),
      createdBy: json['created_by'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      slots: (json['meal_slots'] as List<dynamic>?)
              ?.map((e) => MealSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'week_start_date':
            weekStartDate.toIso8601String().split('T').first,
        'created_by': createdBy,
        'updated_at': updatedAt.toIso8601String(),
      };
}

class GroceryItem {
  const GroceryItem({
    required this.name,
    this.qty,
    this.unit,
  });

  final String name;
  final String? qty;
  final String? unit;

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      name: json['name'] as String,
      qty: json['qty'] as String?,
      unit: json['unit'] as String?,
    );
  }

  String get displayText {
    final parts = <String>[name];
    if (qty != null && qty!.isNotEmpty) parts.add(qty!);
    if (unit != null && unit!.isNotEmpty) parts.add(unit!);
    return parts.join(' ');
  }
}
