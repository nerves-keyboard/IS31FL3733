defmodule IS31FL3733 do
  @moduledoc """
  I2C driver for the IS31FL3733 12x16 dot matrix LED driver.

  This driver tries to follow the data-sheet as closely as possible, so it's
  recommended to be familiar with it: http://www.issi.com/WW/pdf/IS31FL3733.pdf

  **NOTE:** Currently only PWM mode is supported. The auto-breath feature has
  not yet been implemented in this driver.

  ## Example Usage

      iex> # each bit is one LED, 24 * 8 == 16 * 12
      ...> led_state_data = String.duplicate(<<255>>, 24)
      ...>
      ...> # each byte is one LED
      ...> led_pwm_data = String.duplicate(<<255>>, 16 * 12)
      ...>
      ...> # turn on all the LEDs in PWM mode
      ...> ic =
      ...>   "i2c-1"
      ...>   |> IS31FL3733.open(0x50)
      ...>   |> IS31FL3733.set_global_current_control(0x3C)
      ...>   |> IS31FL3733.set_swy_pull_up_resistor(:"32k")
      ...>   |> IS31FL3733.set_csx_pull_down_resistor(:"32k")
      ...>   |> IS31FL3733.set_led_on_off(0x00, led_state_data)
      ...>   |> IS31FL3733.set_led_pwm(0x00, led_pwm_data)
      ...>   |> IS31FL3733.disable_software_shutdown()
      ...>
      ...> ic
      #IS31FL3733<"i2c-1@0x50">
  """

  defstruct ~w(
    address
    bus
    bus_name
    page
    config
  )a

  @type sync_mode :: :single | :primary | :secondary

  @type led_mode :: :breathing | :pwm

  @type current_control_value :: 0x00..0xFF

  @type led_on_off_register :: 0x00..0x17

  @type led_pwm_register :: 0x00..0xBF

  @type resistor :: :none | :"500" | :"1k" | :"2k" | :"4k" | :"8k" | :"16k" | :"32k"

  @opaque t :: %__MODULE__{
            address: I2C.address(),
            bus: I2C.bus(),
            bus_name: binary() | charlist(),
            config: __MODULE__.Config.t(),
            page: 0x00..0x03
          }

  @i2c Application.compile_env(:is31fl3733, :i2c, IS31FL3733.I2C)

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

  @doc """
  Opens an I2C connection and resets the configuration.

  The address can be determined by consulting page 9, table 1 in the data-sheet.

  ## Examples

      iex> IS31FL3733.open("i2c-1", 0x50)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec open(bus_name :: binary() | charlist(), address :: I2C.address()) :: t()
  def open(bus_name, address) do
    case @i2c.open(bus_name) do
      {:ok, bus} ->
        state = %__MODULE__{
          address: address,
          bus: bus,
          bus_name: bus_name,
          page: 0,
          config: IS31FL3733.Config.default()
        }

        reset(state)

      {:error, reason} ->
        raise inspect(reason)
    end
  end

  @doc """
  Closes an I2C connection.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.close(ic)
      :ok
  """
  @spec close(state :: t()) :: :ok
  def close(state), do: @i2c.close(state.bus)

  @doc """
  Sets the sync mode.

  The default sync mode is `:single`.

  Modes:

    * `:single` - A single IC controlling a 12x16 matrix of LEDs
    * `:primary` - This IC is the primary among a set of others and supplies the
      clock signal.
    * `:secondary` - This IC is a secondary and receives its clock signal from
      the primary.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_sync_mode(ic, :primary)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec set_sync_mode(state :: t(), sync_mode :: sync_mode()) :: t()
  def set_sync_mode(state, sync_mode) when sync_mode in ~w(single primary secondary)a do
    state = %{state | config: %{state.config | sync_mode: sync_mode}}

    case write_config(state) do
      :ok -> state
      {:error, reason} -> raise inspect(reason)
    end
  end

  @doc """
  Sets the LED mode.

  The default mode is `:pwm`.

  Modes:

    * `:breathing` - Use the auto-breath feature
    * `:pwm` - Manually set the PWM of each LED

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_led_mode(ic, :pwm)
      #IS31FL3733<"i2c-1@0x50">

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_led_mode(ic, :breathing)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec set_led_mode(state :: t(), led_mode :: led_mode()) :: t()
  def set_led_mode(state, :breathing) do
    state = %{state | config: %{state.config | breathing: true}}

    case write_config(state) do
      :ok -> state
      {:error, reason} -> raise inspect(reason)
    end
  end

  def set_led_mode(state, :pwm) do
    state = %{state | config: %{state.config | breathing: false}}

    case write_config(state) do
      :ok -> state
      {:error, reason} -> raise inspect(reason)
    end
  end

  @doc """
  Enables software shutdown, causing all LEDs to be turned off.

  Software shutdown is enable by default.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.enable_software_shutdown(ic)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec enable_software_shutdown(state :: t()) :: t()
  def enable_software_shutdown(state) do
    state = %{state | config: %{state.config | software_shutdown: true}}

    case write_config(state) do
      :ok -> state
      {:error, reason} -> raise inspect(reason)
    end
  end

  @doc """
  Disables software shutdown, allowing LEDs to be turned on.

  Software shutdown is enable by default.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.disable_software_shutdown(ic)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec disable_software_shutdown(state :: t()) :: t()
  def disable_software_shutdown(state) do
    state = %{state | config: %{state.config | software_shutdown: false}}

    case write_config(state) do
      :ok -> state
      {:error, reason} -> raise inspect(reason)
    end
  end

  defp trigger_open_short_detection(state) do
    state = %{state | config: %{state.config | trigger_open_short_detection: true}}

    with :ok <- write_config(state) do
      # trigger open short detection resets back to off as soon as you use it.
      {:ok, %{state | config: %{state.config | trigger_open_short_detection: false}}}
    end
  end

  defp write_config(state) do
    with {:ok, state} <- set_page(state, @page[:function]) do
      data = IS31FL3733.Config.encode(state.config)
      write(state, @register[:function][:configuration], data)
    end
  end

  @doc """
  Sets the global current control of the CSx pins.

  See page 18, table 14 in the data-sheet for details on how this affects the
  current output of the CSx pins.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_global_current_control(ic, 0x3C)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec set_global_current_control(state :: t(), value :: current_control_value()) :: t()
  def set_global_current_control(state, value) when value in 0x00..0xFF do
    with {:ok, state} <- set_page(state, @page[:function]),
         :ok <- write(state, @register[:function][:global_current_control], value) do
      state
    else
      {:error, reason} -> raise inspect(reason)
    end
  end

  @doc """
  Sets the on/off state of individual LEDs.

  Each register controls 8 LEDs (one byte, each bit turns one LED on or off).
  E.g.: register 0x00 addresses row SW1, columns CS1 through CS8, and register
  0x01 addresses row SW1, columns CS9 through CS16, and so on.

  You can send more than one byte to the register, and each subsequent byte will
  internally increment the register by one. This allows you to set the on/off
  state of the whole matrix with one call.

  See page 14, table 6 in the data-sheet for details on how to address each LED.

  ## Examples

      iex> # each bit is one LED, 24 * 8 == 12 * 16
      ...> led_state_data = String.duplicate(<<255>>, 24)
      ...> # turns on all LEDs in the matrix:
      ...> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_led_on_off(ic, 0x00, led_state_data)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec set_led_on_off(state :: t(), start_register :: led_on_off_register(), data :: binary()) ::
          t()
  def set_led_on_off(state, start_register, data) do
    with :ok <- validate_register(start_register, @register[:led_on_off][:on_off]),
         max_writable_bytes = 0x17 - start_register + 1,
         :ok <- validate_byte_size(data, max_writable_bytes),
         {:ok, state} <- set_page(state, @page[:led_on_off]),
         :ok <- write(state, start_register, data) do
      state
    else
      {:error, reason} -> raise inspect(reason)
    end
  end

  @doc """
  Sets the PWM value of individual LEDs.

  Each register controls 1 LED (one byte, gives possible values 0..255). E.g.
  register 0x00 addresses row SW1, column CS1, and register 0x01 addresses row
  SW1, column CS2, and so on.

  You can send more than one byte to the register, and each subsequent byte will
  internally increment the register by one. This allows you to set the PWM
  values of the whole matrix with one call.

  See page 15, figure 9 in the data-sheet for details on how to address each
  LED.

  ## Examples

      iex> # each byte is one LED
      ...> led_pwm_data = String.duplicate(<<255>>, 16 * 12)
      ...> # sets the PWM value to max for all LEDs:
      ...> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_led_pwm(ic, 0x00, led_pwm_data)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec set_led_pwm(state :: t(), start_register :: led_pwm_register(), data :: binary()) :: t()
  def set_led_pwm(state, start_register, data) do
    with :ok <- validate_register(start_register, @register[:led_pwm]),
         max_writable_bytes = 0xBF - start_register + 1,
         :ok <- validate_byte_size(data, max_writable_bytes),
         {:ok, state} <- set_page(state, @page[:led_pwm]),
         :ok <- write(state, start_register, data) do
      state
    else
      {:error, reason} -> raise inspect(reason)
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

  @doc """
  Sets the internal pull-up resistor for the SWy pins.

  By default, there is no pull-up resistor set.

  Resistor values:

    * :none
    * :"500"
    * :"1k"
    * :"2k"
    * :"4k"
    * :"8k"
    * :"16k"
    * :"32k"

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_swy_pull_up_resistor(ic, :"32k")
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec set_swy_pull_up_resistor(state :: t(), resistor :: resistor()) :: t()
  def set_swy_pull_up_resistor(state, resistor) do
    with {:ok, resistor_value} <- validate_resistor(resistor),
         {:ok, state} <- set_page(state, @page[:function]),
         :ok <- write(state, @register[:function][:swy_pull_up_resistor], resistor_value) do
      state
    else
      {:error, reason} -> raise inspect(reason)
    end
  end

  @doc """
  Sets the internal pull-down resistor for the CSx pins.

  By default, there is no pull-down resistor set.

  Resistor values:

    * :none
    * :"500"
    * :"1k"
    * :"2k"
    * :"4k"
    * :"8k"
    * :"16k"
    * :"32k"

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.set_csx_pull_down_resistor(ic, :"32k")
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec set_csx_pull_down_resistor(state :: t(), resistor :: resistor()) :: t()
  def set_csx_pull_down_resistor(state, resistor) do
    with {:ok, resistor_value} <- validate_resistor(resistor),
         {:ok, state} <- set_page(state, @page[:function]),
         :ok <- write(state, @register[:function][:csx_pull_down_resistor], resistor_value) do
      state
    else
      {:error, reason} -> raise inspect(reason)
    end
  end

  defp validate_resistor(resistor) do
    case Keyword.get(@resistor, resistor) do
      nil -> {:error, :invalid_resistor}
      value -> {:ok, value}
    end
  end

  @doc """
  Resets the internal state and configuration to defaults.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> IS31FL3733.reset(ic)
      #IS31FL3733<"i2c-1@0x50">
  """
  @spec reset(state :: t()) :: t()
  def reset(state) do
    with {:ok, state} <- set_page(state, @page[:function]),
         {:ok, _result} <- read(state, @register[:function][:reset], 1) do
      # performing a reset sets the page back to the default page
      %{state | page: @page[:led_on_off], config: IS31FL3733.Config.default()}
    else
      {:error, reason} -> raise inspect(reason)
    end
  end

  @doc """
  Reports open LEDs.

  This will return a report of which LEDs are open in the circuit, i.e. missing
  LEDs.

  The report is returned as a binary, where each byte represents the open state
  of 8 LEDs. The arrangements follow the same structure as the LED on/off
  states.

  See page 14, table 6 in the data-sheet for details.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> {_ic, report} = IS31FL3733.report_open_leds(ic)
      ...> report
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  """
  @spec report_open_leds(state :: t()) :: {t(), binary()}
  def report_open_leds(state) do
    with {:ok, state} <- trigger_open_short_detection(state),
         :ok <- :timer.sleep(10),
         {:ok, state} <- set_page(state, @page[:led_on_off]),
         {:ok, result} <- read(state, @register[:led_on_off][:open].first, 24) do
      {state, result}
    end
  end

  @doc """
  Reports short LEDs.

  This will return a report of which LEDs are shorted in the circuit.

  The report is returned as a binary, where each byte represents the short state
  of 8 LEDs. The arrangements follow the same structure as the LED on/off
  states.

  See page 14, table 6 in the data-sheet for details.

  ## Examples

      iex> ic = IS31FL3733.open("i2c-1", 0x50)
      ...> {_ic, report} = IS31FL3733.report_short_leds(ic)
      ...> report
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
  """
  @spec report_short_leds(state :: t()) :: {t(), binary()}
  def report_short_leds(state) do
    with {:ok, state} <- trigger_open_short_detection(state),
         :ok <- :timer.sleep(10),
         {:ok, state} <- set_page(state, @page[:led_on_off]),
         {:ok, result} <- read(state, @register[:led_on_off][:short].first, 24) do
      {state, result}
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
    do: @i2c.write_read(state.bus, state.address, <<register>>, bytes)

  defp write(state, register, value) when is_integer(value),
    do: write(state, register, <<value>>)

  defp write(state, register, data) when is_binary(data),
    do: @i2c.write(state.bus, state.address, <<register>> <> data)
end
