defmodule IS31FL3733.I2C do
  @moduledoc """
  I2C behavior implementation.
  """

  @behaviour IS31FL3733.I2CBehavior

  @impl true
  defdelegate open(bus_name), to: Circuits.I2C

  @impl true
  defdelegate close(i2c_bus), to: Circuits.I2C

  @impl true
  defdelegate write(i2c_bus, address, data, opts \\ []), to: Circuits.I2C

  @impl true
  defdelegate write_read(i2c_bus, address, write_data, bytes_to_read, opts \\ []),
    to: Circuits.I2C
end
