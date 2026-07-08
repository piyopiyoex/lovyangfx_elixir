defmodule LovyanGFX.Nerves.RendererTest do
  use ExUnit.Case, async: false

  import Mox

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()

    previous_backend = Application.get_env(:lovyangfx_elixir, :backend)
    Application.put_env(:lovyangfx_elixir, :backend, LovyanGFX.MockBackend)

    on_exit(fn ->
      if previous_backend do
        Application.put_env(:lovyangfx_elixir, :backend, previous_backend)
      else
        Application.delete_env(:lovyangfx_elixir, :backend)
      end
    end)

    :ok
  end

  test "starts backend with display options" do
    parent = self()

    expect(LovyanGFX.MockBackend, :start, fn options ->
      assert options[:width] == 800
      assert options[:height] == 480
      assert options[:framebuffer] == "/dev/fb0"
      send(parent, :backend_started)
      :ok
    end)

    assert {:ok, pid} =
             LovyanGFX.Nerves.Renderer.start_link(
               name: nil,
               width: 800,
               height: 480,
               framebuffer: "/dev/fb0"
             )

    assert_receive :backend_started
    assert Process.alive?(pid)
  end
end
