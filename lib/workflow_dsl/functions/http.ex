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

  def post(params, body) do
    Logger.log(:debug, "execute :post, params: #{inspect params} #{inspect body}")

    case params do
      [["url", url]] ->
        Req.request(:post, url, body: body)

      [["url", url], ["headers", headers]] ->
        Req.request(:post, url, headers: headers, body: body)

      _ -> nil
    end
  end

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
