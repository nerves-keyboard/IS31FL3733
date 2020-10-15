# IS31FL3733

I2C driver for the IS31FL3733 12x16 dot matrix LED driver.

This driver tries to follow the
[data-sheet](http://www.issi.com/WW/pdf/IS31FL3733.pdf) as closely as possible,
so it's recommended to be familiar with it.

**NOTE:** Currently only PWM mode is supported. The auto-breath feature has not
yet been implemented in this driver.

Please see the [docs](https://hexdocs.pm/is31fl3733) for more details on usage.

## Installation

The package can be installed by adding `is31fl3733` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:is31fl3733, "~> 0.1.0"}
  ]
end
```
