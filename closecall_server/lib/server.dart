import 'src/auth/authentication.dart';
import 'src/generated/serverpod.dart';

/// Starts the API with JWT authentication and persistent PostgreSQL storage.
Future<void> run(List<String> args) async {
  final pod = Serverpod(args);
  configureAuthentication(pod);
  await pod.start();
}
