/// Client for the TroSky backend: the HTTP client, DTOs and repositories,
/// with mock twins for `API_MODE=mock`.
library;

export 'src/client/api_client.dart';
export 'src/client/interceptors.dart';
export 'src/dto/auth_dto.dart';
export 'src/dto/driver_dto.dart';
export 'src/dto/user_dto.dart';
export 'src/mock/mock_backend.dart';
export 'src/mock/mock_repositories.dart';
export 'src/repositories/auth_repository.dart';
export 'src/repositories/driver_repository.dart';
export 'src/repositories/user_repository.dart';
