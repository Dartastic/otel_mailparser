// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_mailparser/otel_mailparser.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_mailparser-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('emails.parse records inbox + fields + credits', () async {
    await tracedMailparser<String>(
      operation: 'emails.parse',
      invoke: () async => const MailparserCallResult(
        value: 'ok',
        result: MailparserResult(
          accountId: 'acc_1',
          inboxId: 'inb_1',
          inboxName: 'amazon-orders',
          emailId: 'em_1',
          parseStatus: 'parsed',
          fieldsExtracted: 12,
          attachmentsParsed: 1,
          emailSizeBytes: 88000,
          webhookDelivered: true,
          webhookResponseCode: 200,
          processingMs: 420,
          creditsConsumed: 1,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('mailparser emails.parse')!);
    expect(a['mailparser.inbox.name'], 'amazon-orders');
    expect(a['mailparser.parse.status'], 'parsed');
    expect(a['mailparser.fields.extracted'], 12);
    expect(a['mailparser.webhook.delivered'], true);
    expect(a['mailparser.credits.consumed'], 1);
  });

  test('unparsed status sets span error', () async {
    await tracedMailparser<String>(
      operation: 'emails.parse',
      invoke: () async => const MailparserCallResult(
        value: 'ok',
        result: MailparserResult(
          inboxId: 'inb_1',
          emailId: 'em_2',
          parseStatus: 'unparsed',
        ),
      ),
    );
    expect(
      spans.findSpanByName('mailparser emails.parse')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutMailparserInstrumentationAsync(() async {
      await tracedMailparser<String>(
        operation: 'inboxes.list',
        invoke: () async => const MailparserCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('mailparser '), isEmpty);
  });
}
