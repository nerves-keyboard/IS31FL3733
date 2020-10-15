defmodule IS31FL3733Test do
  @moduledoc false

  use ExUnit.Case

  setup _context do
    Mox.stub_with(IS31FL3733.MockI2C, IS31FL3733.StubI2C)

    :ok
  end

  doctest IS31FL3733
end
