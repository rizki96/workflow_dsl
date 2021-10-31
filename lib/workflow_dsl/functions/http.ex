defmodule WorkflowDsl.Http do

  require Logger

  def get(params) do
    Logger.log(:debug, "execute :get, params: #{inspect params}")

    case params do
      [["url", url]] ->
        Req.request(:get, url)

      [["url", url], ["headers", headers]] ->
        Req.request(:get, url, headers: headers)

      _ -> nil
    end
  end

  #def post(url, headers, body) do
  #
  #end

  #def update(url, headers, body) do
  #
  #end

  #def delete(url, headers) do
  #
  #end

  #def request() do
  #
  #end
end
