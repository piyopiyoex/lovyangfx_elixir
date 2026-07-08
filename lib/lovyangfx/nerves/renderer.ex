defmodule LovyanGFX.Nerves.Renderer do
  @moduledoc """
  Nerves-friendly supervisor child for initializing the LovyanGFX renderer.

  This module does not prepare display hardware. The consuming Nerves app should
  ensure that the framebuffer device exists before this child starts.
  """

  use GenServer
  require Logger

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    if is_nil(name) do
      GenServer.start_link(__MODULE__, opts)
    else
      GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @impl true
  def init(opts) do
    {:ok, %{opts: opts}, {:continue, :start_render}}
  end

  @impl true
  def handle_continue(:start_render, %{opts: opts} = state) do
    case LovyanGFX.start(opts) do
      :ok ->
        Logger.info("LovyanGFX renderer initialized")

      :already_started ->
        Logger.warning("LovyanGFX renderer was already initialized")

      other ->
        Logger.warning("LovyanGFX renderer start returned: #{inspect(other)}")
    end

    {:noreply, state}
  end
end
