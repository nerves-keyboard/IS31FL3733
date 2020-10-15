defmodule IS31FL3733.I2CBehavior do
  @moduledoc """
  Explicit contract behavior used for I2C communication.
  """

  alias Circuits.I2C

  @type bus :: I2C.bus()
  @type address :: I2C.address()
  @type opt :: I2C.opt()

  @callback open(binary() | charlist()) :: {:ok, bus()} | {:error, term()}

  @callback close(bus()) :: :ok

  @callback write(bus(), address(), iodata()) :: :ok | {:error, term()}
  @callback write(bus(), address(), iodata(), [opt()]) :: :ok | {:error, term()}

  @callback write_read(bus(), address(), iodata(), pos_integer()) ::
              {:ok, binary()} | {:error, term()}
  @callback write_read(bus(), address(), iodata(), pos_integer(), [opt()]) ::
              {:ok, binary()} | {:error, term()}
end
