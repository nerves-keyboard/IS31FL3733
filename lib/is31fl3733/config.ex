defmodule IS31FL3733.Config do
  @moduledoc """
  Represents the config byte of the IS31FL3733's configuration register.
  """

  defstruct ~w(
    breathing
    sync_mode
    software_shutdown
    trigger_open_short_detection
  )a

  @type sync_mode :: :single | :primary | :secondary

  @type t :: %__MODULE__{
          breathing: boolean(),
          sync_mode: sync_mode(),
          software_shutdown: boolean(),
          trigger_open_short_detection: boolean()
        }

  @doc """
  Returns the default configuration.
  """
  @spec default :: t()
  def default do
    struct!(__MODULE__, %{
      sync_mode: :single,
      trigger_open_short_detection: false,
      breathing: false,
      software_shutdown: true
    })
  end

  @doc """
  Encodes a configuration struct into a configuration byte for writing to the
  configuration register.
  """
  @spec encode(config :: t()) :: binary()
  def encode(%__MODULE__{} = config) do
    <<
      sync_mode(config.sync_mode)::size(2),
      0::size(3),
      to_int(config.trigger_open_short_detection)::size(1),
      to_int(config.breathing)::size(1),
      to_int(!config.software_shutdown)::size(1)
    >>
  end

  defp to_int(true), do: 0x1
  defp to_int(false), do: 0x0

  defp sync_mode(:single), do: 0x00
  defp sync_mode(:primary), do: 0x01
  defp sync_mode(:secondary), do: 0x02
end
