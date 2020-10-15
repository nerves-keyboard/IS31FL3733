defmodule IS31FL3733.I2CBehavior do
  @moduledoc """
  Explicit contract behavior used for I2C communication.
  """

  alias Circuits.I2C

  @callback open(binary() | charlist()) :: {:ok, I2C.bus()} | {:error, term()}

  @callback close(I2C.bus()) :: :ok

  @callback write(I2C.bus(), I2C.address(), iodata()) :: :ok | {:error, term()}
  @callback write(I2C.bus(), I2C.address(), iodata(), [I2C.opt()]) :: :ok | {:error, term()}

  @callback write_read(I2C.bus(), I2C.address(), iodata(), pos_integer()) ::
              {:ok, binary()} | {:error, term()}
  @callback write_read(I2C.bus(), I2C.address(), iodata(), pos_integer(), [I2C.opt()]) ::
              {:ok, binary()} | {:error, term()}
end
