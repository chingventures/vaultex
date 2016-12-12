defmodule Vaultex.Write do

  def handle(key, value, state = %{token: token}) do
    request(:put, "#{state.url}#{key}", value, [{"X-Vault-Token", token}])
    |> handle_response(state)
  end

  def handle(_key, _value, state = %{}) do
    {:reply, {:error, ["Not Authenticated"]}, state}
  end

  defp handle_response({:ok, response}, state) do
    case response do
      %{status_code: 204} -> {:reply, {:ok}, state}
      _ -> {:reply, {:error, response.body |> Poison.Parser.parse! |> Map.fetch("errors")}, state}
    end
  end

  defp handle_response({_, %HTTPoison.Error{reason: reason}}, state) do
      {:reply, {:error, ["Bad response from vault", "#{reason}"]}, state}
  end

  defp request(method, url, params = %{}, headers) do
    HTTPoison.request(method, url, Poison.Encoder.encode(params, []), headers)
  end

end
