import 'package:dio/dio.dart';
import 'package:trosky_core/trosky_core.dart';

import '../client/api_client.dart';
import '../dto/safety_dto.dart';

/// Backend/app/api/v1/safety.py — SOS + incident reporting. Idempotency
/// isn't baked in server-side (SOS is rate-limited instead), so the
/// outbox sends with a client-generated key via header for its own
/// replay protection; the backend ignores the header.
abstract interface class SafetyRepository {
  /// `POST /trips/{trip_id}/sos`: emergency alert for a trip the caller
  /// is on. Backend SMSes the user's registered emergency contacts
  /// immediately. Coords are optional — included only if location
  /// permission is already granted.
  Future<Result<SosAlertResponse>> triggerTripSos(
    String tripId,
    TriggerSosRequest request, {
    required String idempotencyKey,
  });

  /// `POST /sos`: off-trip SOS. Coords strongly recommended because
  /// there's no trip context to locate the user.
  Future<Result<SosAlertResponse>> triggerSos(
    TriggerSosRequest request, {
    required String idempotencyKey,
  });

  /// `POST /trips/{trip_id}/incidents`: file a report on a trip the
  /// caller is part of.
  Future<Result<IncidentResponse>> reportIncident(
    String tripId,
    ReportIncidentRequest request, {
    required String idempotencyKey,
  });

  /// `POST /incidents/{id}/photo`: one JPEG or PNG, up to 8 MB. Replaces
  /// any previous photo.
  Future<Result<IncidentResponse>> uploadIncidentPhoto(
    String incidentId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  });
}

class LiveSafetyRepository implements SafetyRepository {
  LiveSafetyRepository(this._dio);
  final Dio _dio;

  @override
  Future<Result<SosAlertResponse>> triggerTripSos(
    String tripId,
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/trips/$tripId/sos',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => SosAlertResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<SosAlertResponse>> triggerSos(
    TriggerSosRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/sos',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => SosAlertResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<IncidentResponse>> reportIncident(
    String tripId,
    ReportIncidentRequest request, {
    required String idempotencyKey,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/trips/$tripId/incidents',
      data: request.toJson(),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    ),
    (data) => IncidentResponse.fromJson(jsonObject(data)),
  );

  @override
  Future<Result<IncidentResponse>> uploadIncidentPhoto(
    String incidentId, {
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) => apiCall(
    () => _dio.post<Object?>(
      '/incidents/$incidentId/photo',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      }),
    ),
    (data) => IncidentResponse.fromJson(jsonObject(data)),
  );
}
