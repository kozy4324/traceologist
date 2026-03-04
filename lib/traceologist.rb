# frozen_string_literal: true

require_relative "traceologist/version"

# Traceologist traces Ruby method call sequences using TracePoint,
# returning a structured log of calls, arguments, and return values.
module Traceologist
  class Error < StandardError; end

  # A String subclass returned by {trace_sequence} that supports writing to a file with `>>`.
  class String < ::String
    # Writes the trace to a file. Raises if the file already exists.
    # @param path [String] destination file path
    def >>(other)
      raise "A file already exists!" if File.exist?(other)

      File.write(other, to_s)
    end
  end

  # Traces method call sequences within the given block using TracePoint.
  #
  # @param depth_limit [Integer] Maximum call depth to trace (default: 20)
  # @param filter [String, Symbol, Array<String, Symbol>, nil] Only trace classes whose name
  #   starts with one of these prefixes. When nil, all calls are traced.
  # @param show_location [Boolean] Whether to include source file and line number (default: false)
  # @yield The block of code to trace
  # @return [Traceologist::String] The call sequence as a newline-joined string
  #
  # @example
  #   result = Traceologist.trace_sequence(filter: "MyClass") { MyClass.new.run }
  #   puts result
  def self.trace_sequence(depth_limit: 20, filter: nil, show_location: false, &)
    Tracer.new(depth_limit: depth_limit, filter: filter, show_location: show_location).run(&)
  end

  # @api private
  class Tracer
    def initialize(depth_limit:, filter:, show_location:)
      @depth_limit = depth_limit
      @filter = filter
      @show_location = show_location
      @depth = 0
      @call_stack = []
      @calls = []
      @object_registry = {}.compare_by_identity
      @next_id = 0
    end

    def run(&)
      trace_point = TracePoint.new(:call, :return) { |event| handle(event) }
      trace_point.enable(&)
      Traceologist::String.new(@calls.join("\n"))
    end

    private

    def handle(event)
      assign_seq(event.self)
      case event.event
      when :call then on_call(event)
      when :return then on_return(event)
      end
    end

    def on_call(event)
      unless matches?(event.defined_class.to_s) && @depth <= @depth_limit
        @call_stack << false
        return
      end

      @call_stack << true
      @calls << call_line(event)
      record_args(event)
      @depth += 1
    end

    def on_return(event)
      return unless @call_stack.pop

      @depth -= 1
      indent = "  " * @depth
      @calls << "#{indent}<- #{label(event)}"
      @calls << "#{indent}    => #{format_value(event.return_value)}"
    end

    def call_line(event)
      indent = "  " * @depth
      location = @show_location ? " # #{event.path}:#{event.lineno}" : ""
      "#{indent}-> #{label(event)}#{location}"
    end

    def record_args(event)
      indent = "  " * @depth
      args = event.parameters.filter_map do |(type, name)|
        next if name.nil? || type == :block

        val = event.binding.local_variable_get(name)
        "#{name}: #{format_value(val)}"
      end
      @calls << args.map { |arg| "#{indent}    #{arg}" }.join("\n") unless args.empty?
    rescue StandardError
      # ignore binding errors
    end

    def label(event)
      "#{event.defined_class}(##{@object_registry[event.self]})##{event.method_id}"
    end

    def matches?(class_name)
      @filter.nil? || Array(@filter).any? { |prefix| class_name.start_with?(prefix.to_s) }
    end

    def assign_seq(obj)
      @object_registry[obj] ||= (@next_id += 1)
    rescue StandardError
      nil
    end

    def format_value(val)
      case val
      when Numeric, ::String, Symbol, NilClass, TrueClass, FalseClass
        val.inspect
      else
        "#{val.class}(##{assign_seq(val)})"
      end
    end
  end

  private_constant :Tracer
end
