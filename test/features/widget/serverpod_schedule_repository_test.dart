import 'dart:async';

import 'package:closecall/features/widget/data/schedule_repository.dart';
import 'package:closecall/features/widget/data/serverpod_schedule_repository.dart';
import 'package:closecall_client/closecall_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/schedule_fakes.dart';

void main() {
  test(
    'generated calls preserve DTOs, own/partner targets and immutable UTC request',
    () async {
      final own = scheduleTimeline();
      final partner = scheduleTimeline(recipient: 'partner');
      final result = scheduleEntry(recipient: 'partner');
      final calls = <Object>[];
      final stream = StreamController<WidgetTimeline>();
      final repository = ServerpodScheduleRepository.withCalls(
        current: () async => own,
        partner: () async => partner,
        create: (asset, from, until, id) async {
          calls.add((asset, from, until, id));
          expect(from.isUtc && until.isUtc, isTrue);
          return result;
        },
        fallback: (asset) async {
          calls.add(asset);
          return own;
        },
        cancel: (id) async {
          calls.add(id);
        },
        watch: () => stream.stream,
      );
      expect(await repository.currentTimeline(), same(own));
      expect(await repository.partnerTimeline(), same(partner));
      final from = DateTime.parse('2026-10-03T14:05:00+02:00');
      final until = DateTime.parse('2026-10-03T14:15:00+02:00');
      expect(
        await repository.createSchedule('mine', from, until, 'retry-id'),
        same(result),
      );
      expect(calls.single, ('mine', from.toUtc(), until.toUtc(), 'retry-id'));
      expect(await repository.setFallback('own-fallback'), same(own));
      await repository.cancelSchedule('cancel-id');
      expect(calls.sublist(1), ['own-fallback', 'cancel-id']);
      final observed = repository.watchTimeline().first;
      stream.add(own);
      expect(await observed, same(own));
      await stream.close();
    },
  );

  test(
    'typed and transport failures preserve identity rather than masking retries',
    () async {
      for (final failure in [
        ScheduleFailure(code: 'request_conflict'),
        StateError('offline'),
      ]) {
        final repository = ServerpodScheduleRepository.withCalls(
          current: () async => throw failure,
          partner: () async => throw failure,
          create: (_, _, _, _) async => throw failure,
          fallback: (_) async => throw failure,
          cancel: (_) async => throw failure,
          watch: () => Stream.error(failure),
        );
        await expectLater(repository.currentTimeline(), throwsA(same(failure)));
        await expectLater(repository.partnerTimeline(), throwsA(same(failure)));
        await expectLater(
          repository.createSchedule(
            'asset',
            scheduleEpoch,
            scheduleEpoch,
            'id',
          ),
          throwsA(same(failure)),
        );
        await expectLater(
          repository.setFallback('asset'),
          throwsA(same(failure)),
        );
        await expectLater(
          repository.cancelSchedule('id'),
          throwsA(same(failure)),
        );
        await expectLater(
          repository.watchTimeline().first,
          throwsA(same(failure)),
        );
      }
    },
  );

  test(
    'typed schedule error guidance distinguishes pairing, quota and request conflict',
    () {
      expect(
        scheduleErrorMessage(ScheduleFailure(code: 'not_paired')),
        contains('Complete pairing'),
      );
      expect(
        scheduleErrorMessage(ScheduleFailure(code: 'quota_exceeded')),
        contains('quota'),
      );
      expect(
        scheduleErrorMessage(ScheduleFailure(code: 'request_conflict')),
        contains('Discard'),
      );
      expect(
        scheduleErrorMessage(ScheduleFailure(code: 'future_error')),
        contains('future_error'),
      );
      expect(scheduleErrorMessage(StateError('offline')), contains('offline'));
    },
  );
}
