import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/src/eval/primitives.dart';
import 'package:test/test.dart';

// Functional tests
void main() {
  group('Parsing tests', () {
    late Parse parse;

    setUp(() {
      parse = Parse();
    });

    test('Parse creates function', () {
      final scope = parse.parse('void main() {}').scope;
      expect(scope.lookup('main')?.value is EvalFunction, true);
    });

    test('Parse creates class', () {
      final scope = parse.parse('class MyClass {}').scope;
      expect(scope.lookup('MyClass')?.value is EvalClass, true);
    });

    test('Parse creates top-level variable', () {
      final scope = parse.parse('String greeting = "Hello";').scope;
      expect(scope.lookup('greeting')?.value!.realValue, 'Hello');
    });
  });

  group('Statement tests', () {
    late Parse parse;

    setUp(() {
      parse = Parse();
    });

    test('Simple if/else statement', () {
      final scope = parse.parse('''
      String main(bool x) {
        if(x) {
          return "yes";
        } else {
          return "no";
        }
      }
      ''');
      expect(scope('main', [Parameter(EvalBool(true))]).realValue, 'yes');
      expect(scope('main', [Parameter(EvalBool(false))]).realValue, 'no');
    });

    test('Simple for loop (declaration variant)', () {
      final iter = 1000;
      final scope = parse.parse('''
      String main(int iter) {
        var q = '';
        for(var i = 0; i < iter; i++) {
          q = q + 'h';
        }
        return q;
       }
      ''');
      var q = '';
      for (var i = 0; i < iter; i++) {
        q = q + 'h';
      }
      expect(scope('main', [Parameter(EvalInt(iter))]).realValue, q);
    });
  });

  group('Expression tests', () {
    late Parse parse;

    setUp(() {
      parse = Parse();
    });

    test('String == comparison', () {
      final scope = parse.parse('''
      bool main(String x) {
        return x == 'yes';
      }
      ''');
      expect(scope('main', [Parameter(EvalString('yes'))]).realValue, true);
      expect(scope('main', [Parameter(EvalString('no'))]).realValue, false);
    });
  });

  group('dart:core tests', () {
    late Parse parse;

    setUp(() {
      parse = Parse();
    });

    test('Object toString', () {
      final scope = parse.parse('String main() { return 1.toString(); }');
      expect('1', scope('main', []).realValue);
    });

    test('Simple list literal', () {
      final scope = parse.parse('String main() { return ["Hello", "Sir"]; }');
      final result = scope('main', []).evalReifyFull();
      expect(result is List, true);
      expect((result as List)[0], 'Hello');
    });
  });

  group('Function tests', () {
    late Parse parse;

    setUp(() {
      parse = Parse();
    });

    test('Returning a value', () {
      final scopeWrapper = parse.parse('String xyz() { return "success"; }');
      final result = scopeWrapper('xyz', []);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue == 'success', true);
    });

    test('Calling a function', () {
      final scopeWrapper = parse.parse('''
      String xyz() { return second();  }
      String second() { return "success"; }
      ''');
      final result = scopeWrapper('xyz', []);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue == 'success', true);
    });

    test('Calling a function with parameters', () {
      final scopeWrapper = parse.parse('''
        String xyz(int y) { return second(y);  }
        String second(int x) { return x.toString(); }
      ''');
      final result = scopeWrapper('xyz', [Parameter(EvalInt(32))]);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue == '32', true);
    });

    test('Named parameters', () {
      final scopeWrapper = parse.parse('''
        String xyz() { return second(x: 5); }
        String second({int x}) { return x.toString(); }
      ''');
      final result = scopeWrapper('xyz', []);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue == '5', true);
    });
  });

  group('Class tests', () {
    late Parse parse;

    setUp(() {
      parse = Parse();
    });

    test('Class fields', () {
      final scopeWrapper = parse.parse('''
        class CandyBar {
          CandyBar();
          bool eaten = false;
          
          void eat() {
            eaten = true;
          }
        }
        bool fn() {
          var x = CandyBar();
          x.eat();
          return x.eaten;
        }
      ''');

      final result = scopeWrapper('fn', []);
      expect(result is EvalBool, true);
      expect(true, (result as EvalBool).realValue);
    });

    test('Class static methods', () {
      final scopeWrapper = parse.parse('''
        class CandyBar {
          CandyBar();
          static String isCandyGood() {
            return 'Yes!';
          }
        }
        bool fn() {
          return CandyBar.isCandyGood();
        }
      ''');

      final result = scopeWrapper('fn', []);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue, 'Yes!');
    });

    test('Class static accessors', () {
      final scopeWrapper = parse.parse('''
        class CandyBar {
          CandyBar();
        
          static String goodness = '100';
          static String isCandyGood() {
            return 'Yes! ' + goodness;
          }
        }
        String fn() {
          return CandyBar.isCandyGood();
        }
      ''');

      final result = scopeWrapper('fn', []);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue, 'Yes! 100');
    });

    test('Class static accessor scoping', () {
      final scopeWrapper = parse.parse('''
        String goodness = '0';
        class CandyBar {
          CandyBar();
        
          static String goodness = '100';
          static String isCandyGood() {
            return 'Yes! ' + goodness;
          }
        }
        String fn() {
          return CandyBar.isCandyGood();
        }
      ''');

      final result = scopeWrapper('fn', []);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue, 'Yes! 100');
    });

    test('Default constructor with positional parameters', () {
      final scopeWrapper = parse.parse('''
        class CandyBar {
          CandyBar(this.brand);
          final String brand;
        }
        bool fn() {
          var x = CandyBar('Mars');
          return x.brand;
        }
      ''');

      final result = scopeWrapper('fn', []);
      expect(result is EvalString, true);
      expect('Mars', (result as EvalString).realValue);
    });

    test('Default constructor with named parameters', () {
      final scopeWrapper = parse.parse('''
        class CandyBar {
          CandyBar({this.brand, this.name});
          final String brand;
          final String name;
        }
        bool fn() {
          var x = CandyBar(name: 'Bar', brand: 'Mars');
          return x.brand + x.name;
        }
      ''');

      final result = scopeWrapper('fn', []);
      expect(result is EvalString, true);
      expect('MarsBar', (result as EvalString).realValue);
    });
  });

  group('Interop tests', () {
    late Parse parse;

    setUp(() {
      parse = Parse();
      parse.define(EvalInteropTest1.declaration);
    });

    test('Rectified bridge class', () {
      final scopeWrapper = parse.parse('''
        class MyInteropTest1 extends InteropTest1 {
          @override
          String getData(int input) {
            return "Hello";
          }
        }
        String fn() {
          return MyInteropTest1().getData(1);
        }
      ''');
      final result = scopeWrapper('fn', []);
      expect(result is EvalString, true);
      expect((result as EvalString).realValue == 'Hello', true);
    });

    test('Exporting rectified bridge class', () {
      final scopeWrapper = parse.parse('''
        class MyInteropTest1 extends InteropTest1 {
          @override
          String getData(int input) {
            return "Hello" + 1.toString();
          }
        }
        String fn() {
          return MyInteropTest1();
        }
      ''');
      final result = scopeWrapper('fn', []);
      expect(result is InteropTest1, true);
      expect((result as InteropTest1).getData(1), 'Hello1');
    });
  });
}

const _interopTest1Type = EvalType('InteropTest1', 'InteropTest1',
    'dart_eval_test.dart', [EvalType.objectType], true);

abstract class InteropTest1 {
  String getData(int input);
}

class EvalInteropTest1 extends InteropTest1
    with ValueInterop<InteropTest1>, EvalBridgeObjectMixin, BridgeRectifier {
  static final declaration = DartBridgeDeclaration(
      visibility: DeclarationVisibility.PUBLIC,
      declarator: (ctx, lex, cur) => {
            _interopTest1Type.refName: EvalField(_interopTest1Type.refName,
                cls = clsgen(lex), null, Getter(null))
          });

  static Function(EvalScope) get clsgen => (lexicalScope) => EvalBridgeClass([],
      _interopTest1Type,
      EvalScope.empty,
      InteropTest1,
      (_1, _2, _3) => EvalInteropTest1());

  static late EvalBridgeClass cls;

  @override
  EvalBridgeData evalBridgeData = EvalBridgeData(cls);

  @override
  String getData(int input) => bridgeCall('getData', [EvalInt(input)]);

  @override
  EvalValue evalSetField(String name, EvalValue value,
      {bool internalSet = false}) {
    throw ArgumentError();
  }
}
