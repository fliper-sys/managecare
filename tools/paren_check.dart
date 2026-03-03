import 'dart:io';
import 'dart:math';

void main(List<String> args) {
  final path = args.isNotEmpty
      ? args[0]
      : 'lib/presentation/industry_specific/hotel/screens/room_list_screen.dart';
  final lines = File(path).readAsLinesSync();
  int lineNo = 0;
  final stack = <Map<String, int>>[]; // stores {'line':lineNo, 'col':i}
  for (final line in lines) {
    lineNo++;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '(') stack.add({'line': lineNo, 'col': i});
      if (c == ')') {
        if (stack.isNotEmpty) {
          stack.removeLast();
        } else {
          print('Unmatched ) at line $lineNo col $i');
        }
      }
    }
  }
  if (stack.isEmpty) {
    print('All parentheses matched');
  } else {
    print('Unmatched opens: ${stack.length}');
    for (var e in stack) {
      print('Unmatched ( at line ${e['line']} col ${e['col']}');
    }
    final last = stack.last;
    print('Context around first unmatched:');
    final ln = last['line'] as int;
    for (int i = max(1, ln - 3); i <= min(lines.length, ln + 3); i++) {
      print('${i.toString().padLeft(3)} | ${lines[i - 1]}');
    }
  }
}

