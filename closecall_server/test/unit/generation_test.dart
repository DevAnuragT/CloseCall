import 'dart:io';

import 'package:test/test.dart';

import '../../tool/generate.dart';

const raw = '''
/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */
import 'package:serverpod/protocol.dart' as p;
class Protocol {
  List<p.TableDefinition> getTargetTableDefinitions() => targetTableDefinitions;
}
''';

void main() {
  test(
    'structured schema extension is idempotent and independent of formatting',
    () {
      final extended = extendScheduleProtocol(raw);
      expect(
        extended,
        contains('withScheduleConstraints(targetTableDefinitions)'),
      );
      expect(
        extended,
        contains("import '../widget/widget_schedule_schema.dart';"),
      );
      expect(extendScheduleProtocol(extended), extended);
      expect(
        extendScheduleProtocol(
          raw.replaceAll(
            '=> targetTableDefinitions',
            '=>\n targetTableDefinitions',
          ),
        ),
        extended,
      );
    },
  );
  test(
    'unexpected generator shapes fail closed rather than changing RPC code',
    () {
      expect(
        () => extendScheduleProtocol(
          raw.replaceAll('targetTableDefinitions', 'newTargets'),
        ),
        throwsStateError,
      );
      expect(
        () => extendScheduleProtocol(
          raw.replaceAll(
            '=> targetTableDefinitions;',
            '{ return targetTableDefinitions; }',
          ),
        ),
        throwsStateError,
      );
    },
  );
  test(
    'real pinned CLI regeneration roundtrip has no server output drift',
    () async {
      // Runs official generation in isolated scratch, applies the structured
      // extension and compares EVERY server/test-tools output without writes.
      final changed = await generateServer(Directory.current, check: true);
      expect(
        changed,
        isEmpty,
        reason: 'Run dart run tool/generate.dart to refresh output.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
