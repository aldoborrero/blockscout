defmodule NFTMediaHandler.Application do
  @moduledoc """
  Stub Application module for NFTMediaHandler - functionality has been disabled.
  """
  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    Logger.debug("NFTMediaHandler.Application starting in disabled mode")
    
    # Start a minimal supervisor with no children
    opts = [strategy: :one_for_one, name: NFTMediaHandler.Supervisor]
    Supervisor.start_link([], opts)
  end
end