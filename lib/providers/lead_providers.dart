import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/lead_service.dart';

/// Lead-capture service for the embeddable chatbot. Override in tests.
final leadServiceProvider = Provider<ILeadService>((ref) => LeadService());
