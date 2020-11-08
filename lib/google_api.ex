defmodule GoogleApi do
  use Tesla

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
    {:ok, a} = get("/storage/v1/b/#{@bucket}/o/?delimiter=/")
    a.body["prefixes"]
    |> Enum.map(fn id -> String.replace(id, "/", "") end)
  end

  def get_event(stream_id, event_nr) do
    {:ok, a} =
      get("/download/storage/v1/b/#{@bucket}/o/#{stream_id}%2f#{event_nr}?alt=media&fields=body")

    a.body |> Jason.decode!()
  end

  def nr_of_events_in_stream(stream_id) do
    {:ok, a} = get("/storage/v1/b/#{@bucket}/o/?prefix=#{stream_id}&fields=items(name)")

    a.body["items"]
    |> case do
      nil -> 0
      x -> length(x)
    end
  end

  def put_event(stream_id, event_nr, data) do
    enc_data = data |> Jason.encode!()

    {:ok, a} =
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
