# frozen_string_literal: true

require "test_helper"

class TestTraceologist < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Traceologist::VERSION
  end

  # ------- fixture classes -------

  class Calculator
    def add(a, b)
      a + b
    end

    def multiply(x, y)
      x * y
    end
  end

  class Tree
    def outer
      inner
    end

    def inner
      42
    end
  end

  class Greeter
    def greet(name, loud: false)
      loud ? name.upcase : name
    end
  end

  # ------- tests -------

  def test_basic_call_and_return_are_captured
    calc = Calculator.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(1, 2)
    end

    assert_equal(1, result.count { |l| l.include?("-> ") && l.include?("#add") })
    assert_equal(1, result.count { |l| l.include?("<- ") && l.include?("#add") })
  end

  def test_return_value_is_captured
    calc = Calculator.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(2, 3)
    end

    return_line = result.find { |l| l.include?("=> ") }
    assert_equal "    => 5", return_line
  end

  def test_positional_arguments_are_captured
    calc = Calculator.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(7, 8)
    end

    arg_line = result.find { |l| l.include?("a: ") }
    refute_nil arg_line
    assert_match(/a: 7/, arg_line)
    assert_match(/b: 8/, arg_line)
  end

  def test_keyword_arguments_are_captured
    greeter = Greeter.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Greeter") do
      greeter.greet("Alice", loud: true)
    end

    arg_line = result.find { |l| l.include?("name: ") }
    refute_nil arg_line
    assert_match(/name: "Alice"/, arg_line)
    assert_match(/loud: true/, arg_line)
  end

  def test_nested_calls_are_indented
    obj = Tree.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Tree") do
      obj.outer
    end

    outer_call = result.find { |l| l.include?("-> ") && l.include?("#outer") }
    inner_call = result.find { |l| l.include?("-> ") && l.include?("#inner") }

    refute_nil outer_call
    refute_nil inner_call
    assert outer_call.start_with?("-> "), "outer call should have no indent"
    assert inner_call.start_with?("  -> "), "inner call should be indented 2 spaces"
  end

  def test_filter_excludes_non_matching_classes
    calc = Calculator.new
    greeter = Greeter.new

    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(1, 2)
      greeter.greet("Bob")
    end

    call_lines = result.select { |l| l.include?("-> ") }
    assert call_lines.any? { |l| l.include?("TestTraceologist::Calculator") },
           "should include Calculator calls"
    refute call_lines.any? { |l| l.include?("TestTraceologist::Greeter") },
           "should exclude Greeter calls"
  end

  def test_filter_accepts_array
    calc = Calculator.new
    greeter = Greeter.new

    result = Traceologist.trace_sequence(
      filter: ["TestTraceologist::Calculator", "TestTraceologist::Greeter"]
    ) do
      calc.add(1, 2)
      greeter.greet("Bob")
    end

    call_classes = result.select { |l| l.include?("-> ") }.map { |l| l[/\w[\w:]+(?=\(#)/, 0] }
    assert call_classes.include?("TestTraceologist::Calculator")
    assert call_classes.include?("TestTraceologist::Greeter")
  end

  def test_show_location_adds_file_and_line
    calc = Calculator.new
    result = Traceologist.trace_sequence(
      filter: "TestTraceologist::Calculator",
      show_location: true
    ) do
      calc.add(1, 2)
    end

    call_line = result.find { |l| l.include?("-> ") && l.include?("#add") }
    assert_match(/#\s+.+\.rb:\d+/, call_line, "should include file:line comment")
  end

  def test_show_location_is_absent_by_default
    calc = Calculator.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(1, 2)
    end

    call_line = result.find { |l| l.include?("-> ") && l.include?("#add") }
    refute_match(/#\s+.+\.rb:\d+/, call_line, "should NOT include file:line comment by default")
  end

  def test_same_object_gets_consistent_sequence_number
    calc = Calculator.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(1, 2)
      calc.multiply(3, 4)
    end

    seq_numbers = result
                  .select { |l| l.include?("-> ") }
                  .map { |l| l[/#(\d+)\)/, 1] }

    assert_equal seq_numbers.uniq.length, 1,
                 "same object should always get the same sequence number"
  end

  def test_depth_limit_truncates_deep_recursion
    klass = Class.new do
      def recurse(n)
        recurse(n - 1) if n.positive?
      end
    end
    Object.const_set(:DeepRecurser, klass)

    result = Traceologist.trace_sequence(filter: "DeepRecurser", depth_limit: 3) do
      DeepRecurser.new.recurse(100)
    end

    call_lines = result.select { |l| l.include?("-> ") }
    assert call_lines.length <= 4, "should stop tracing beyond depth_limit"
  ensure
    Object.send(:remove_const, :DeepRecurser) if Object.const_defined?(:DeepRecurser)
  end

  def test_returns_array_of_strings
    calc = Calculator.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(1, 2)
    end

    assert_instance_of Array, result
    assert(result.all?(String))
  end

  def test_primitive_values_are_inspected
    calc = Calculator.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Calculator") do
      calc.add(10, 20)
    end

    arg_line = result.find { |l| l.include?("a: ") }
    assert_match(/a: 10/, arg_line)
  end

  def test_object_values_show_class_and_seq
    greeter = Greeter.new
    result = Traceologist.trace_sequence(filter: "TestTraceologist::Greeter") do
      greeter.greet("world")
    end

    return_line = result.find { |l| l.include?("=> ") }
    assert_equal '    => "world"', return_line
  end
end
