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

      testCase.verifyEqual(c.Node.currValue, 8, ...
        'Failed basic addition with mapn');
    end

    function test_mapn_partial_inputs(testCase)
      % Verify mapn doesn't compute until all inputs have values
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);

      testCase.verifyTrue(c.Node.currValue == sig.Nil.instance(), ...
        'mapn should not compute with partial inputs');

      b.post2(3);

      testCase.verifyEqual(c.Node.currValue, 8, ...
        'mapn should compute once all inputs have values');
    end

    function test_mapn_update_propagation(testCase)
      % Verify updating one input propagates correctly
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);
      b.post2(3);
      testCase.verifyEqual(c.Node.currValue, 8);

      a.post2(10);
      testCase.verifyEqual(c.Node.currValue, 13, ...
        'Failed to update when input changed');

      b.post2(7);
      testCase.verifyEqual(c.Node.currValue, 17, ...
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
      testCase.verifyEqual(y.Node.currValue, 59, ...
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

      testCase.verifyEqual(X.Node.currValue, expectedX, ...
        'meshgrid X output mismatch');
      testCase.verifyEqual(Y.Node.currValue, expectedY, ...
        'meshgrid Y output mismatch');
    end

    function test_mapn_constants_dont_trigger(testCase)
      % Verify constants don't trigger recomputation
      [a, b] = deal(testCase.A, testCase.B);
      c = a + b;

      a.post2(5);
      b.post2(3);
      testCase.verifyEqual(c.Node.currValue, 8);

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

      testCase.verifyEqual(b.Node.currValue, fliplr(arr), ...
        'map should apply function to input');
    end

    function test_map_constant(testCase)
      % Test mapping to a constant value
      a = testCase.A;
      v = 42;
      b = a.map(v);

      a.post2(1:3);

      testCase.verifyEqual(b.Node.currValue, v, ...
        'map should return constant regardless of input');
    end

    function test_map_multiple_updates(testCase)
      % Test map propagates multiple updates
      a = testCase.A;
      b = a.map(@(x) x * 2);

      a.post2(5);
      testCase.verifyEqual(b.Node.currValue, 10);

      a.post2(7);
      testCase.verifyEqual(b.Node.currValue, 14);
    end

    function test_map_no_working_value(testCase)
      % Test map returns false when input has no working value
      a = testCase.A;
      b = a.map(@(x) x + 1);

      a.post2(5);
      testCase.verifyEqual(b.Node.currValue, 6);

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
      testCase.verifyEqual(m.Node.currValue, 10);

      b.post2(20);
      testCase.verifyEqual(m.Node.currValue, 20);

      c.post2(30);
      testCase.verifyEqual(m.Node.currValue, 30);
    end

    function test_merge_multiple_updates(testCase)
      % Test merge with multiple updates to different inputs
      [a, b, c] = deal(testCase.A, testCase.B, testCase.C);
      m = merge(a, b, c);

      % Update in different order
      for s = {c, b, a, b}
        v = randi(100);
        s{1}.post2(v);
        testCase.verifyEqual(m.Node.currValue, v, ...
          'merge should output most recently updated input');
      end
    end

    function test_merge_no_working_value(testCase)
      % Test merge returns false when no inputs have working value
      [a, b] = deal(testCase.A, testCase.B);
      m = merge(a, b);

      a.post2(5);
      testCase.verifyEqual(m.Node.currValue, 5);

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
      testCase.verifyEqual(f.Node.currValue, 'hello', ...
        'filter should pass char when criterion is true');
    end

    function test_filter_blocks_nonmatching(testCase)
      % Test filter blocks values when f(value) ~= criterion
      [a, b] = deal(testCase.A, testCase.B);
      f = a.filter(@ischar, b);

      b.post2(true);  % criterion = true
      a.post2('hello');
      testCase.verifyEqual(f.Node.currValue, 'hello');

      a.post2(123);  % ischar(123) == false, doesn't match criterion
      testCase.verifyEqual(f.Node.currValue, 'hello', ...
        'filter should block non-char when criterion is true');
    end

    function test_filter_criterion_change(testCase)
      % Test filter responds to criterion changes
      [a, b] = deal(testCase.A, testCase.B);
      f = a.filter(@ischar, b);

      b.post2(true);
      a.post2('text');
      testCase.verifyEqual(f.Node.currValue, 'text');

      b.post2(false);  % now pass when ischar(value) == false
      a.post2(42);
      testCase.verifyEqual(f.Node.currValue, 42, ...
        'filter should pass number when criterion is false');
    end

    function test_filter_no_working_value(testCase)
      % Test filter returns false when "what" has no working value
      [a, b] = deal(testCase.A, testCase.B);
      f = a.filter(@ischar, b);

      b.post2(true);
      a.post2('test');
      testCase.verifyEqual(f.Node.currValue, 'test');

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
      testCase.verifyTrue(clickedPos.Node.currValue == sig.Nil.instance(), ...
        'at should not fire until when is truthy');

      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.currValue, 100, ...
        'at should sample pos when click fires');
    end

    function test_at_samples_current_value(testCase)
      % Test at grabs the current 'what' value even if 'what' didnt just update
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(50);
      pos.post2(75);  % pos is now 75
      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.currValue, 75, ...
        'at should grab current pos value');
    end

    function test_at_ignores_falsy_when(testCase)
      % Test at does nothing when 'when' is falsy
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(100);
      click.post2(false);  % falsy - should not trigger
      testCase.verifyTrue(clickedPos.Node.currValue == sig.Nil.instance(), ...
        'at should not fire when when is false');

      click.post2(0);  % also falsy
      testCase.verifyTrue(clickedPos.Node.currValue == sig.Nil.instance(), ...
        'at should not fire when when is 0');
    end

    function test_at_multiple_samples(testCase)
      % Test at can sample multiple times
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(10);
      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.currValue, 10);

      pos.post2(20);
      pos.post2(30);
      click.post2(true);
      testCase.verifyEqual(clickedPos.Node.currValue, 30, ...
        'at should sample latest pos on second click');
    end

    function test_at_no_what_value(testCase)
      % Test at does nothing if 'what' has no value at all
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      % click fires but pos was never set
      click.post2(true);
      testCase.verifyTrue(clickedPos.Node.currValue == sig.Nil.instance(), ...
        'at should not fire if what has no value');
    end

    function test_at_nonscalar_when_errors(testCase)
      % Test at throws error when 'when' is a non-scalar array
      % The 'when' trigger must be scalar - arrays don't make sense here
      [pos, click] = deal(testCase.A, testCase.B);
      clickedPos = pos.at(click);

      pos.post2(42);
      testCase.verifyError(@() click.post2([1 1 1]), ...
        'signals:at:nonScalarWhen');
    end

    %% identity Tests
    function test_identity_basic(testCase)
      % Test identity transfer function
      a = testCase.A;
      b = a.identity();

      a.post2(42);

      testCase.verifyEqual(b.Node.currValue, a.Node.currValue, ...
        'identity should pass through value unchanged');
    end

    function test_identity_multiple_updates(testCase)
      % Test identity propagates multiple updates
      a = testCase.A;
      b = a.identity();

      values = [1, 2, 3, 100, -5, 0];
      for v = values
        a.post2(v);
        testCase.verifyEqual(b.Node.currValue, v, ...
          sprintf('identity failed for value %d', v));
      end
    end

    function test_identity_with_arrays(testCase)
      % Test identity with array values
      a = testCase.A;
      b = a.identity();

      arr = magic(3);
      a.post2(arr);

      testCase.verifyEqual(b.Node.currValue, arr, ...
        'identity should handle array values');
    end

    function test_identity_no_working_value(testCase)
      % Test identity returns false when input has no working value
      a = testCase.A;
      b = a.identity();

      a.post2(5);
      testCase.verifyEqual(b.Node.currValue, 5);

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
      testCase.verifyEqual(c.Node.currValue, 8);

      % When we post to a, a.workingValue is used, b.currValue is used
      a.post2(10);
      testCase.verifyEqual(c.Node.currValue, 13, ...
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

      testCase.verifyEqual(c.Node.currValue, 8, ...
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
      testCase.verifyEqual(e.Node.currValue, 58, ...  % 6*10 - 2
        'Deep network propagation failed');

      a.post2(5);
      testCase.verifyEqual(e.Node.currValue, 28, ...  % 6*5 - 2
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
      testCase.verifyEqual(d.Node.currValue, 16, ...  % 3*5 + 1
        'Diamond dependency calculation failed');

      a.post2(10);
      testCase.verifyEqual(d.Node.currValue, 31, ...  % 3*10 + 1
        'Diamond dependency update failed');
    end
  end
end