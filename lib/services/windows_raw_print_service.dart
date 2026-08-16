import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

final class _DocInfo1 extends Struct {
  external Pointer<Utf16> pDocName;
  external Pointer<Utf16> pOutputFile;
  external Pointer<Utf16> pDatatype;
}

typedef _OpenPrinterWNative = Int32 Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);
typedef _OpenPrinterWDart = int Function(
  Pointer<Utf16> pPrinterName,
  Pointer<IntPtr> phPrinter,
  Pointer<Void> pDefault,
);

typedef _ClosePrinterNative = Int32 Function(Pointer<Void> hPrinter);
typedef _ClosePrinterDart = int Function(Pointer<Void> hPrinter);

typedef _StartDocPrinterWNative = Uint32 Function(
  Pointer<Void> hPrinter,
  Uint32 level,
  Pointer<_DocInfo1> pDocInfo,
);
typedef _StartDocPrinterWDart = int Function(
  Pointer<Void> hPrinter,
  int level,
  Pointer<_DocInfo1> pDocInfo,
);

typedef _EndDocPrinterNative = Int32 Function(Pointer<Void> hPrinter);
typedef _EndDocPrinterDart = int Function(Pointer<Void> hPrinter);

typedef _StartPagePrinterNative = Int32 Function(Pointer<Void> hPrinter);
typedef _StartPagePrinterDart = int Function(Pointer<Void> hPrinter);

typedef _EndPagePrinterNative = Int32 Function(Pointer<Void> hPrinter);
typedef _EndPagePrinterDart = int Function(Pointer<Void> hPrinter);

typedef _WritePrinterNative = Int32 Function(
  Pointer<Void> hPrinter,
  Pointer<Void> pBuf,
  Uint32 cbBuf,
  Pointer<Uint32> pcWritten,
);
typedef _WritePrinterDart = int Function(
  Pointer<Void> hPrinter,
  Pointer<Void> pBuf,
  int cbBuf,
  Pointer<Uint32> pcWritten,
);

typedef _GetDefaultPrinterWNative = Int32 Function(
  Pointer<Utf16> pszBuffer,
  Pointer<Uint32> pcchBuffer,
);
typedef _GetDefaultPrinterWDart = int Function(
  Pointer<Utf16> pszBuffer,
  Pointer<Uint32> pcchBuffer,
);

class WindowsRawPrintService {
  WindowsRawPrintService._();

  static bool get isAvailable => Platform.isWindows;

  static final DynamicLibrary _winspool = DynamicLibrary.open('winspool.drv');

  static final _OpenPrinterWDart _openPrinter = _winspool
      .lookupFunction<_OpenPrinterWNative, _OpenPrinterWDart>('OpenPrinterW');
  static final _ClosePrinterDart _closePrinter = _winspool
      .lookupFunction<_ClosePrinterNative, _ClosePrinterDart>('ClosePrinter');
  static final _StartDocPrinterWDart _startDocPrinter =
      _winspool.lookupFunction<_StartDocPrinterWNative, _StartDocPrinterWDart>(
    'StartDocPrinterW',
  );
  static final _EndDocPrinterDart _endDocPrinter = _winspool
      .lookupFunction<_EndDocPrinterNative, _EndDocPrinterDart>(
    'EndDocPrinter',
  );
  static final _StartPagePrinterDart _startPagePrinter = _winspool
      .lookupFunction<_StartPagePrinterNative, _StartPagePrinterDart>(
    'StartPagePrinter',
  );
  static final _EndPagePrinterDart _endPagePrinter = _winspool
      .lookupFunction<_EndPagePrinterNative, _EndPagePrinterDart>(
    'EndPagePrinter',
  );
  static final _WritePrinterDart _writePrinter = _winspool
      .lookupFunction<_WritePrinterNative, _WritePrinterDart>('WritePrinter');
  static final _GetDefaultPrinterWDart _getDefaultPrinter =
      _winspool.lookupFunction<_GetDefaultPrinterWNative, _GetDefaultPrinterWDart>(
    'GetDefaultPrinterW',
  );

  static Future<String> defaultPrinterName() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Raw USB printing is only available on Windows.');
    }

    final length = calloc<Uint32>()..value = 0;
    try {
      _getDefaultPrinter(nullptr, length);
      if (length.value <= 0) {
        throw StateError('No default Windows printer is configured.');
      }

      final bufferBytes = calloc<Uint16>(length.value);
      final buffer = bufferBytes.cast<Utf16>();
      try {
        final ok = _getDefaultPrinter(buffer, length) != 0;
        if (!ok) {
          throw StateError('Unable to read the default Windows printer.');
        }
        return buffer.toDartString();
      } finally {
        calloc.free(bufferBytes);
      }
    } finally {
      calloc.free(length);
    }
  }

  static Future<void> printPlainText({
    required String text,
    String? printerName,
    String jobName = 'Manage Care Receipt',
    bool cutPaper = true,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Plain text USB printing is only available on Windows.');
    }

    final targetPrinter = (printerName ?? await defaultPrinterName()).trim();
    if (targetPrinter.isEmpty) {
      throw StateError('No Windows printer selected.');
    }

    final bytes = _buildReceiptBytes(text, cutPaper: cutPaper);
    _writeRawBytes(
      printerName: targetPrinter,
      jobName: jobName,
      bytes: bytes,
    );
  }

  static Uint8List _buildReceiptBytes(String text, {required bool cutPaper}) {
    final normalized = text
        .replaceAll('₦', 'NGN ')
        .replaceAll('â‚¦', 'NGN ')
        .replaceAll('•', '-')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final bytes = <int>[
      0x1B,
      0x40,
      ...utf8.encode(normalized),
      0x0A,
      0x0A,
      0x0A,
    ];

    if (cutPaper) {
      bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
    }

    return Uint8List.fromList(bytes);
  }

  static void _writeRawBytes({
    required String printerName,
    required String jobName,
    required Uint8List bytes,
  }) {
    final printerNamePtr = printerName.toNativeUtf16();
    final printerHandlePtr = calloc<IntPtr>();
    final docInfo = calloc<_DocInfo1>();
    final jobNamePtr = jobName.toNativeUtf16();
    final dataTypePtr = 'RAW'.toNativeUtf16();
    final dataPtr = calloc<Uint8>(bytes.length);
    final writtenPtr = calloc<Uint32>();

    try {
      final openOk = _openPrinter(printerNamePtr, printerHandlePtr, nullptr) != 0;
      if (!openOk || printerHandlePtr.value == 0) {
        throw StateError('Unable to open Windows printer "$printerName".');
      }

      final printerHandle = Pointer<Void>.fromAddress(printerHandlePtr.value);

      docInfo.ref
        ..pDocName = jobNamePtr
        ..pOutputFile = nullptr
        ..pDatatype = dataTypePtr;

      final jobId = _startDocPrinter(printerHandle, 1, docInfo);
      if (jobId == 0) {
        throw StateError('Unable to start print job on "$printerName".');
      }

      var pageStarted = false;
      try {
        pageStarted = _startPagePrinter(printerHandle) != 0;
        if (!pageStarted) {
          throw StateError('Unable to start printer page on "$printerName".');
        }

        final nativeBytes = dataPtr.asTypedList(bytes.length);
        nativeBytes.setAll(0, bytes);

        final writeOk = _writePrinter(
              printerHandle,
              dataPtr.cast<Void>(),
              bytes.length,
              writtenPtr,
            ) !=
            0;
        if (!writeOk || writtenPtr.value != bytes.length) {
          throw StateError(
            'Windows printer accepted ${writtenPtr.value} of ${bytes.length} bytes.',
          );
        }
      } finally {
        if (pageStarted) {
          _endPagePrinter(printerHandle);
        }
        _endDocPrinter(printerHandle);
      }

      _closePrinter(printerHandle);
      printerHandlePtr.value = 0;
    } finally {
      if (printerHandlePtr.value != 0) {
        _closePrinter(Pointer<Void>.fromAddress(printerHandlePtr.value));
      }
      calloc.free(printerNamePtr);
      calloc.free(printerHandlePtr);
      calloc.free(docInfo);
      calloc.free(jobNamePtr);
      calloc.free(dataTypePtr);
      calloc.free(dataPtr);
      calloc.free(writtenPtr);
    }
  }
}
