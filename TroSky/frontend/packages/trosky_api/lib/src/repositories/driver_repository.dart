import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/driver_dto.dart';

/// `/drivers/*` (backend/app/api/v1/drivers.py).
abstract interface class DriverRepository {
  /// The signed-in driver's profile. 404 `NOT_FOUND` before the driver has
  /// registered one (D-01); 403 `FORBIDDEN` for an account without the
  /// driver role.
  Future<Result<DriverResponse>> getMe();
}

/// [DriverRepository] against the backend.
class LiveDriverRepository implements DriverRepository {
  LiveDriverRepository(this._dio);

  final Dio _dio;

  @override
  Future<Result<DriverResponse>> getMe() => apiCall(
    () => _dio.get<Object?>('/drivers/me'),
    (data) => DriverResponse.fromJson(jsonObject(data)),
  );
}
