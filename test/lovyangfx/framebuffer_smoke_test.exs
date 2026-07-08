defmodule LovyanGFX.FramebufferSmokeTest do
  use ExUnit.Case, async: false

  @moduletag :framebuffer

  test "starts against a framebuffer device" do
    assert File.exists?("/dev/fb0")

    assert LovyanGFX.start(width: 800, height: 480, framebuffer: "/dev/fb0") in [
             :ok,
             :already_started
           ]
  end
end
