defmodule IS31FL3733.Config do
  @moduledoc """
  TODO:
  """

  defstruct ~w(
    breathing
    sync_mode
    software_shutdown
    trigger_open_short_detection
  )a

  def default do
    %__MODULE__{
      sync_mode: :single,
      trigger_open_short_detection: false,
      breathing: false,
      software_shutdown: true
    }
  end

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
