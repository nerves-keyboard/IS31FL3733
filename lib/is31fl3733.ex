defmodule IS31FL3733 do
  @moduledoc """
  TODO:
  """

  require Logger

  alias Circuits.I2C

  defstruct ~w(
    address
    bus
    bus_name
    page
    config
  )a

  # Defined pages. Use command register to change active page.
  @page [
    led_on_off: 0x00,
    led_pwm: 0x01,
    led_auto_breath: 0x02,
    function: 0x03
  ]

  # Defined registers.
  # command and command_write_lock are always available;
  # the rest of the registers are only available when the corresponding page is
  # active.
  @register [
    command: 0xFD,
    command_write_lock: 0xFE,
    led_on_off: [
      on_off: 0x00..0x17,
      open: 0x18..0x2F,
      short: 0x30..0x47
    ],
    led_pwm: 0x00..0xBF,
    led_auto_breath: 0x00..0xBF,
    function: [
      configuration: 0x00,
      global_current_control: 0x01,
      # TODO: auto breath configuration registers 0x02 - 0x0E
      swy_pull_up_resistor: 0x0F,
      csx_pull_down_resistor: 0x10,
      reset: 0x11
    ]
  ]

  @resistor [
    none: 0x00,
    "500": 0x01,
    "1k": 0x02,
    "2k": 0x03,
    "4k": 0x04,
    "8k": 0x05,
    "16k": 0x06,
    "32k": 0x07
  ]

  @command_write_lock_disable_once 0xC5

  def open(bus_name, address) do
    with {:ok, bus} <- I2C.open(bus_name) do
      state = %__MODULE__{
        address: address,
        bus: bus,
        bus_name: bus_name,
        page: 0,
        config: IS31FL3733.Config.default()
      }

      reset(state)
    end
  end

  def close(state), do: I2C.close(state.bus)

  def set_sync_mode(state, sync_mode) when sync_mode in ~w(single primary secondary)a do
    state = %{state | config: %{state.config | sync_mode: sync_mode}}
    with :ok <- write_config(state), do: {:ok, state}
  end

  def set_led_mode(state, :breathing) do
    state = %{state | config: %{state.config | breathing: true}}
    with :ok <- write_config(state), do: {:ok, state}
  end

  def set_led_mode(state, :pwm) do
    state = %{state | config: %{state.config | breathing: false}}
    with :ok <- write_config(state), do: {:ok, state}
  end

  def enable_software_shutdown(state) do
    state = %{state | config: %{state.config | software_shutdown: true}}
    with :ok <- write_config(state), do: {:ok, state}
  end

  def disable_software_shutdown(state) do
    state = %{state | config: %{state.config | software_shutdown: false}}
    with :ok <- write_config(state), do: {:ok, state}
  end

  def trigger_open_short_detection(state) do
    state = %{state | config: %{state.config | trigger_open_short_detection: true}}

    with :ok <- write_config(state) do
      # trigger open short detection resets back to off as soon as you use it.
      {:ok, %{state | config: %{state.config | trigger_open_short_detection: false}}}
    end
  end

  defp write_config(state) do
    Logger.debug(fn -> "#{logger_label(state)} Writing config" end)

    with {:ok, state} <- set_page(state, @page[:function]) do
      data = IS31FL3733.Config.encode(state.config)
      write(state, @register[:function][:configuration], data)
    end
  end

  def set_global_current_control(state, value) when value in 0x00..0xFF do
    with {:ok, state} <- set_page(state, @page[:function]),
         :ok <- write(state, @register[:function][:global_current_control], value) do
      {:ok, state}
    end
  end

  def set_led_on_off(state, start_register, data) do
    with :ok <- validate_register(start_register, @register[:led_on_off][:on_off]),
         max_writable_bytes = 0x17 - start_register + 1,
         :ok <- validate_byte_size(data, max_writable_bytes),
         {:ok, state} <- set_page(state, @page[:led_on_off]),
         :ok <- write(state, start_register, data) do
      {:ok, state}
    end
  end

  def set_led_pwm(state, start_register, data) do
    with :ok <- validate_register(start_register, @register[:led_pwm]),
         max_writable_bytes = 0xBF - start_register + 1,
         :ok <- validate_byte_size(data, max_writable_bytes),
         {:ok, state} <- set_page(state, @page[:led_pwm]),
         :ok <- write(state, start_register, data) do
      {:ok, state}
    end
  end

  defp validate_register(register, register_range) do
    if register in register_range do
      :ok
    else
      {:error, :invalid_register}
    end
  end

  defp validate_byte_size(led_data, max_writable_bytes) do
    if byte_size(led_data) <= max_writable_bytes do
      :ok
    else
      {:error, :too_much_data}
    end
  end

  def set_swy_pull_up_resistor(state, resistor) do
    with {:ok, resistor_value} <- validate_resistor(resistor),
         {:ok, state} <- set_page(state, @page[:function]),
         :ok <- write(state, @register[:function][:swy_pull_up_resistor], resistor_value) do
      {:ok, state}
    end
  end

  def set_csx_pull_down_resistor(state, resistor) do
    with {:ok, resistor_value} <- validate_resistor(resistor),
         {:ok, state} <- set_page(state, @page[:function]),
         :ok <- write(state, @register[:function][:csx_pull_down_resistor], resistor_value) do
      {:ok, state}
    end
  end

  defp validate_resistor(resistor) do
    case Keyword.get(@resistor, resistor) do
      nil -> {:error, :invalid_resistor}
      value -> {:ok, value}
    end
  end

  def reset(state) do
    Logger.debug(fn -> "#{logger_label(state)} Performing reset" end)

    with {:ok, state} <- set_page(state, @page[:function]),
         {:ok, result} <- read(state, @register[:function][:reset], 1) do
      Logger.debug(fn -> "#{logger_label(state)} Reset result: #{inspect(result)}" end)

      # performing a reset sets the page back to the default page
      {:ok, %{state | page: @page[:led_on_off], config: IS31FL3733.Config.default()}}
    end
  end

  def report_open_pixels(state) do
    with {:ok, state} <- trigger_open_short_detection(state),
         :ok <- :timer.sleep(10),
         {:ok, state} <- set_page(state, @page[:led_on_off]) do
      read(state, @register[:led_on_off][:open].first, 24)
    end
  end

  def report_short_pixels(state) do
    with {:ok, state} <- trigger_open_short_detection(state),
         :ok <- :timer.sleep(10),
         {:ok, state} <- set_page(state, @page[:led_on_off]) do
      read(state, @register[:led_on_off][:short].first, 24)
    end
  end

  defp set_page(%{page: page} = state, page), do: {:ok, state}

  defp set_page(state, page) do
    with :ok <- unlock_command_register(state),
         :ok <- write(state, @register[:command], page) do
      {:ok, %{state | page: page}}
    end
  end

  defp unlock_command_register(state),
    do: write(state, @register[:command_write_lock], @command_write_lock_disable_once)

  defp read(state, register, bytes),
    do: I2C.write_read(state.bus, state.address, <<register>>, bytes)

  defp write(state, register, value) when is_integer(value),
    do: write(state, register, <<value>>)

  defp write(state, register, data) when is_binary(data),
    do: I2C.write(state.bus, state.address, <<register>> <> data)

  defp logger_label(%{address: address, bus_name: bus_name}) do
    "IS31FL3733(#{bus_name}@0x#{Integer.to_string(address, 16)}):"
  end
end
