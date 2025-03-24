defmodule NFTMediaHandler.DispatcherInterface do
  @moduledoc """
  Stub module for NFTMediaHandler.DispatcherInterface - functionality has been disabled.
  """
  require Logger
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Logger.debug("NFTMediaHandler.DispatcherInterface disabled")
    {:ok, %{}}
  end

  @impl true
  def handle_call(:take_node_to_call, _from, state) do
    {:reply, {:self, "disabled"}, state}
  end

  @doc """
  Stub for get_urls - returns empty list.
  """
  @spec get_urls(non_neg_integer()) :: {list(), atom(), String.t()}
  def get_urls(_amount) do
    {[], :self, "disabled"}
  end

  @doc """
  Stub for store_result - does nothing.
  """
  @spec store_result(any(), String.t(), atom()) :: :ok
  def store_result(_result, _url, _node) do
    :ok
  end
end