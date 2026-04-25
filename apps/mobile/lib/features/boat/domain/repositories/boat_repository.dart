import 'package:navis_mobile/features/boat/domain/entities/boat.dart';
import 'package:navis_mobile/shared/models/paginated_response.dart';

abstract class BoatRepository {
  Future<PaginatedResponse<Boat>> getBoats({String? cursor, int limit = 20});
  Future<Boat> getBoat(String id);
  Future<Boat> createBoat(Boat boat);
  Future<Boat> updateBoat(Boat boat);
  Future<void> deleteBoat(String id);
}
