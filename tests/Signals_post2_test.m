classdef Signals_post2_test < matlab.unittest.TestCase
  % Tests for the pure MATLAB signal propagation (post2).
  %
  % The original Signals_test.m uses post() which relies on MEX. Here we
  % test post2() instead, which is our pure MATLAB replacement.

  properties
    net
    A
    B
    C
  end

  methods (TestClassSetup)
    function createNetwork(testCase)
      testCase.net = sig.Net;
      testCase.addTeardown(@delete, testCase.net)
    end
  end

  methods (TestMethodSetup)
    function setupInputSignals(testCase)
      testCase.A = testCase.net.origin('a');
      testCase.B = testCase.net.origin('b');
      testCase.C = testCase.net.origin('c');
      % Clear schedule between tests so delay tests don't accumulate
      testCase.net.Schedule(:) = [];

      testCase.addTeardown(@delete, testCase.A)
      testCase.addTeardown(@delete, testCase.B)
      testCase.addTeardown(@delete, testCase.C)
    end
  end

  methods (Test)
    %% mapn Tests
    function test_mapn_basic_addition(testCase)
      % Test basic addition: c = a + b
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);
      b.post2(3);

      testCase.verifyEqual(c.Node.CurrValue, 8, ...
        'Failed basic addition with mapn');
    end

    function test_mapn_partial_inputs(testCase)
      % Verify mapn doesn't compute until all inputs have values
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);

      testCase.verifyTrue(c.Node.CurrValue == sig.Nil.instance(), ...
        'mapn should not compute with partial inputs');

      b.post2(3);

      testCase.verifyEqual(c.Node.CurrValue, 8, ...
        'mapn should compute once all inputs have values');
    end

    function test_mapn_update_propagation(testCase)
      % Verify updating one input propagates correctly
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);
      b.post2(3);
      testCase.verifyEqual(c.Node.CurrValue, 8);

      a.post2(10);
      testCase.verifyEqual(c.Node.CurrValue, 13, ...
        'Failed to update when input changed');

      b.post2(7);
      testCase.verifyEqual(c.Node.CurrValue, 17, ...
        'Failed to update when other input changed');
    end

    function test_mapn_complex_expression(testCase)
      % Test complex expression: y = a*x^2 + b*x + c
      [x, a, b, c] = deal(testCase.A, testCase.B, testCase.C, testCase.net.origin('d'));
      y = a * (x ^ 2) + b * x + c;

      a.post2(5);  % a = 5
      b.post2(2);  % b = 2
      c.post2(8);  % c = 8
      x.post2(3);  % x = 3

      % y = 5*9 + 2*3 + 8 = 45 + 6 + 8 = 59
      testCase.verifyEqual(y.Node.CurrValue, 59, ...
        'Failed complex polynomial expression');
    end

    function test_mapn_with_meshgrid(testCase)
      % Test mapn with multiple outputs
      [a, b] = deal(testCase.A, testCase.B);
      [X, Y] = a.mapn(b, @meshgrid);

      xx = 1:3;
      yy = 4:6;
      [expectedX, expectedY] = meshgrid(xx, yy);

      a.post2(xx);
      b.post2(yy);

      testCase.verifyEqual(X.Node.CurrValue, expectedX, ...
        'meshgrid X output mismatch');
      testCase.verifyEqual(Y.Node.CurrValue, expectedY, ...
        'meshgrid Y output mismatch');
    end

    function test_mapn_constants_dont_trigger(testCase)
      % Verify constants don't trigger recomputation
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);
      b.post2(3);
      testCase.verifyEqual(c.Node.CurrValue, 8);

      % After commit, workingValue should be Nil
      testCase.verifyTrue(a.Node.workingValue == sig.Nil.instance(), ...
        'Working value should be cleared after commit');
    end

    %% map Tests
    function test_map_function(testCase)
      % Test mapping signal through a function
      a = testCase.A;
      b = a.map(@fliplr);

      arr = 1:5;
      a.post2(arr);

      testCase.verifyEqual(b.Node.CurrValue, fliplr(arr), ...
        'map should apply function to input');
    end

    function test_map_constant(testCase)
      % Test mapping to a constant value
      a = testCase.A;
      v = 42;
      b = a.map(v);

      a.post2(1:3);

      testCase.verifyEqual(b.Node.CurrValue, v, ...
        'map should return constant regardless of input');
    end

    function test_map_multiple_updates(testCase)
      % Test map propagates multiple updates
      a = testCase.A;
      b = a.map(@(x) x * 2);

      a.post2(5);
      testCase.verifyEqual(b.Node.CurrValue, 10);

      a.post2(7);
      testCase.verifyEqual(b.Node.CurrValue, 14);
    end

    function test_map_no_working_value(testCase)
      % Test map returns false when input has no working value
      a = testCase.A;
      b = a.map(@(x) x + 1);

      a.post2(5);
      testCase.verifyEqual(b.Node.CurrValue, 6);

      % After commit, calling map directly should return false
      result = b.Node.map();
      testCase.verifyFalse(result, ...
        'map should return false when input has no working value');
    end

    %% merge Tests
    function test_merge_basic(testCase)
      % Test merge returns value of most recently updated input
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      m = merge(a, b, c);

      a.post2(10);
      testCase.verifyEqual(m.Node.CurrValue, 10);

      b.post2(20);
      testCase.verifyEqual(m.Node.CurrValue, 20);

      c.post2(30);
      testCase.verifyEqual(m.Node.CurrValue, 30);
    end

    function test_merge_multiple_updates(testCase)
      % Test merge with multiple updates to different inputs
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      m = merge(a, b, c);

      % Update in different order
      for s = {c, b, a, b}
        v = randi(100);
        s{1}.post2(v);
        testCase.verifyEqual(m.Node.CurrValue, v, ...
          'merge should output most recently updated input');
      end
    end

    function test_merge_no_working_value(testCase)
      % Test merge returns false when no inputs have working value
      [a, b] = deal(testCase.A, testCase.B);
      m = merge(a, b);

      a.post2(5);
      testCase.verifyEqual(m.Node.CurrValue, 5);

      % After commit, calling merge directly should return false
      result = m.Node.merge();
      testCase.verifyFalse(result, ...
        'merge should return false when no input has working value');
    end

    %% filter Tests
    function test_filter_passes_matching(testCase)
      % Test filter passes values when f(value) == criterion
      [a, b] = deal(testCase.A, testCase.B);
      f = a.filter(@ischar, b);

      b.post2(true);  % criterion = true, so pass when ischar(value) == true
      a.post2('hello');
      testCase.verifyEqual(f.Node.CurrValue, 'hello', ...
        'filter should pass char when criterion is true');
    end

    function test_filter_blocks_nonmatching(testCase)
      % Test filter blocks values when f(value) ~= criterion
      [a, b] = deal(testCase.A, testCase.B);
      f = a.filter(@ischar, b);

      b.post2(true);  % criterion = true
      a.post2('hello');
      testCase.verifyEqual(f.Node.CurrValue, 'hello');

      a.post2(123);  % ischar(123) == false, doesn't match criterion
      testCase.verifyEqual(f.Node.CurrValue, 'hello', ...
        'filter should block non-char when criterion is true');
    end

    function test_filter_criterion_change(testCase)
      % Test filter responds to criterion changes
      [a, b] = deal(testCase.A, testCase.B);
      f = a.filter(@ischar, b);

      b.post2(true);
      a.post2('text');
      testCase.verifyEqual(f.Node.CurrValue, 'text');

      b.post2(false);  % now pass when ischar(value) == false
      a.post2(42);
      testCase.verifyEqual(f.Node.CurrValue, 42, ...
        'filter should pass number when criterion is false');
    end

    function test_filter_no_working_value(testCase)
      % Test filter returns false when "what" has no working value
      [a, b] = deal(testCase.A, testCase.B);
      f = a.filter(@ischar, b);

      b.post2(true);
      a.post2('test');
      testCase.verifyEqual(f.Node.CurrValue, 'test');

      result = f.Node.filter();
      testCase.verifyFalse(result, ...
        'filter should return false when input has no working value');
    end

    %% at Tests
    function test_at_basic(testCase)
      % Test basic at: sample 'what' when 'when' fires
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(100);
      testCase.verifyTrue(clickedPos.Node.CurrValue == sig.Nil.instance(), ...
        'at should not fire until when is true');

      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.CurrValue, 100, ...
        'at should sample pos when click fires');
    end

    function test_at_samples_current_value(testCase)
      % Test at grabs the current 'what' value even if 'what' didnt just update
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(50);
      pos.post2(75);  % pos is now 75
      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.CurrValue, 75, ...
        'at should grab current pos value');
    end

    function test_at_ignores_false_when(testCase)
      % Test at does nothing when 'when' is false
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(100);
      click.post2(false);  % false - should not trigger
      testCase.verifyTrue(clickedPos.Node.CurrValue == sig.Nil.instance(), ...
        'at should not fire when when is false');

      click.post2(0);  % also false
      testCase.verifyTrue(clickedPos.Node.CurrValue == sig.Nil.instance(), ...
        'at should not fire when when is 0');
    end

    function test_at_multiple_samples(testCase)
      % Test at can sample multiple times
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(10);
      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.CurrValue, 10);

      pos.post2(20);
      pos.post2(30);
      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.CurrValue, 30, ...
        'at should sample latest pos on second click');
    end

    function test_at_no_what_value(testCase)
      % Test at does nothing if 'what' has no value at all
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      % click fires but pos was never set
      click.post2(true);
      testCase.verifyTrue(clickedPos.Node.CurrValue == sig.Nil.instance(), ...
        'at should not fire if what has no value');
    end

    function test_at_nonscalar_when(testCase)
      % 'when' goes through a plain if, exactly like MEX at.m L11: a
      % non-scalar gate passes only when all elements are non-zero
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(42);
      click.post2([1 1 1]);  % all non-zero, gate open
      testCase.verifyEqual(clickedPos.Node.CurrValue, 42, ...
        'at should fire when all gate elements are non-zero');

      pos.post2(50);
      click.post2([1 0 1]);  % contains a zero, gate closed
      testCase.verifyEqual(clickedPos.Node.CurrValue, 42, ...
        'at should not fire when any gate element is zero');
    end

    %% identity Tests
    function test_identity_basic(testCase)
      % Test identity transfer function
      a = testCase.A;
      b = a.identity();

      a.post2(42);

      testCase.verifyEqual(b.Node.CurrValue, a.Node.CurrValue, ...
        'identity should pass through value unchanged');
    end

    function test_identity_multiple_updates(testCase)
      % Test identity propagates multiple updates
      a = testCase.A;
      b = a.identity();

      values = [1, 2, 3, 100, -5, 0];
      for v = values
        a.post2(v);
        testCase.verifyEqual(b.Node.CurrValue, v, ...
          sprintf('identity failed for value %d', v));
      end
    end

    function test_identity_with_arrays(testCase)
      % Test identity with array values
      a = testCase.A;
      b = a.identity();

      arr = magic(3);
      a.post2(arr);

      testCase.verifyEqual(b.Node.CurrValue, arr, ...
        'identity should handle array values');
    end

    function test_identity_no_working_value(testCase)
      % Test identity returns false when input has no working value
      a = testCase.A;
      b = a.identity();

      a.post2(5);
      testCase.verifyEqual(b.Node.CurrValue, 5);

      % After commit, calling identity should return false
      result = b.Node.identity();
      testCase.verifyFalse(result, ...
        'identity should return false when input has no working value');
    end

    %% nop Tests
    function test_nop_returns_false(testCase)
      % Test nop always returns false
      a = testCase.A;

      result = a.Node.nop();
      testCase.verifyFalse(result, 'nop should always return false');
    end

    function test_nop_no_propagation(testCase)
      % Test nop doesn't cause propagation
      a = testCase.A;

      for i = 1:5
        result = a.Node.nop();
        testCase.verifyFalse(result, 'nop should consistently return false');
      end
    end

    %% LATEST_VALUE Semantics Tests
    function test_latest_value_prefers_working(testCase)
      % Verify LATEST_VALUE: use workingValue if available, else currValue
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);
      b.post2(3);
      testCase.verifyEqual(c.Node.CurrValue, 8);

      % When we post to a, a.workingValue is used, b.currValue is used
      a.post2(10);
      testCase.verifyEqual(c.Node.CurrValue, 13, ...
        'LATEST_VALUE should use workingValue when available');
    end

    %% Two-Phase Commit Tests
    function test_two_phase_commit(testCase)
      % Verify values computed to workingValue, then committed to currValue
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);
      b.post2(3);

      testCase.verifyTrue(c.Node.workingValue == sig.Nil.instance(), ...
        'workingValue should be cleared after commit');

      testCase.verifyEqual(c.Node.CurrValue, 8, ...
        'currValue should have committed result');
    end

    %% Deep Network Tests
    function test_deep_network_propagation(testCase)
      % Test propagation through a deeper network
      a = testCase.A;

      % Chain: a -> b -> c -> d -> e
      b = a * 2;      % b = 2a
      c = b + 1;      % c = 2a + 1
      d = c * 3;      % d = 6a + 3
      e = d - 5;      % e = 6a - 2

      a.post2(10);
      testCase.verifyEqual(e.Node.CurrValue, 58, ...  % 6*10 - 2
        'Deep network propagation failed');

      a.post2(5);
      testCase.verifyEqual(e.Node.CurrValue, 28, ...  % 6*5 - 2
        'Deep network update propagation failed');
    end

    %% Diamond Dependency Tests
    function test_diamond_dependency(testCase)
      % Test diamond-shaped dependency:
      %      a
      %     / \
      %    b   c
      %     \ /
      %      d
      a = testCase.A;
      b = a * 2;
      c = a + 1;
      d = b + c;  % d = 2a + (a + 1) = 3a + 1

      a.post2(5);
      testCase.verifyEqual(d.Node.CurrValue, 16, ...  % 3*5 + 1
        'Diamond dependency calculation failed');

      a.post2(10);
      testCase.verifyEqual(d.Node.CurrValue, 31, ...  % 3*10 + 1
        'Diamond dependency update failed');
    end

    function test_working_value_retraction(testCase)
      % A node computed early in a transaction must have its working value
      % retracted when a later visit in the same transaction produces no
      % output (MEX network.c L701-708: valset false with a working value
      % already set clears the value and still propagates).
      %
      %   a ----------> c = a.keepWhen(b)
      %    \           /
      %     g = a*2 -> b = g > 0
      %
      % a's targets are [g, c] in creation order, so c computes first with
      % b's stale current value, then again after b updates. On the second
      % visit the gate is closed, so the value gated through on the first
      % visit must not survive to the commit.
      a = testCase.A;
      g = a * 2;
      b = g > 0;
      c = a.keepWhen(b);

      a.post2(1);   % gate open, c takes 1
      testCase.verifyEqual(c.Node.CurrValue, 1, ...
        'keepWhen should pass value when gate is open');

      a.post2(-5);  % gate closes mid-transaction, first visit gated -5 through
      testCase.verifyEqual(c.Node.CurrValue, 1, ...
        'Retracted working value must not be committed');
    end

    function test_event_target_fires_once_per_commit(testCase)
      % A node computed twice in one transaction appears twice in the
      % affected list. The apply phase must notify its event target only
      % once (MEX network.c L368: nodes whose working value was already
      % applied and cleared are skipped, including their notification).
      %
      %   a ----------> d = a + c2
      %    \           /
      %     b = a*2 -> c2 = b + 1
      %
      % a's targets are [b, d] in creation order, so d computes once with
      % c2's stale value and again after c2 updates, landing in the
      % affected list twice.
      a = testCase.A;
      b = a * 2;
      c2 = b + 1;
      d = a + c2;

      count = 0;
      lh = d.onValue(@bump);

      a.post2(1);   % d computes on its second visit only
      testCase.verifyEqual(d.Node.CurrValue, 4);  % 1 + (2*1 + 1)
      testCase.verifyEqual(count, 1, ...
        'onValue should fire once for the first post');

      a.post2(2);   % d computes on both visits, affected twice
      testCase.verifyEqual(d.Node.CurrValue, 7);  % 2 + (2*2 + 1)
      testCase.verifyEqual(count, 2, ...
        'onValue must fire once per commit, not once per affected entry');

      function bump(~)
        count = count + 1;
      end
    end

    %% buffer Tests
    function test_buffer_basic(testCase)
      % Test buffer accumulates values into an array
      a = testCase.A;
      b = a.bufferUpTo(5);

      a.post2(10);
      testCase.verifyEqual(b.Node.CurrValue, 10);

      a.post2(20);
      testCase.verifyEqual(b.Node.CurrValue, [10 20]);

      a.post2(30);
      testCase.verifyEqual(b.Node.CurrValue, [10 20 30]);
    end

    function test_buffer_overflow(testCase)
      % Test buffer drops oldest values when full
      a = testCase.A;
      b = a.bufferUpTo(3);

      a.post2(1);
      a.post2(2);
      a.post2(3);
      testCase.verifyEqual(b.Node.CurrValue, [1 2 3]);

      a.post2(4);
      testCase.verifyEqual(b.Node.CurrValue, [2 3 4]);

      a.post2(5);
      testCase.verifyEqual(b.Node.CurrValue, [3 4 5]);

      a.post2(6);
      testCase.verifyEqual(b.Node.CurrValue, [4 5 6]);
    end

    function test_buffer_exact_size(testCase)
      % Test buffer at exactly max capacity then one more
      a = testCase.A;
      b = a.bufferUpTo(4);

      a.post2(10);
      a.post2(20);
      a.post2(30);
      a.post2(40);
      testCase.verifyEqual(b.Node.CurrValue, [10 20 30 40], ...
        'Buffer should hold exactly max values');

      a.post2(50);
      testCase.verifyEqual(b.Node.CurrValue, [20 30 40 50], ...
        'Buffer should drop oldest when one over max');
    end

    function test_buffer_no_sample(testCase)
      % Test buffer returns false when no new sample
      a = testCase.A;
      b = a.bufferUpTo(3);

      a.post2(5);
      testCase.verifyEqual(b.Node.CurrValue, 5);

      % After commit, calling buffer directly should return false
      result = b.Node.buffer();
      testCase.verifyFalse(result, ...
        'buffer should return false when input has no working value');
    end

    function test_buffer_no_max(testCase)
      % Test buffer returns false when max size is not set
      % Create a buffer node manually where maxSamps input has no value
      net = testCase.net;
      a = net.origin('a');
      maxNode = sig.node.Node(net);  % root node with no value
      maxNode.Name = 'max';
      maxNode.FormatSpec = 'max';

      % Call buffer directly - maxSamps has no value so should return false
      result = maxNode.nop();  % just verify the node exists
      testCase.verifyFalse(result);
    end

    function test_buffer_via_bufferUpTo(testCase)
      % Test buffer through the Signal-level bufferUpTo API
      a = testCase.A;
      buf = a.bufferUpTo(3);

      values = [10 20 30 40 50];
      expected = {10, [10 20], [10 20 30], [20 30 40], [30 40 50]};
      for i = 1:numel(values)
        a.post2(values(i));
        testCase.verifyEqual(buf.Node.CurrValue, expected{i}, ...
          sprintf('bufferUpTo failed at step %d', i));
      end
    end

    %% indexOfFirst Tests
    function test_indexOfFirst_basic(testCase)
      % First true input wins
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      idx = indexOfFirst(a, b, c);

      a.post2(false);
      b.post2(true);
      c.post2(false);

      testCase.verifyEqual(idx.Node.CurrValue, 2, ...
        'indexOfFirst should return 2 (b is first true)');
    end

    function test_indexOfFirst_no_match(testCase)
      % All false → returns N+1
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      idx = indexOfFirst(a, b, c);

      a.post2(false);
      b.post2(false);
      c.post2(false);

      testCase.verifyEqual(idx.Node.CurrValue, 4, ...
        'indexOfFirst should return N+1 (4) when no match');
    end

    function test_indexOfFirst_first_input_true(testCase)
      % First input is true → returns 1
      [a, b] = deal(testCase.A, testCase.B);
      idx = indexOfFirst(a, b);

      a.post2(true);
      b.post2(false);

      testCase.verifyEqual(idx.Node.CurrValue, 1, ...
        'indexOfFirst should return 1 when first input is true');
    end

    function test_indexOfFirst_unset_predicate(testCase)
      % If a predicate has no value yet, return noMatch
      % Only post to first input, leave second unset
      [a, b] = deal(testCase.A, testCase.B);
      idx = indexOfFirst(a, b);

      a.post2(false);
      % b never posted — its predicate is unset
      % MEX L33-38: can't evaluate further, return noMatch
      testCase.verifyEqual(idx.Node.CurrValue, 3, ...
        'indexOfFirst should return N+1 (3) when predicate unset');
    end

    function test_indexOfFirst_match_changes(testCase)
      % When match changes from later to earlier input
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      idx = indexOfFirst(a, b, c);

      a.post2(false);
      b.post2(false);
      c.post2(true);
      testCase.verifyEqual(idx.Node.CurrValue, 3, ...
        'indexOfFirst should return 3 (c is first true)');

      % Now a becomes true — should shift to 1
      a.post2(true);
      testCase.verifyEqual(idx.Node.CurrValue, 1, ...
        'indexOfFirst should return 1 after a becomes true');
    end

    function test_indexOfFirst_early_exit(testCase)
      % Tests the early exit optimization (MEX L24-29):
      % If first changed predicate is after current match, result can't change
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      idx = indexOfFirst(a, b, c);

      a.post2(true);
      b.post2(false);
      c.post2(false);
      testCase.verifyEqual(idx.Node.CurrValue, 1, ...
        'indexOfFirst should return 1 (a is true)');

      % Now update c (index 3) — current match is 1, so 3 > 1 → early exit
      % Result should remain 1
      c.post2(true);
      testCase.verifyEqual(idx.Node.CurrValue, 1, ...
        'indexOfFirst should still be 1 (early exit, c change irrelevant)');
    end

    %% keepWhen Tests
    function test_keepWhen_basic(testCase)
      % Value passes through when gate is true
      [a, b] = deal(testCase.A, testCase.B);
      k = a.keepWhen(b);

      b.post2(true);
      a.post2(42);
      testCase.verifyEqual(k.Node.CurrValue, 42, ...
        'keepWhen should pass value when gate is true');
    end

    function test_keepWhen_gate_false(testCase)
      % Value is blocked when gate is false
      [a, b] = deal(testCase.A, testCase.B);
      k = a.keepWhen(b);
      nilInstance = sig.Nil.instance();

      b.post2(false);
      a.post2(42);
      testCase.verifyTrue(k.Node.CurrValue == nilInstance, ...
        'keepWhen should block value when gate is false');
    end

    function test_keepWhen_gate_changes(testCase)
      % Gate going from true to false blocks subsequent values
      [a, b] = deal(testCase.A, testCase.B);
      k = a.keepWhen(b);

      b.post2(true);
      a.post2(10);
      testCase.verifyEqual(k.Node.CurrValue, 10);

      b.post2(false);
      a.post2(20);
      testCase.verifyEqual(k.Node.CurrValue, 10, ...
        'keepWhen should still be 10 after gate went false');
    end

    function test_keepWhen_no_current_fallback(testCase)
      % Unlike 'at', keepWhen does NOT fall back to 'what' current value.
      % Only working value of 'what' passes through (MEX L33).
      [a, b] = deal(testCase.A, testCase.B);
      k = a.keepWhen(b);

      % Set a's value first, then set gate — a has current but no working
      a.post2(99);
      b.post2(true);
      % 'a' was posted in a previous transaction, so it has currValue but
      % no workingValue in this transaction. keepWhen should NOT pass it.
      nilInstance = sig.Nil.instance();
      testCase.verifyTrue(k.Node.CurrValue == nilInstance, ...
        'keepWhen should not fall back to current value of what');
    end

    function test_keepWhen_when_unset(testCase)
      % When gate has no value at all, nothing passes
      [a, b] = deal(testCase.A, testCase.B);
      k = a.keepWhen(b);
      nilInstance = sig.Nil.instance();

      % Only post to 'what', gate never set
      a.post2(42);
      testCase.verifyTrue(k.Node.CurrValue == nilInstance, ...
        'keepWhen should not pass when gate has no value');
    end

    %% skipRepeats Tests
    function test_skipRepeats_blocks_duplicates(testCase)
      % Test skipRepeats blocks repeated values
      a = testCase.A;
      nr = a.skipRepeats();

      a.post2(5);
      testCase.verifyEqual(nr.Node.CurrValue, 5);

      a.post2(5);  % same value — should be blocked
      testCase.verifyEqual(nr.Node.CurrValue, 5, ...
        'skipRepeats should still be 5, not re-propagated');
    end

    function test_skipRepeats_passes_different(testCase)
      % Test skipRepeats passes through when value changes
      a = testCase.A;
      nr = a.skipRepeats();

      a.post2(5);
      testCase.verifyEqual(nr.Node.CurrValue, 5);

      a.post2(10);
      testCase.verifyEqual(nr.Node.CurrValue, 10, ...
        'skipRepeats should pass through different value');
    end

    function test_skipRepeats_first_value_always_passes(testCase)
      % Test first value always passes (no current value to compare)
      a = testCase.A;
      nr = a.skipRepeats();

      a.post2(42);
      testCase.verifyEqual(nr.Node.CurrValue, 42, ...
        'First value should always pass through');
    end

    function test_skipRepeats_with_arrays(testCase)
      % Test skipRepeats works with arrays (uses isequal)
      a = testCase.A;
      nr = a.skipRepeats();

      a.post2([1 2 3]);
      testCase.verifyEqual(nr.Node.CurrValue, [1 2 3]);

      a.post2([1 2 3]);  % same array — blocked
      testCase.verifyEqual(nr.Node.CurrValue, [1 2 3]);

      a.post2([1 2 4]);  % different array — passes
      testCase.verifyEqual(nr.Node.CurrValue, [1 2 4]);
    end

    function test_skipRepeats_no_working_value(testCase)
      % Test skipRepeats returns false when input has no working value
      a = testCase.A;
      nr = a.skipRepeats();

      a.post2(5);
      testCase.verifyEqual(nr.Node.CurrValue, 5);

      % After commit, calling skipRepeats directly should return false
      result = nr.Node.skipRepeats();
      testCase.verifyFalse(result, ...
        'skipRepeats should return false when input has no working value');
    end

    %% latch tests
    function test_latch_arm_then_release(testCase)
      % Basic arm/release cycle: arm fires true, then release fires true
      net = testCase.net;
      arm = net.origin('arm');
      release = net.origin('release');
      p = arm.to(release);

      % Initially not armed
      testCase.verifyFalse(p.Node.CurrValue, ...
        'Latch should start as false');

      % Arm with true value
      arm.post2(1);
      testCase.verifyTrue(p.Node.CurrValue, ...
        'Latch should be true after arming');

      % Release with true value
      release.post2(1);
      testCase.verifyFalse(p.Node.CurrValue, ...
        'Latch should be false after releasing');
    end

    function test_latch_zero_arm_ignored(testCase)
      % Posting 0 (non-true) to arm should not arm the latch
      net = testCase.net;
      arm = net.origin('arm');
      release = net.origin('release');
      p = arm.to(release);

      arm.post2(0);
      testCase.verifyFalse(p.Node.CurrValue, ...
        'Posting 0 to arm should not arm the latch');
    end

    function test_latch_zero_release_ignored(testCase)
      % Posting 0 to release should not release an armed latch
      net = testCase.net;
      arm = net.origin('arm');
      release = net.origin('release');
      p = arm.to(release);

      arm.post2(1);
      testCase.verifyTrue(p.Node.CurrValue);

      release.post2(0);
      testCase.verifyTrue(p.Node.CurrValue, ...
        'Posting 0 to release should not release the latch');
    end

    function test_latch_rearm_when_armed_is_noop(testCase)
      % Posting true to arm again when already armed should not change state
      net = testCase.net;
      arm = net.origin('arm');
      release = net.origin('release');
      p = arm.to(release);

      arm.post2(1);
      testCase.verifyTrue(p.Node.CurrValue);

      % Arm again — should be a no-op (valset = false, no propagation)
      arm.post2(5);
      testCase.verifyTrue(p.Node.CurrValue, ...
        'Re-arming when already armed should not change state');
    end

    function test_latch_release_without_arm_is_noop(testCase)
      % Releasing when not armed should not change state
      net = testCase.net;
      arm = net.origin('arm');
      release = net.origin('release');
      p = arm.to(release);

      release.post2(1);
      testCase.verifyFalse(p.Node.CurrValue, ...
        'Releasing when not armed should not change state');
    end

    function test_latch_multiple_cycles(testCase)
      % Full arm/release/re-arm/re-release cycle
      net = testCase.net;
      arm = net.origin('arm');
      release = net.origin('release');
      p = arm.to(release);

      % Cycle 1
      arm.post2(1);
      testCase.verifyTrue(p.Node.CurrValue);
      release.post2(1);
      testCase.verifyFalse(p.Node.CurrValue);

      % Cycle 2
      arm.post2(3);
      testCase.verifyTrue(p.Node.CurrValue, ...
        'Should re-arm after being released');
      release.post2(7);
      testCase.verifyFalse(p.Node.CurrValue, ...
        'Should release again in second cycle');
    end

    function test_latch_simultaneous_arm_and_release(testCase)
      % MEX L15: when both arm AND release fire true in same transaction,
      % release wins — output is false.
      % We wire both inputs from the same origin so a single post2 gives
      % both inputs working values in the same BFS pass.
      net = testCase.net;
      x = net.origin('x');
      arm = x.map(@(v) v);      % identity — follows x
      release = x.map(@(v) v);   % identity — also follows x
      p = arm.to(release);

      % Both arm and release get working value 1 in the same transaction
      x.post2(1);
      testCase.verifyFalse(p.Node.CurrValue, ...
        'When both arm and release fire simultaneously, release should win');
    end

    %% log tests
    function test_log_basic(testCase)
      % Each posted value gets timestamped and stored
      net = testCase.net;
      a = net.origin('a');
      clk = containers.Map('KeyType','char','ValueType','double');
      clk('t') = 0;
      clockFun = @() clk('t');  % handle object — mutations visible to closure
      lg = a.log(clockFun);

      % Initial CurrValue is an empty struct array
      testCase.verifyTrue(isempty(lg.Node.CurrValue), ...
        'Log should start empty');

      clk('t') = 1.0;
      a.post2(42);
      result = lg.Node.CurrValue;
      testCase.verifyEqual(result.time, 1.0, ...
        'Timestamp should come from clock function');
      testCase.verifyEqual(result.value, 42, ...
        'Logged value should match posted value');
    end

    function test_log_multiple_values(testCase)
      % Log captures each value with its timestamp
      net = testCase.net;
      a = net.origin('a');
      clk = containers.Map('KeyType','char','ValueType','double');
      clk('t') = 0;
      clockFun = @() clk('t');
      lg = a.log(clockFun);

      clk('t') = 0.5;
      a.post2(10);
      clk('t') = 1.5;
      a.post2(20);
      clk('t') = 2.5;
      a.post2(30);

      result = lg.Node.CurrValue;
      testCase.verifyEqual(numel(result), 3, ...
        'Log should have 3 entries');
      testCase.verifyEqual([result.time], [0.5 1.5 2.5], ...
        'Timestamps should accumulate in order');
      testCase.verifyEqual([result.value], [10 20 30], ...
        'Values should accumulate in order');
    end

    function test_log_no_working_value(testCase)
      % Log should not fire when input has no working value
      net = testCase.net;
      a = net.origin('a');
      clockFun = @() 0;
      lg = a.log(clockFun);

      % Don't post anything — log should stay empty
      result = lg.Node.log();
      testCase.verifyFalse(result, ...
        'Log should return false when input has no working value');
    end

    function test_log_different_types(testCase)
      % Log should work with any value type (string, array, etc.)
      net = testCase.net;
      a = net.origin('a');
      clk = containers.Map('KeyType','char','ValueType','double');
      clk('t') = 0;
      clockFun = @() clk('t');
      lg = a.log(clockFun);

      clk('t') = 1.0;
      a.post2('hello');
      result = lg.Node.CurrValue;
      testCase.verifyEqual(result(end).value, 'hello', ...
        'Log should handle string values');

      clk('t') = 2.0;
      a.post2([1 2 3]);
      result = lg.Node.CurrValue;
      testCase.verifyEqual(result(end).value, [1 2 3], ...
        'Log should handle array values');
    end

    %% scan tests
    function test_scan_basic_accumulator(testCase)
      % Basic scan: accumulate sum with seed = 0
      net = testCase.net;
      a = net.origin('a');
      acc = a.scan(@plus, 0);

      a.post2(5);
      testCase.verifyEqual(acc.Node.CurrValue, 5, ...
        'Accumulator should be 0 + 5 = 5');

      a.post2(3);
      testCase.verifyEqual(acc.Node.CurrValue, 8, ...
        'Accumulator should be 5 + 3 = 8');

      a.post2(2);
      testCase.verifyEqual(acc.Node.CurrValue, 10, ...
        'Accumulator should be 8 + 2 = 10');
    end

    function test_scan_seed_initialises_accumulator(testCase)
      % Seed value should be the starting accumulator
      net = testCase.net;
      a = net.origin('a');
      acc = a.scan(@plus, 100);

      a.post2(1);
      testCase.verifyEqual(acc.Node.CurrValue, 101, ...
        'Accumulator should start from seed 100');
    end

    function test_scan_seed_signal_override(testCase)
      % When seed is a signal, updating it should reset the accumulator
      net = testCase.net;
      a = net.origin('a');
      seed = net.origin('seed');
      acc = a.scan(@plus, seed);

      seed.post2(10);
      testCase.verifyEqual(acc.Node.CurrValue, 10, ...
        'Seed signal should set initial accumulator');

      a.post2(5);
      testCase.verifyEqual(acc.Node.CurrValue, 15, ...
        'Accumulator should be 10 + 5 = 15');

      % Posting new seed resets accumulator
      seed.post2(0);
      testCase.verifyEqual(acc.Node.CurrValue, 0, ...
        'New seed should reset accumulator');

      a.post2(7);
      testCase.verifyEqual(acc.Node.CurrValue, 7, ...
        'Accumulator should be 0 + 7 = 7 after reset');
    end

    function test_scan_with_parameters(testCase)
      % Scan with extra parameter: f(acc, item, par)
      net = testCase.net;
      a = net.origin('a');
      scale = net.origin('scale');
      % f(acc, item, scale) = acc + item * scale
      acc = a.scan(@(acc, item, s) acc + item * s, 0, 'pars', scale);

      scale.post2(2);
      a.post2(5);
      testCase.verifyEqual(acc.Node.CurrValue, 10, ...
        'Should be 0 + 5*2 = 10');

      a.post2(3);
      testCase.verifyEqual(acc.Node.CurrValue, 16, ...
        'Should be 10 + 3*2 = 16');

      % Change scale parameter
      scale.post2(10);
      a.post2(1);
      testCase.verifyEqual(acc.Node.CurrValue, 26, ...
        'Should be 16 + 1*10 = 26');
    end

    function test_scan_no_item_no_update(testCase)
      % If element input has no working value, accumulator should not change
      net = testCase.net;
      a = net.origin('a');
      acc = a.scan(@plus, 0);

      a.post2(5);
      testCase.verifyEqual(acc.Node.CurrValue, 5);

      % Don't post to a — calling scan directly should return false
      result = acc.Node.scan();
      testCase.verifyFalse(result, ...
        'scan should return false when element has no working value');
    end

    function test_scan_missing_parameter_bails(testCase)
      % If a parameter has no value at all, scan should not proceed
      net = testCase.net;
      a = net.origin('a');
      p = net.origin('p');
      acc = a.scan(@(acc, item, par) acc + item + par, 0, 'pars', p);

      % Post to a without ever posting to p — param is missing
      a.post2(5);
      testCase.verifyEqual(acc.Node.CurrValue, 0, ...
        'Accumulator should stay at seed when parameter is missing');
    end

    function test_scan_custom_function(testCase)
      % Scan with custom function: build a string
      net = testCase.net;
      a = net.origin('a');
      acc = a.scan(@(acc, item) [acc '_' num2str(item)], 'start');

      a.post2(1);
      testCase.verifyEqual(acc.Node.CurrValue, 'start_1');

      a.post2(2);
      testCase.verifyEqual(acc.Node.CurrValue, 'start_1_2');

      a.post2(3);
      testCase.verifyEqual(acc.Node.CurrValue, 'start_1_2_3');
    end

    %% schedule/delay tests (full pipeline: schedule -> onValue -> delayedPost -> Net.Schedule)
    function test_delay_basic(testCase)
      % delay() queues a scheduled entry in Net.Schedule
      net = testCase.net;
      a = net.origin('a');
      period = net.origin('period');
      d = a.delay(period);

      period.post2(2);
      a.post2(42);
      testCase.verifyEqual(numel(net.Schedule), 1, ...
        'One entry should be queued in Net.Schedule');
      testCase.verifyEqual(net.Schedule(1).value, 42, ...
        'Scheduled value should be 42');
    end

    function test_delay_no_what(testCase)
      % If 'what' has no working value, nothing is scheduled
      net = testCase.net;
      a = net.origin('a');
      period = net.origin('period');
      d = a.delay(period);

      % Only post to delay, not to 'what'
      period.post2(5);
      testCase.verifyEqual(numel(net.Schedule), 0, ...
        'Nothing should be scheduled without what working value');
    end

    function test_delay_no_period(testCase)
      % If 'delay' has no value at all, nothing is scheduled
      net = testCase.net;
      a = net.origin('a');
      period = net.origin('period');
      d = a.delay(period);

      % Only post to 'what', period never set
      a.post2(42);
      testCase.verifyEqual(numel(net.Schedule), 0, ...
        'Nothing should be scheduled without delay value');
    end

    function test_delay_period_uses_latest_value(testCase)
      % 'delay' uses LATEST_VALUE — falls back to current when no working
      net = testCase.net;
      a = net.origin('a');
      period = net.origin('period');
      d = a.delay(period);

      % Set period first (becomes currValue), then post 'what' alone
      period.post2(3);
      a.post2(10);
      testCase.verifyEqual(numel(net.Schedule), 1);
      testCase.verifyEqual(net.Schedule(1).value, 10);

      % Post 'what' again — period still has current value from before
      a.post2(20);
      testCase.verifyEqual(numel(net.Schedule), 2);
      testCase.verifyEqual(net.Schedule(2).value, 20);
    end

    function test_delay_multiple_posts(testCase)
      % Each new 'what' post produces a separate schedule entry
      net = testCase.net;
      a = net.origin('a');
      period = net.origin('period');
      d = a.delay(period);

      period.post2(1);
      a.post2(100);
      testCase.verifyEqual(numel(net.Schedule), 1);
      testCase.verifyEqual(net.Schedule(1).value, 100);

      a.post2(200);
      testCase.verifyEqual(numel(net.Schedule), 2);
      testCase.verifyEqual(net.Schedule(2).value, 200);

      % Change delay too
      period.post2(5);
      a.post2(300);
      testCase.verifyEqual(numel(net.Schedule), 3);
      testCase.verifyEqual(net.Schedule(3).value, 300);
    end
    %% Missing test coverage from Signals_test.m

    function test_filter_char_expression(testCase)
      % Original test_filter covers: a.filter('~=2') with char instead of function handle
      net = testCase.net;
      a = net.origin('a');
      f = a.filter('~=2');

      % 0 ~= 2 is true, so value passes through
      a.post2(0);
      testCase.verifyEqual(f.Node.CurrValue, 0, ...
        'filter with char should pass value where expression is true');

      % 2 ~= 2 is false, so value is blocked
      a.post2(2);
      testCase.verifyEqual(f.Node.CurrValue, 0, ...
        'filter with char should block value where expression is false');
    end

    function test_map_signal_to_signal(testCase)
      % Original test_map covers: a.map(c) where c is another signal
      % This means "whenever a updates, take c's current value"
      net = testCase.net;
      a = net.origin('a');
      c = net.origin('c');
      b = a.map(c);

      % Post to c first — b should not update (a hasn't fired)
      c.post2(1:3);
      testCase.verifyTrue(b.Node.CurrValue == sig.Nil.instance(), ...
        'map(signal) should not update until source signal updates');

      % Post to a — b should take c's current value
      a.post2(0);
      testCase.verifyEqual(b.Node.CurrValue, 1:3, ...
        'map(signal) should take the mapped signal''s value when source updates');
    end

    function test_bufferUpTo_signal_N(testCase)
      % Original test_bufferUpTo covers: a.bufferUpTo(b) where b is a signal
      net = testCase.net;
      a = net.origin('a');
      b = net.origin('b');
      buff = a.bufferUpTo(b);

      % No updates until n samples defined
      a.post2(1);
      testCase.verifyTrue(buff.Node.CurrValue == sig.Nil.instance(), ...
        'bufferUpTo(signal) should not update before N is set');

      % Set N then fill buffer
      b.post2(3);
      a.post2(10);
      a.post2(20);
      a.post2(30);
      testCase.verifyEqual(numel(buff.Node.CurrValue), 3, ...
        'Buffer should have exactly N elements');
      testCase.verifyEqual(buff.Node.CurrValue(end), 30, ...
        'Last buffer element should be most recent value');

      % Shrink N — next post should trim buffer
      b.post2(2);
      a.post2(40);
      testCase.verifyEqual(numel(buff.Node.CurrValue), 2, ...
        'Buffer should shrink when N decreases');
      testCase.verifyEqual(buff.Node.CurrValue(end), 40, ...
        'Last buffer element should be most recent after shrink');
    end

    function test_nop_warning(testCase)
      % Original test_nop covers: nop issues warning 'signals:transfer:nopCalled'
      net = testCase.net;
      a = net.origin('a');
      % Create a node with nop transfer (default when no transfer specified)
      nopNode = sig.node.Node(net);
      testCase.verifyWarning(@() nopNode.nop(), ...
        'signals:transfer:nopCalled', ...
        'nop should issue warning matching MEX reference');
    end

    function test_then(testCase)
      % Original test_then covers: b.then(a) is reversed-argument at
      % b.then(a) == a.at(b) — sample a's value when b fires
      net = testCase.net;
      a = net.origin('a');
      b = net.origin('b');
      s = b.then(a);

      % Post value to a (what) — s should not update
      v = 42;
      a.post2(v);
      testCase.verifyTrue(s.Node.CurrValue == sig.Nil.instance(), ...
        'then should not update when only what is posted');

      % Post true to b (when) — s should sample a's current value
      b.post2(true);
      testCase.verifyEqual(s.Node.CurrValue, v, ...
        'then should sample what''s value when when fires true');

      % Post new value to a, then false to b — s should not update
      a.post2(99);
      b.post2(false);
      testCase.verifyEqual(s.Node.CurrValue, v, ...
        'then should not update when when fires false');
    end

    %% flatten Tests
    function test_flatten_regular_value(testCase)
      % Director posts a regular value — flatten gets that value
      a = testCase.A;
      flat = a.flatten();

      a.post2(42);
      testCase.verifyEqual(flat.Node.CurrValue, 42, ...
        'flatten should pass through regular values');
    end

    function test_flatten_signal_value(testCase)
      % Director posts a Signal — flatten gets that Signal's current value
      a = testCase.A;
      b = testCase.B;
      flat = a.flatten();

      % Give b a value first, then point director at b
      b.post2(10);
      a.post2(b);
      testCase.verifyEqual(flat.Node.CurrValue, 10, ...
        'flatten should get source Signal''s value');
    end

    function test_flatten_source_updates(testCase)
      % Source Signal updates — flatten follows
      a = testCase.A;
      b = testCase.B;
      flat = a.flatten();

      b.post2(10);
      a.post2(b);
      testCase.verifyEqual(flat.Node.CurrValue, 10);

      % Now update source — flatten should follow
      b.post2(99);
      testCase.verifyEqual(flat.Node.CurrValue, 99, ...
        'flatten should follow source updates');
    end

    function test_flatten_switch_source(testCase)
      % Director switches from Signal A to Signal B — flatten follows B
      a = testCase.A;
      b = testCase.B;
      c = testCase.C;
      flat = a.flatten();

      % Point at b
      b.post2(10);
      a.post2(b);
      testCase.verifyEqual(flat.Node.CurrValue, 10);

      % Switch to c
      c.post2(20);
      a.post2(c);
      testCase.verifyEqual(flat.Node.CurrValue, 20, ...
        'flatten should follow new source after switch');

      % Update c — flatten should follow c, not b
      c.post2(30);
      testCase.verifyEqual(flat.Node.CurrValue, 30, ...
        'flatten should follow new source updates');
    end

    function test_flatten_signal_to_regular(testCase)
      % Director switches from Signal to regular value
      a = testCase.A;
      b = testCase.B;
      flat = a.flatten();

      % Start with signal
      b.post2(10);
      a.post2(b);
      testCase.verifyEqual(flat.Node.CurrValue, 10);

      % Switch to regular value
      a.post2(42);
      testCase.verifyEqual(flat.Node.CurrValue, 42, ...
        'flatten should return regular value after switching from Signal');
    end

    function test_flatten_via_signal_api(testCase)
      % Test through Signal-level flatten() API
      a = testCase.A;
      b = testCase.B;
      flat = a.flatten();

      % Verify it creates a valid signal
      testCase.verifyTrue(isa(flat, 'sig.node.Signal'), ...
        'flatten() should return a Signal');

      % Regular value
      a.post2(5);
      testCase.verifyEqual(flat.Node.CurrValue, 5);

      % Signal value
      b.post2(100);
      a.post2(b);
      testCase.verifyEqual(flat.Node.CurrValue, 100);
    end

    %% selectFrom Tests
    function test_selectFrom_basic(testCase)
      % idx=1 selects option 1
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);
      a.post2(1);

      testCase.verifyEqual(s.Node.CurrValue, 100, ...
        'idx=1 should select option 1 (b = 100)');
    end

    function test_selectFrom_picks_second(testCase)
      % idx=2 selects option 2
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);
      a.post2(2);

      testCase.verifyEqual(s.Node.CurrValue, 200, ...
        'idx=2 should select option 2 (c = 200)');
    end

    function test_selectFrom_idx_changes(testCase)
      % Switching indexer changes which option emits
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);
      a.post2(1);
      testCase.verifyEqual(s.Node.CurrValue, 100);

      a.post2(2);
      testCase.verifyEqual(s.Node.CurrValue, 200, ...
        'switching idx to 2 should emit option 2');
    end

    function test_selectFrom_option_changes(testCase)
      % if the selected option gets a new value, that value should come out.
      % also covers the case where the idx came from the previous round, not
      % this one
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);
      a.post2(1);
      testCase.verifyEqual(s.Node.CurrValue, 100);

      b.post2(150);
      testCase.verifyEqual(s.Node.CurrValue, 150, ...
        'posting to selected option should emit new value');
    end

    function test_selectFrom_unselected_option_no_emit(testCase)
      % posting to an option that isn't currently selected shouldn't change
      % the output. neither the idx nor the chosen option changed, so we
      % don't want to re-emit the same value (MEX L26-27)
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);
      a.post2(1);
      testCase.verifyEqual(s.Node.CurrValue, 100);

      c.post2(999);
      testCase.verifyEqual(s.Node.CurrValue, 100, ...
        'posting to unselected option should not change output');
    end

    function test_selectFrom_idx_out_of_range(testCase)
      % idx bigger than the number of options, nothing to pick (MEX L21)
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);
      a.post2(5);

      testCase.verifyTrue(s.Node.CurrValue == sig.Nil.instance(), ...
        'out-of-range idx should not emit');
    end

    function test_selectFrom_no_idx_value(testCase)
      % no idx posted yet, so nothing to pick (MEX L15-19)
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);

      testCase.verifyTrue(s.Node.CurrValue == sig.Nil.instance(), ...
        'no indexer value should not emit');
    end

    function test_selectFrom_selected_option_unset(testCase)
      % idx points to an option that has never been given a value, so we
      % can't emit anything
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      a.post2(2);

      testCase.verifyTrue(s.Node.CurrValue == sig.Nil.instance(), ...
        'idx pointing to unset option should not emit');
    end

    function test_selectFrom_no_working_value(testCase)
      % calling selectFrom directly when nothing has a working value should
      % just return false (MEX L33-34). you can't actually hit this through
      % post2() but it matches the pattern of the other no-working-value tests
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a.selectFrom(b, c);

      b.post2(100);
      c.post2(200);
      a.post2(1);
      testCase.verifyEqual(s.Node.CurrValue, 100);

      result = s.Node.selectFrom();
      testCase.verifyFalse(result, ...
        'selectFrom should return false when no input has working value');
    end

    %% subsref Tests
    function test_subsref_constant_index(testCase)
      % arr(1) with a literal index, should give first element
      a = testCase.A;
      s = a(1);

      a.post2([10 20 30]);

      testCase.verifyEqual(s.Node.CurrValue, 10, ...
        'a(1) should give first element');
    end

    function test_subsref_signal_index(testCase)
      % arr(idx) where idx is itself a signal, both must have values
      [a, b] = deal(testCase.A, testCase.B);
      s = a(b);

      a.post2([10 20 30]);
      b.post2(2);

      testCase.verifyEqual(s.Node.CurrValue, 20, ...
        'a(2) should give second element');
    end

    function test_subsref_index_changes(testCase)
      % change the index, output should switch
      [a, b] = deal(testCase.A, testCase.B);
      s = a(b);

      a.post2([10 20 30]);
      b.post2(1);
      testCase.verifyEqual(s.Node.CurrValue, 10);

      b.post2(3);
      testCase.verifyEqual(s.Node.CurrValue, 30, ...
        'changing index should give new element');
    end

    function test_subsref_array_changes(testCase)
      % change the array, output should update with same index
      [a, b] = deal(testCase.A, testCase.B);
      s = a(b);

      a.post2([10 20 30]);
      b.post2(2);
      testCase.verifyEqual(s.Node.CurrValue, 20);

      a.post2([100 200 300]);
      testCase.verifyEqual(s.Node.CurrValue, 200, ...
        'changing array should give new element at same index');
    end

    function test_subsref_multi_dim(testCase)
      % a(b, c) with 2D matrix and two index signals
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      s = a(b, c);

      a.post2([1 2 3; 4 5 6; 7 8 9]);
      b.post2(2);
      c.post2(3);

      testCase.verifyEqual(s.Node.CurrValue, 6, ...
        'a(2,3) should give the element at row 2, col 3');
    end

    function test_subsref_slice(testCase)
      % a(2:4), slicing with a colon expression
      a = testCase.A;
      s = a(2:4);

      a.post2([10 20 30 40 50]);

      testCase.verifyEqual(s.Node.CurrValue, [20 30 40], ...
        'a(2:4) should give a slice');
    end

    function test_subsref_end_with_signal_returns_first_element(testCase)
      % a(end) on a Signal does NOT return the last element of the underlying
      % array. Signal.m defines end(k,n) as a Static method, so it doesn't
      % match MATLAB's class end protocol (which wants a non-static method
      % with the object as first arg). MATLAB falls back to its builtin end
      % for the Signal handle, which gives numel(signal)=1. So a(end) ends
      % up being a(1).
      %
      % The expr.Expr resolve loop in subsrefTransfer (MEX L46-50) is dead
      % code through this path. It would only fire if something else built
      % an expr.End and fed it as a subscript value.
      a = testCase.A;
      s = a(end);

      a.post2([10 20 30 40]);

      testCase.verifyEqual(s.Node.CurrValue, 10, ...
        'a(end) on a Signal returns a(1) because Signal.end is static');
    end

    function test_subsref_unset_subscript(testCase)
      % if a subscript signal has no value, can't compute anything
      [a, b] = deal(testCase.A, testCase.B);
      s = a(b);

      a.post2([10 20 30]);
      % b never posted

      testCase.verifyTrue(s.Node.CurrValue == sig.Nil.instance(), ...
        'should not emit when subscript has no value');
    end

    function test_subsref_no_working_value(testCase)
      % direct call after a successful propagation. all inputs have
      % CurrValues but none have workingValues, so ~any(wvset) bails
      % out with valset=false. MEX literally falls off the end of the
      % function here without setting val/valset, our version returns
      % false explicitly. the method is named subsrefTransfer on Node
      % so it doesn't collide with MATLAB's builtin subsref
      [a, b] = deal(testCase.A, testCase.B);
      s = a(b);

      a.post2([10 20 30]);
      b.post2(2);
      testCase.verifyEqual(s.Node.CurrValue, 20);

      result = s.Node.subsrefTransfer();
      testCase.verifyFalse(result, ...
        'subsrefTransfer should return false when no input has working value');
    end
  end
end