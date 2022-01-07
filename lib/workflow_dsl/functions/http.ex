defmodule WorkflowDsl.Http do

  require Logger
  alias WorkflowDsl.Lang
  alias WorkflowDsl.Storages

  def get(params) do
    Logger.log(:debug, "execute :get, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :get})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    request(:get, parameters)
  end

  def post(params) do
    Logger.log(:debug, "execute :post, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :post})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    request(:post, parameters)
  end

  def put(params) do
    Logger.log(:debug, "execute :update, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :put})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    request(:put, parameters)
  end

  #def delete(params) do
  #
  #end

  defp request(:get, %{"url" => url, "headers" => headers} = _params) do
    Req.request(:get, url, headers: headers)
  end
  defp request(:get, %{"url" => url} = _params) do
    Req.request(:get, url)
  end
  defp request(:get, params) do
    Logger.log(:debug, "get unknown params: #{inspect params}")
    cond do
      not Map.has_key?(params, "url") -> {:missingparam, [:url], params}
      true -> {:unknownparam, [], params}
    end
  end

  defp request(:post, %{"url" => url, "headers" => headers, "body" => body} = _params) do
    body =
    cond do
      is_tuple(body) -> Jason.encode!(Tuple.to_list(body))
      true -> Jason.encode!(body)
    end
    Req.request(:post, url, headers: headers, body: body)
  end
  defp request(:post, %{"url" => url, "body" => body} = _params) do
    body =
      cond do
        is_tuple(body) -> Jason.encode!(Tuple.to_list(body))
        true -> Jason.encode!(body)
      end
    Req.request(:post, url, body: body)
  end
  defp request(:post, params) do
    Logger.log(:debug, "post unknown params: #{inspect params}")
    cond do
      not Map.has_key?(params, "body") -> {:missingparam, [:body], params}
      not Map.has_key?(params, "url") -> {:missingparam, [:url], params}
      true -> {:unknownparam, [], params}
    end
  end

  defp request(:put, %{"url" => url, "headers" => headers, "body" => body} = _params) do
    body =
      cond do
        is_tuple(body) -> Jason.encode!(Tuple.to_list(body))
        true -> Jason.encode!(body)
      end
    Req.request(:put, url, headers: headers, body: body)
  end
  defp request(:put, %{"url" => url, "body" => body} = _params) do
    body =
      cond do
        is_tuple(body) -> Jason.encode!(Tuple.to_list(body))
        true -> Jason.encode!(body)
      end
    Req.request(:put, url, body: body)
  end
  defp request(:put, params) do
    Logger.log(:debug, "put unknown params: #{inspect params}")
    cond do
      not Map.has_key?(params, "body") -> {:missingparam, [:body], params}
      not Map.has_key?(params, "url") -> {:missingparam, [:url], params}
      true -> {:unknownparam, [], params}
    end
  end

end
