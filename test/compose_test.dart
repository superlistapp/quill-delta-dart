import 'dart:convert';
import 'dart:math';

import 'package:quill_delta/quill_delta.dart';
import 'package:test/test.dart';

/// The compose algorithm before retained operations were reused, kept as the
/// reference that [Delta.compose] must match exactly.
Delta _referenceCompose(Delta a, Delta b) {
  final result = Delta();
  final thisIter = DeltaIterator(a);
  final otherIter = DeltaIterator(b);

  Operation? composeOperation() {
    if (otherIter.isNextInsert) return otherIter.next();
    if (thisIter.isNextDelete) return thisIter.next();

    final length = min(thisIter.peekLength(), otherIter.peekLength());
    final thisOp = thisIter.next(length);
    final otherOp = otherIter.next(length);

    if (otherOp.isRetain) {
      final attributes = Delta.composeAttributes(
        thisOp.attributes,
        otherOp.attributes,
        keepNull: thisOp.isRetain,
      );
      if (thisOp.isRetain) return Operation.retain(thisOp.length, attributes);
      return Operation.insert(thisOp.data, attributes);
    }
    if (thisOp.isRetain) return otherOp;
    return null;
  }

  while (thisIter.hasNext || otherIter.hasNext) {
    final newOp = composeOperation();
    if (newOp != null) result.push(newOp);
  }
  return result..trim();
}

const _attributePool = <Map<String, dynamic>?>[
  null,
  {},
  {'bold': true},
  {'bold': null},
  {'bold': true, 'italic': null},
  {'node_id': 'a', 'task_id': 't'},
  {'node_id': 'b', 'task_id': 't', 'draft': false},
];

Map<String, dynamic>? _attributes(Random random) =>
    _attributePool[random.nextInt(_attributePool.length)];

Object _insertData(Random random) => random.nextInt(5) == 0
    ? {'image': 'img${random.nextInt(3)}'}
    : 'abcdef\n'.substring(0, 1 + random.nextInt(7));

/// Builds operations without [Delta.push], so adjacent operations can share
/// attributes the way deltas built with [DeltaUnsafe.fromOperationsUnsafe] do.
Delta _randomDocument(Random random) {
  return DeltaUnsafe.fromOperationsUnsafe([
    for (var i = random.nextInt(8); i > 0; i--)
      Operation.insert(_insertData(random), _attributes(random)),
  ]);
}

Operation _randomChangeOperation(Random random) {
  final kind = random.nextInt(3);
  if (kind == 0) {
    return Operation.retain(1 + random.nextInt(9), _attributes(random));
  }
  if (kind == 1) return Operation.delete(1 + random.nextInt(4));
  return Operation.insert(_insertData(random), _attributes(random));
}

Delta _randomChange(Random random) {
  return DeltaUnsafe.fromOperationsUnsafe([
    for (var i = random.nextInt(6); i > 0; i--) _randomChangeOperation(random),
  ]);
}

void _expectSameAsReference(Delta a, Delta b) {
  final actual = a.compose(b);
  final expected = _referenceCompose(a, b);
  final reason = 'a: $a\nb: $b';
  expect(actual.toList(), expected.toList(), reason: reason);
  expect(
    jsonEncode(actual.toJson()),
    jsonEncode(expected.toJson()),
    reason: reason,
  );
}

void main() {
  group('Delta.compose', () {
    test('reuses whole operations covered by a plain retain', () {
      final document = Delta()
        ..insert('first\n', {'node_id': '1'})
        ..insert('second\n', {'node_id': '2'})
        ..insert('third\n', {'node_id': '3'});
      final change = Delta()
        ..retain(8)
        ..insert('!');

      final result = document.compose(change);

      expect(
        result,
        Delta()
          ..insert('first\n', {'node_id': '1'})
          ..insert('se', {'node_id': '2'})
          ..insert('!')
          ..insert('cond\n', {'node_id': '2'})
          ..insert('third\n', {'node_id': '3'}),
      );
      expect(result.elementAt(0), same(document.elementAt(0)));
      expect(result.elementAt(4), same(document.elementAt(2)));
    });

    test('drops null attribute values from retained inserts', () {
      final document = Delta()..insert('abc', {'bold': null, 'italic': true});

      expect(
        document.compose(Delta()..retain(1)),
        Delta()..insert('abc', {'italic': true}),
      );
    });

    test('turns empty attributes of retained inserts into null', () {
      final document = DeltaUnsafe.fromOperationsUnsafe([
        Operation.insert('abc', {}),
      ]);

      final result = document.compose(Delta()..retain(1));

      expect(
          jsonEncode(result),
          jsonEncode([
            {'insert': 'abc'},
          ]));
    });

    test('keeps null attribute values of retained retains', () {
      final change = Delta()..retain(3, {'bold': null});

      expect(
        change.compose(Delta()..retain(5)),
        Delta()..retain(3, {'bold': null}),
      );
    });

    test('merges reused operations with the previous result operation', () {
      final document = DeltaUnsafe.fromOperationsUnsafe([
        Operation.insert('ab'),
        Operation.insert('cd'),
      ]);

      expect(document.compose(Delta()..retain(1)), Delta()..insert('abcd'));
    });

    test('matches the reference algorithm for random deltas', () {
      final random = Random(7805);
      for (var i = 0; i < 20000; i++) {
        final a =
            random.nextBool() ? _randomDocument(random) : _randomChange(random);
        _expectSameAsReference(a, _randomChange(random));
      }
    });
  });
}
