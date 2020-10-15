defmodule IS31FL3733.StubI2C do
  @moduledoc false

  @behaviour IS31FL3733.I2CBehavior

  @impl true
  def open(bus_name), do: {:ok, "fake-reference-for-#{bus_name}"}

  @impl true
  def close(_i2c_bus), do: :ok

  @impl true
  def write(_i2c_bus, _address, _data, _opts \\ []), do: :ok

  @impl true
  def write_read(_i2c_bus, _address, _write_data, bytes_to_read, _opts \\ []),
    do: {:ok, String.duplicate(<<0>>, bytes_to_read)}
end
