import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/safety_outbox.dart';

final safetyOutboxProvider = Provider<SafetyOutbox>((ref) => SafetyOutbox());
