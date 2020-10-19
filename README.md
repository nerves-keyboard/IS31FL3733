# IS31FL3733

[![CI Status](https://github.com/ElixirSeattle/IS31FL3733/workflows/CI/badge.svg)](https://github.com/ElixirSeattle/IS31FL3733/actions)
[![codecov](https://codecov.io/gh/ElixirSeattle/IS31FL3733/branch/master/graph/badge.svg)](https://codecov.io/gh/ElixirSeattle/IS31FL3733)
[![Hex.pm Version](https://img.shields.io/hexpm/v/is31fl3733.svg?style=flat)](https://hex.pm/packages/is31fl3733)
[![License](https://img.shields.io/hexpm/l/is31fl3733.svg)](LICENSE.md)

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
    {:is31fl3733, "~> 0.1"}
  ]
end

## License

This library is licensed under the [MIT license](./LICENSE.md)
