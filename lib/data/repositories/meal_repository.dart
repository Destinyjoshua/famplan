import 'package:famplan/config/supabase.dart';
import 'package:famplan/data/models/meal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MealRepository {
  SupabaseClient get _client => SupabaseConfig.client;
  final _uuid = const Uuid();

  DateTime mondayOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  Future<MealPlan> getOrCreateMealPlan(String familyId, DateTime weekStart) async {
    final weekDate = mondayOfWeek(weekStart).toIso8601String().split('T').first;

    var response = await _client
        .from('meal_plans')
        .select('*, meal_slots(*)')
        .eq('family_id', familyId)
        .eq('week_start_date', weekDate)
        .maybeSingle();

    if (response == null) {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw StateError('Not authenticated');

      final now = DateTime.now().toIso8601String();
      response = await _client.from('meal_plans').insert({
        'id': _uuid.v4(),
        'family_id': familyId,
        'week_start_date': weekDate,
        'created_by': userId,
        'updated_at': now,
      }).select('*, meal_slots(*)').single();
    }

    return MealPlan.fromJson(response);
  }

  Future<MealSlot> upsertMealSlot({
    required String mealPlanId,
    required String familyId,
    required int dayOfWeek,
    required String mealType,
    String? mealName,
    String? cookId,
    List<MealIngredient>? ingredients,
  }) async {
    final existing = await _client
        .from('meal_slots')
        .select()
        .eq('meal_plan_id', mealPlanId)
        .eq('day_of_week', dayOfWeek)
        .eq('meal_type', mealType)
        .maybeSingle();

    final payload = {
      'meal_plan_id': mealPlanId,
      'family_id': familyId,
      'day_of_week': dayOfWeek,
      'meal_type': mealType,
      'meal_name': mealName,
      'cook_id': cookId,
      'ingredients': ingredients?.map((e) => e.toJson()).toList() ?? [],
    };

    final Map<String, dynamic> response;
    if (existing != null) {
      response = await _client
          .from('meal_slots')
          .update(payload)
          .eq('id', existing['id'] as String)
          .select()
          .single();
    } else {
      response = await _client.from('meal_slots').insert({
        'id': _uuid.v4(),
        ...payload,
      }).select().single();
    }

    return MealSlot.fromJson(response);
  }

  Future<List<GroceryItem>> generateGroceryList(String mealPlanId) async {
    final response = await _client.rpc(
      'generate_grocery_list',
      params: {'meal_plan_id': mealPlanId},
    );

    if (response is List) {
      return response
          .map((e) => GroceryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }
}
