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

  def delete(params) do
    Logger.log(:debug, "execute :delete, params: #{inspect params}")

    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => :delete})
    parameters = Enum.map(params, fn [k,v] ->
      {k, Lang.eval(func.session, v)}
    end)
    |> Enum.into(%{})

    request(:delete, parameters)
  end

  defp request(:get, %{"url" => url, "headers" => headers} = _params) do
    Req.request(:get, URI.encode(url), headers: headers)
  end
  defp request(:get, %{"url" => url} = _params) do
    Req.request(:get, URI.encode(url))
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
      body
      |> translate_body(:post)
      |> Jason.encode!()
    headers =
      headers |> Enum.map(fn [k, v] -> {k, v} end) |> Enum.into(%{})
    Req.request(:post, URI.encode(url), headers: headers, body: body)
  end
  defp request(:post, %{"url" => url, "body" => body} = _params) do
    body =
      body
      |> translate_body(:post)
      |> Jason.encode!()
    Req.request(:post, URI.encode(url), body: body)
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
      body
      |> translate_body(:put)
      |> Jason.encode!()
    headers =
      headers |> Enum.map(fn [k, v] -> {k, v} end) |> Enum.into(%{})
    Req.request(:put, URI.encode(url), headers: headers, body: body)
  end
  defp request(:put, %{"url" => url, "body" => body} = _params) do
    body =
      body
      |> translate_body(:put)
      |> Jason.encode!()
    Req.request(:put, URI.encode(url), body: body)
  end
  defp request(:put, params) do
    Logger.log(:debug, "put unknown params: #{inspect params}")
    cond do
      not Map.has_key?(params, "body") -> {:missingparam, [:body], params}
      not Map.has_key?(params, "url") -> {:missingparam, [:url], params}
      true -> {:unknownparam, [], params}
    end
  end

  defp request(:delete, %{"url" => url, "headers" => headers, "body" => body} = _params) do
    body =
      body
      |> translate_body(:delete)
      |> Jason.encode!()
    headers =
      headers |> Enum.map(fn [k, v] -> {k, v} end) |> Enum.into(%{})
    Req.request(:delete, URI.encode(url), headers: headers, body: body)
  end
  defp request(:delete, %{"url" => url, "body" => body} = _params) do
    body =
      body
      |> translate_body(:put)
      |> Jason.encode!()
    Req.request(:delete, URI.encode(url), body: body)
  end
  defp request(:delete, params) do
    Logger.log(:debug, "delete unknown params: #{inspect params}")
    cond do
      not Map.has_key?(params, "url") -> {:missingparam, [:url], params}
      true -> {:unknownparam, [], params}
    end
  end

  defp translate_body(body, http_method) do
    func = Storages.get_last_function_by(%{"module" => __MODULE__, "name" => http_method})
    if is_list(body) do
      Enum.map(body, fn b ->
        case b do
          {k, v} ->
            {k, translate_body(v, http_method)}
          [k, v] ->
            {k, translate_body(v, http_method)}
          _ -> Lang.eval(func.session, body)
        end
      end) |> Enum.into(%{})
    else
      Lang.eval(func.session, body)
    end
  end

end
