// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_mailparser_suppression.dart';

const _tracerName = 'dartastic_otel_libs_mailparser';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class MailparserResult {
  const MailparserResult({
    this.accountId,
    this.inboxId,
    this.inboxName,
    this.emailId,
    this.parseStatus,
    this.fieldsExtracted,
    this.attachmentsParsed,
    this.emailSizeBytes,
    this.webhookDelivered,
    this.webhookResponseCode,
    this.processingMs,
    this.creditsConsumed,
    this.statusCode,
  });

  final String? accountId;

  /// Mailparser mailbox id (each parsing inbox has its own `@mailparser.io`
  /// address).
  final String? inboxId;

  final String? inboxName;

  /// Source email id once received.
  final String? emailId;

  /// `parsed` / `unparsed` / `partial` / `rejected` / `received`.
  final String? parseStatus;

  /// Number of fields the rules extracted from the body/subject.
  final int? fieldsExtracted;

  /// PDFs/CSVs/etc. parsed from the attachment chain.
  final int? attachmentsParsed;

  final int? emailSizeBytes;

  /// `true` if the parsed payload was successfully forwarded to a
  /// configured webhook destination.
  final bool? webhookDelivered;

  /// HTTP code from the downstream webhook endpoint.
  final int? webhookResponseCode;

  final int? processingMs;

  /// Credits charged — Mailparser bills per parsed email above the
  /// plan quota.
  final int? creditsConsumed;

  final int? statusCode;
}

class MailparserCallResult<T> {
  const MailparserCallResult({required this.value, this.result});
  final T value;
  final MailparserResult? result;
}

/// Wraps a Mailparser API call in a CLIENT span. [operation] is one
/// of `inboxes.list`, `inboxes.create`, `emails.list`, `emails.get`,
/// `emails.parse`, `emails.reparse`, `downloads.csv`,
/// `downloads.json`, `webhooks.list`, `webhooks.deliver`.
Future<T> tracedMailparser<T>({
  required String operation,
  required Future<MailparserCallResult<T>> Function() invoke,
}) async {
  if (mailparserInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'mailparser',
    'rpc.method': operation,
    'mailparser.operation': operation,
  };

  final span = _tracer().startSpan(
    'mailparser $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.accountId != null) {
        extras.add(OTel.attributeString(
          'mailparser.account.id',
          r.result!.accountId!,
        ));
      }
      if (r.result!.inboxId != null) {
        extras.add(OTel.attributeString(
          'mailparser.inbox.id',
          r.result!.inboxId!,
        ));
      }
      if (r.result!.inboxName != null) {
        extras.add(OTel.attributeString(
          'mailparser.inbox.name',
          r.result!.inboxName!,
        ));
      }
      if (r.result!.emailId != null) {
        extras.add(OTel.attributeString(
          'mailparser.email.id',
          r.result!.emailId!,
        ));
      }
      if (r.result!.parseStatus != null) {
        extras.add(OTel.attributeString(
          'mailparser.parse.status',
          r.result!.parseStatus!,
        ));
        if (r.result!.parseStatus == 'unparsed' ||
            r.result!.parseStatus == 'rejected') {
          span.setStatus(
            SpanStatusCode.Error,
            'Mailparser ${r.result!.parseStatus}',
          );
        }
      }
      if (r.result!.fieldsExtracted != null) {
        extras.add(OTel.attributeInt(
          'mailparser.fields.extracted',
          r.result!.fieldsExtracted!,
        ));
      }
      if (r.result!.attachmentsParsed != null) {
        extras.add(OTel.attributeInt(
          'mailparser.attachments.parsed',
          r.result!.attachmentsParsed!,
        ));
      }
      if (r.result!.emailSizeBytes != null) {
        extras.add(OTel.attributeInt(
          'mailparser.email.size_bytes',
          r.result!.emailSizeBytes!,
        ));
      }
      if (r.result!.webhookDelivered != null) {
        extras.add(OTel.attributeBool(
          'mailparser.webhook.delivered',
          r.result!.webhookDelivered!,
        ));
      }
      if (r.result!.webhookResponseCode != null) {
        extras.add(OTel.attributeInt(
          'mailparser.webhook.response.status_code',
          r.result!.webhookResponseCode!,
        ));
      }
      if (r.result!.processingMs != null) {
        extras.add(OTel.attributeInt(
          'mailparser.processing_ms',
          r.result!.processingMs!,
        ));
      }
      if (r.result!.creditsConsumed != null) {
        extras.add(OTel.attributeInt(
          'mailparser.credits.consumed',
          r.result!.creditsConsumed!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Mailparser HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
