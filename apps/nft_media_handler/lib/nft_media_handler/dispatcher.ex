defmodule NFTMediaHandler.Dispatcher do
  @moduledoc """
  Stub module for NFTMediaHandler.Dispatcher - functionality has been disabled.
  """
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.debug("NFTMediaHandler.Dispatcher disabled")
    {:ok, %{}}
  end

  # All other messages are ignored
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end