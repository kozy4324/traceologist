# Traceologist

Traceologist is a Ruby gem that traces method call sequences using `TracePoint`, returning a structured, human-readable log of calls, arguments, and return values.

It is designed for debugging and understanding runtime behavior — drop it into any block of code and get a clear picture of what methods were called, with what arguments, and what they returned.

## Installation

Add to your Gemfile:

```ruby
gem "traceologist"
```

Or install directly:

```bash
gem install traceologist
```

## Usage

### Basic

```ruby
require "traceologist"

class Order
  def initialize(items)
    @items = items
  end

  def total
    @items.sum { |item| item[:price] }
  end
end

result = Traceologist.trace_sequence(filter: "Order") do
  order = Order.new([{ price: 100 }, { price: 250 }])
  order.total
end

puts result.join("\n")
```

Output:

```
-> Order(#1)#initialize
    items: [{:price=>100}, {:price=>250}]
<- Order(#1)#initialize
    => Order(#1)
-> Order(#1)#total
<- Order(#1)#total
    => 350
```

### Options

#### `filter:` — Limit tracing to specific classes

Pass a class name prefix (or an array of prefixes) to exclude noise from the trace:

```ruby
Traceologist.trace_sequence(filter: "MyApp") { ... }
Traceologist.trace_sequence(filter: ["MyApp::Order", "MyApp::Item"]) { ... }
```

Without a filter, **all** Ruby method calls within the block are traced.

#### `depth_limit:` — Cap recursion depth (default: `20`)

```ruby
Traceologist.trace_sequence(depth_limit: 5, filter: "MyClass") { ... }
```

#### `show_location:` — Include source file and line number

```ruby
result = Traceologist.trace_sequence(filter: "MyClass", show_location: true) do
  MyClass.new.run
end
```

Output includes a comment on each call line:

```
-> MyClass(#1)#run # /path/to/my_class.rb:12
```

### Reading the output

Each element of the returned array is a string. The lines follow this format:

| Pattern | Meaning |
|---|---|
| `-> ClassName(#N)#method` | Method call (indented by depth) |
| `    arg: value` | Argument name and value |
| `<- ClassName(#N)#method` | Method return (indented by depth) |
| `    => value` | Return value |

`#N` is a stable sequence number assigned to each unique object instance within the traced block. The same object always gets the same number, making it easy to follow a single instance across many calls.

Primitive values (`Integer`, `Float`, `String`, `Symbol`, `nil`, `true`, `false`) are shown with `inspect`. All other objects are shown as `ClassName(#N)`.

### Printing the result

```ruby
result = Traceologist.trace_sequence(filter: "MyClass") { MyClass.new.run }
puts result.join("\n")
```

## Development

```bash
bin/setup       # install dependencies
bundle exec rake test   # run tests
bundle exec rubocop     # lint
bin/console     # interactive prompt
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kozy4324/traceologist.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
