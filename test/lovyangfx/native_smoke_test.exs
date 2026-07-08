defmodule LovyanGFX.NativeSmokeTest do
  use ExUnit.Case, async: false

  @moduletag :native

  test "native module exposes expected functions" do
    assert Code.ensure_loaded?(LovyanGFX.Native)
    assert function_exported?(LovyanGFX.Native, :start, 3)
    assert function_exported?(LovyanGFX.Native, :render, 1)
    assert function_exported?(LovyanGFX.Native, :width, 0)
    assert function_exported?(LovyanGFX.Native, :height, 0)
    assert function_exported?(LovyanGFX.Native, :rotation, 0)
    assert function_exported?(LovyanGFX.Native, :moving_icons_set_status, 1)
    assert function_exported?(LovyanGFX.Native, :moving_icons_set_touch, 1)
    assert function_exported?(LovyanGFX.Native, :moving_icons_timings, 0)
  end
end
