defmodule NFTMediaHandler do
  @moduledoc """
  Stub module for NFTMediaHandler - functionality has been disabled.
  This provides compatible interfaces without performing actual work.
  """

  require Logger

  @doc """
  Stub for prepare_and_upload_by_url - returns error indicating disabled functionality.

  ## Parameters

    - url: The URL of the media to be prepared and uploaded (ignored).
    - r2_folder: The destination folder where the media would be uploaded (ignored).

  ## Returns

    - {:error, :nft_media_handler_disabled}
  """
  @spec prepare_and_upload_by_url(binary(), binary()) :: {:error, any()} | {list(), {binary(), binary()}}
  def prepare_and_upload_by_url(_url, _r2_folder) do
    Logger.debug("NFTMediaHandler functionality is disabled")
    {:error, :nft_media_handler_disabled}
  end

  @doc """
  Stub for image_to_binary - returns error indicating disabled functionality.

  ## Parameters

    - resized_image: The image to be converted (ignored).
    - file_name: used only for .gif (ignored).
    - extension: The extension of the image format (ignored).

  ## Returns

    - {:error, :nft_media_handler_disabled}
  """
  def image_to_binary(_resized_image, _file_name, _extension) do
    {:error, :nft_media_handler_disabled}
  end
end