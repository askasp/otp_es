defmodule GoogleApi do
  use Tesla
  require Logger

  @moduledoc """
  Documentation for GoogleApi.Storage.Samples.
  """
  @bucket System.get_env("BUCKET")

  plug(Tesla.Middleware.BaseUrl, "https://storage.googleapis.com")
  plug(Tesla.Middleware.Headers, [{"authorization", "Bearer #{get_token()}"}])
  plug(Tesla.Middleware.JSON)

  def get_token() do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")
    token.token
  end

  def get_streams() do
    Logger.debug("#{@bucket}")
    {:ok, a} = get("/storage/v1/b/#{@bucket}/o/?delimiter=/")
    a.body["prefixes"]
    |> case do
      nil -> []
      x -> x |> Enum.map(fn id -> String.replace(id, "/", "") end)
    end
  end


  def get_event(stream_id, event_nr) do
    {:ok, a} =
      get("/download/storage/v1/b/#{@bucket}/o/#{stream_id}%2f#{event_nr}?alt=media&fields=body")

    map = a.body |> Jason.decode!()
    
   case is_map(map) && Map.has_key?(map, "struct_type") do
      false -> map
      true -> struct(map["struct_type"]  |> String.to_atom, string_map_to_atom_map(Map.delete(map, "struct_type")))
      end
    
  end

  def string_map_to_atom_map(string_map) do
    for {key, val}  <- string_map, into: %{}, do: {String.to_atom(key), val}

  end

  def nr_of_events_in_stream(stream_id) do
    {:ok, a} = get("/storage/v1/b/#{@bucket}/o/?prefix=#{stream_id}&fields=items(name)")
    Logger.debug("Nr of events is #{inspect(a)}")

    a.body["items"]
    |> case do
      nil -> 0
      x -> length(x)
    end
  end

  def put_event(stream_id, event_nr, event) do
    
    data = case (is_map(event) && Map.has_key?(event, :__struct__) ) do
      	false -> event
      	true -> Map.from_struct(event)  |> Map.put(:struct_type, event.__struct__)
      	end

   enc_data = data |> Jason.encode!()

    {:ok, _a} =
      post(
        "/upload/storage/v1/b/#{@bucket}/o?uploadType=media&name=#{stream_id}%2f#{event_nr}",
        enc_data
      )

     :ok
  end

  def delete_event(stream_id, event_nr) do
    {:ok, a} =
      delete(
        "/storage/v1/b/#{@bucket}/o/#{stream_id}%2f#{event_nr}"
      )
     :ok

  end
end
