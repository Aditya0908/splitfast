import 'package:flutter_test/flutter_test.dart';
import 'package:splitfast/models/bill_item.dart';
import 'package:splitfast/models/bill_state.dart';
import 'package:splitfast/engine/split_engine.dart';

void main() {
  // ──────────────────────────────────────────────
  // Helper: assert the sum of all splits == finalTotal exactly
  // ──────────────────────────────────────────────
  void expectNoDrift(Map<String, SplitResult> results, double finalTotal) {
    final sum = results.values.fold<double>(0.0, (s, r) => s + r.finalAmount);
    expect(
      double.parse(sum.toStringAsFixed(2)),
      finalTotal,
      reason: 'Sum of splits must exactly equal finalTotal (no drift)',
    );
  }

  group('Proportional Split – basic scenarios', () {
    test('Two people, two items, each assigned one item', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Burger',
          price: 200,
          assignedParticipantIds: ['alice'],
        ),
        BillItem(
          id: '2',
          name: 'Pizza',
          price: 300,
          assignedParticipantIds: ['bob'],
        ),
      ];
      final bill = BillState(subtotal: 500, finalTotal: 500);

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['alice', 'bob'],
        payerId: 'alice',
      );

      expect(results['alice']!.finalAmount, 200.0);
      expect(results['bob']!.finalAmount, 300.0);
      expectNoDrift(results, 500);
    });

    test('Three people share all items equally', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Pasta',
          price: 300,
          assignedParticipantIds: ['a', 'b', 'c'],
        ),
        BillItem(
          id: '2',
          name: 'Salad',
          price: 150,
          assignedParticipantIds: ['a', 'b', 'c'],
        ),
      ];
      final bill = BillState(subtotal: 450, finalTotal: 450);

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b', 'c'],
        payerId: 'a',
      );

      expect(results['b']!.finalAmount, 150.0);
      expect(results['c']!.finalAmount, 150.0);
      expectNoDrift(results, 450);
    });

    test('Mixed assignment – some items shared, some individual', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Shared Appetizer',
          price: 240,
          assignedParticipantIds: ['a', 'b', 'c'],
        ),
        BillItem(
          id: '2',
          name: 'Steak',
          price: 500,
          assignedParticipantIds: ['a'],
        ),
        BillItem(
          id: '3',
          name: 'Fish',
          price: 400,
          assignedParticipantIds: ['b'],
        ),
        BillItem(
          id: '4',
          name: 'Soup',
          price: 160,
          assignedParticipantIds: ['c'],
        ),
      ];
      // subtotal = 240 + 500 + 400 + 160 = 1300
      final bill = BillState(subtotal: 1300, finalTotal: 1300);

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b', 'c'],
        payerId: 'a',
      );

      // a: 80 (appetizer share) + 500 = 580
      // b: 80 + 400 = 480
      // c: 80 + 160 = 240
      expect(results['a']!.finalAmount, 580.0);
      expect(results['b']!.finalAmount, 480.0);
      expect(results['c']!.finalAmount, 240.0);
      expectNoDrift(results, 1300);
    });
  });

  group('Proportional Split – with tax, service charge, discount', () {
    test('Tax and service charge distributed proportionally', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Expensive Dish',
          price: 800,
          assignedParticipantIds: ['a'],
        ),
        BillItem(
          id: '2',
          name: 'Cheap Dish',
          price: 200,
          assignedParticipantIds: ['b'],
        ),
      ];
      // subtotal=1000, tax=100(10%), sc=50(5%), discount=0 => final=1150
      final bill = BillState(
        subtotal: 1000,
        totalTax: 100,
        serviceCharge: 50,
        discount: 0,
        finalTotal: 1150,
      );

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b'],
        payerId: 'a',
      );

      // a's ratio = 800/1000 = 0.8  =>  800 + 80(tax) + 40(sc) = 920
      // b's ratio = 200/1000 = 0.2  =>  200 + 20(tax) + 10(sc) = 230
      expect(results['a']!.finalAmount, 920.0);
      expect(results['b']!.finalAmount, 230.0);
      expectNoDrift(results, 1150);
    });

    test('Discount distributed proportionally', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Item A',
          price: 600,
          assignedParticipantIds: ['a', 'b'],
        ),
        BillItem(
          id: '2',
          name: 'Item B',
          price: 400,
          assignedParticipantIds: ['b'],
        ),
      ];
      // subtotal=1000, discount=100, tax=50, sc=0 => final=950
      final bill = BillState(
        subtotal: 1000,
        totalTax: 50,
        serviceCharge: 0,
        discount: 100,
        finalTotal: 950,
      );

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b'],
        payerId: 'a',
      );

      // a raw: 300  (600/2)
      // b raw: 300 + 400 = 700
      // a ratio: 300/1000 = 0.3  =>  300 - 30(disc) + 15(tax) = 285
      // b ratio: 700/1000 = 0.7  =>  700 - 70(disc) + 35(tax) = 665
      expect(results['a']!.finalAmount, 285.0);
      expect(results['b']!.finalAmount, 665.0);
      expectNoDrift(results, 950);
    });

    test('All modifiers combined', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Biryani',
          price: 350,
          quantity: 2,
          assignedParticipantIds: ['a', 'b', 'c'],
        ),
        BillItem(
          id: '2',
          name: 'Naan',
          price: 50,
          quantity: 4,
          assignedParticipantIds: ['a', 'b', 'c'],
        ),
        BillItem(
          id: '3',
          name: 'Lassi',
          price: 120,
          assignedParticipantIds: ['a'],
        ),
      ];
      // subtotal = 700 + 200 + 120 = 1020
      // discount=50, sc=51, tax=102 => final = 1020 - 50 + 51 + 102 = 1123
      final bill = BillState(
        subtotal: 1020,
        totalTax: 102,
        serviceCharge: 51,
        discount: 50,
        finalTotal: 1123,
      );

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b', 'c'],
        payerId: 'a',
      );

      expectNoDrift(results, 1123);
      // a gets more because of the Lassi
      expect(results['a']!.finalAmount, greaterThan(results['b']!.finalAmount));
      expect(results['b']!.finalAmount, results['c']!.finalAmount);
    });
  });

  group('Drift resolution', () {
    test('Drift from 3-way equal split on indivisible amount goes to payer', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Shared Platter',
          price: 100,
          assignedParticipantIds: ['a', 'b', 'c'],
        ),
      ];
      // 100 / 3 = 33.33 each => sum = 99.99, drift = 0.01
      final bill = BillState(subtotal: 100, finalTotal: 100);

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b', 'c'],
        payerId: 'a',
      );

      expect(results['b']!.finalAmount, 33.33);
      expect(results['c']!.finalAmount, 33.33);
      // Payer absorbs the 0.01 drift
      expect(results['a']!.finalAmount, 33.34);
      expectNoDrift(results, 100);
    });

    test('Negative drift (rounding up) is also absorbed by payer', () {
      // 7-way split of 1000: each = 142.86, sum = 1000.02, drift = -0.02
      final items = [
        BillItem(
          id: '1',
          name: 'Big Item',
          price: 1000,
          assignedParticipantIds: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7'],
        ),
      ];
      final bill = BillState(subtotal: 1000, finalTotal: 1000);

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7'],
        payerId: 'p1',
      );

      expectNoDrift(results, 1000);
      // Non-payers should all be 142.86
      for (final id in ['p2', 'p3', 'p4', 'p5', 'p6', 'p7']) {
        expect(results[id]!.finalAmount, 142.86);
      }
      // Payer absorbs: 1000 - (6 * 142.86) = 1000 - 857.16 = 142.84
      expect(results['p1']!.finalAmount, 142.84);
    });

    test('Large bill with many items — no drift', () {
      final items = List.generate(
        20,
        (i) => BillItem(
          id: 'item_$i',
          name: 'Item $i',
          price: 99.99,
          assignedParticipantIds: ['a', 'b', 'c', 'd', 'e'],
        ),
      );
      // subtotal = 20 * 99.99 = 1999.80
      // tax=200, sc=100, disc=50 => final = 1999.80 + 200 + 100 - 50 = 2249.80
      final bill = BillState(
        subtotal: 1999.80,
        totalTax: 200,
        serviceCharge: 100,
        discount: 50,
        finalTotal: 2249.80,
      );

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b', 'c', 'd', 'e'],
        payerId: 'a',
      );

      expectNoDrift(results, 2249.80);
    });
  });

  group('Quantity handling', () {
    test('Item quantity multiplies the effective price', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Beer',
          price: 150,
          quantity: 3,
          assignedParticipantIds: ['a', 'b'],
        ),
      ];
      // effectiveTotalPrice = 150 * 3 = 450
      final bill = BillState(subtotal: 450, finalTotal: 450);

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b'],
        payerId: 'a',
      );

      expect(results['a']!.finalAmount, 225.0);
      expect(results['b']!.finalAmount, 225.0);
      expectNoDrift(results, 450);
    });
  });

  group('Equal split (Quick Split Mode)', () {
    test('Basic equal split', () {
      final results = SplitEngine.equalSplit(
        finalTotal: 900,
        participantIds: ['a', 'b', 'c'],
        payerId: 'a',
      );

      expect(results['a']!.finalAmount, 300.0);
      expect(results['b']!.finalAmount, 300.0);
      expect(results['c']!.finalAmount, 300.0);
      expectNoDrift(results, 900);
    });

    test('Equal split with indivisible amount', () {
      final results = SplitEngine.equalSplit(
        finalTotal: 1000,
        participantIds: ['a', 'b', 'c'],
        payerId: 'a',
      );

      expect(results['b']!.finalAmount, 333.33);
      expect(results['c']!.finalAmount, 333.33);
      // Payer absorbs drift: 1000 - 666.66 = 333.34
      expect(results['a']!.finalAmount, 333.34);
      expectNoDrift(results, 1000);
    });

    test('Equal split with two people', () {
      final results = SplitEngine.equalSplit(
        finalTotal: 501.01,
        participantIds: ['x', 'y'],
        payerId: 'x',
      );

      expectNoDrift(results, 501.01);
    });
  });

  group('Edge cases', () {
    test('Single participant gets the full amount', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Solo Meal',
          price: 750,
          assignedParticipantIds: ['solo'],
        ),
      ];
      final bill = BillState(
        subtotal: 750,
        totalTax: 75,
        finalTotal: 825,
      );

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['solo'],
        payerId: 'solo',
      );

      expect(results['solo']!.finalAmount, 825.0);
      expectNoDrift(results, 825);
    });

    test('Empty participant list returns empty map', () {
      final results = SplitEngine.calculate(
        items: [],
        billState: BillState(subtotal: 100, finalTotal: 100),
        participantIds: [],
        payerId: 'nobody',
      );
      expect(results, isEmpty);
    });

    test('Empty items list falls back to equal split', () {
      final results = SplitEngine.calculate(
        items: [],
        billState: BillState(subtotal: 600, finalTotal: 600),
        participantIds: ['a', 'b'],
        payerId: 'a',
      );

      expect(results['a']!.finalAmount, 300.0);
      expect(results['b']!.finalAmount, 300.0);
      expectNoDrift(results, 600);
    });

    test('Item with zero assigned participants is skipped', () {
      final items = [
        BillItem(
          id: '1',
          name: 'Assigned',
          price: 200,
          assignedParticipantIds: ['a'],
        ),
        BillItem(
          id: '2',
          name: 'Unassigned',
          price: 100,
          assignedParticipantIds: [],
        ),
      ];
      final bill = BillState(subtotal: 300, finalTotal: 300);

      final results = SplitEngine.calculate(
        items: items,
        billState: bill,
        participantIds: ['a', 'b'],
        payerId: 'a',
      );

      // Only item 1 (200) is distributed. a gets it all.
      // Ratio: a=200/300, b=0/300
      // a: 200 => ratio 200/300 => final = 200 (from items) proportionally adjusted
      // The finalTotal is 300 but only 200 is assigned in items.
      // a ratio = 200/300 = 0.6667 => a total = 200 (no modifiers, no disc/tax/sc)
      // b ratio = 0/300 = 0 => b total = 0
      // drift = 300 - 200 = 100 => payer absorbs
      expect(results['b']!.finalAmount, 0.0);
      expectNoDrift(results, 300);
    });
  });

  group('Bill validation (Consistency Engine)', () {
    test('Valid bill passes validation', () {
      final items = [
        BillItem(id: '1', name: 'A', price: 300),
        BillItem(id: '2', name: 'B', price: 200),
      ];
      final bill = BillState(
        subtotal: 500,
        totalTax: 50,
        serviceCharge: 25,
        discount: 10,
        finalTotal: 565, // 500 - 10 + 25 + 50
      );

      final validation = SplitEngine.validateParsedBill(
        items: items,
        billState: bill,
      );

      expect(validation.isValid, isTrue);
      expect(validation.subtotalDiff, 0.0);
      expect(validation.finalDiff, 0.0);
    });

    test('Mismatched subtotal fails validation', () {
      final items = [
        BillItem(id: '1', name: 'A', price: 300),
        BillItem(id: '2', name: 'B', price: 200),
      ];
      final bill = BillState(
        subtotal: 600, // Wrong! Items sum to 500
        finalTotal: 600,
      );

      final validation = SplitEngine.validateParsedBill(
        items: items,
        billState: bill,
      );

      expect(validation.isValid, isFalse);
      expect(validation.subtotalDiff, 100.0);
    });

    test('Mismatched final total fails validation', () {
      final items = [
        BillItem(id: '1', name: 'A', price: 500),
      ];
      final bill = BillState(
        subtotal: 500,
        totalTax: 50,
        finalTotal: 600, // Wrong! Should be 550
      );

      final validation = SplitEngine.validateParsedBill(
        items: items,
        billState: bill,
      );

      expect(validation.isValid, isFalse);
      expect(validation.finalDiff, 50.0);
    });

    test('Small rounding difference within tolerance passes', () {
      final items = [
        BillItem(id: '1', name: 'A', price: 333.33),
        BillItem(id: '2', name: 'B', price: 333.33),
        BillItem(id: '3', name: 'C', price: 333.33),
      ];
      // Items sum to 999.99, bill says 1000 — within default 1.0 tolerance
      final bill = BillState(subtotal: 1000, finalTotal: 1000);

      final validation = SplitEngine.validateParsedBill(
        items: items,
        billState: bill,
      );

      expect(validation.isValid, isTrue);
    });
  });

  group('BillItem model', () {
    test('effectiveTotalPrice = price * quantity', () {
      final item = BillItem(id: '1', name: 'X', price: 99.50, quantity: 3);
      expect(item.effectiveTotalPrice, 298.50);
    });

    test('default quantity is 1', () {
      final item = BillItem(id: '1', name: 'X', price: 100);
      expect(item.quantity, 1);
      expect(item.effectiveTotalPrice, 100.0);
    });

    test('isUnassigned returns true when no participants', () {
      final item = BillItem(id: '1', name: 'X', price: 100);
      expect(item.isUnassigned, isTrue);
    });

    test('isUnassigned returns false when participants exist', () {
      final item = BillItem(
        id: '1',
        name: 'X',
        price: 100,
        assignedParticipantIds: ['a'],
      );
      expect(item.isUnassigned, isFalse);
    });
  });

  group('BillState model', () {
    test('calculatedFinalTotal computes correctly', () {
      final bill = BillState(
        subtotal: 1000,
        totalTax: 100,
        serviceCharge: 50,
        discount: 75,
        finalTotal: 1075,
      );
      expect(bill.calculatedFinalTotal, 1075.0);
    });
  });
}
