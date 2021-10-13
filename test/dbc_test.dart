import 'package:dart_eval/src/dbc/dbc_gen.dart';
import 'package:test/test.dart';

// Functional tests
void main() {
  group('Function tests', () {
    late DbcGen gen;

    setUp(() {
      gen = DbcGen();
    });

    test('Local variable assignment with ints', () {
      final exec = gen.generate('''
      int main() {
        var i = 3;
        {
          var k = 2;
          k = i;
          return k;
        }
      }
      ''');

      expect(3, exec.executeNamed(0, 'main'));
    });
  });
}