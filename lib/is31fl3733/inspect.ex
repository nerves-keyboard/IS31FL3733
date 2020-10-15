defimpl Inspect, for: IS31FL3733 do
  def inspect(ic, _opts) do
    "#IS31FL3733<\"#{ic.bus_name}@0x#{Integer.to_string(ic.address, 16)}\">"
  end
end
