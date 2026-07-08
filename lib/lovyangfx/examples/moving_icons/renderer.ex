defmodule LovyanGFX.Examples.MovingIcons.Renderer do
  @moduledoc """
  Supervisor child for the native MovingIcons smoke-test renderer.
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
    case LovyanGFX.Examples.MovingIcons.start(opts) do
      :ok -> Logger.info("LovyanGFX MovingIcons demo started")
      :already_started -> Logger.warning("LovyanGFX MovingIcons demo was already started")
      other -> Logger.warning("LovyanGFX MovingIcons demo start returned: #{inspect(other)}")
    end

    {:noreply, state}
  end
end
