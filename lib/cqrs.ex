
defmodule OtpEs.AggregateAgent do
  use GenServer

  def with_aggregate(model, stream_id, function) do
    find_or_start_aggregate_agent(model, stream_id)
    via_tuple(model, stream_id) |> GenServer.call(function)
  end

  defp find_or_start_aggregate_agent(model, stream_id) do
    Registry.lookup(AggregateRegistry, stream_id)
    |> case do
      [{_, _}] -> :ok
      [] ->
        DynamicSupervisor.start_child(
          AggregateSupervisor,
          {__MODULE__, stream_id: stream_id, model: model, name: {:via, Registry, {AggregateRegistry, stream_id}}}
        )
    end
  end

  def start_link(args) do
	  [stream_id: stream_id, model: model, name: _] = args
      name = via_tuple(model, stream_id)
      GenServer.start_link(__MODULE__, {model, stream_id}, name: name)
  end

  defp via_tuple(model, stream_id) do
    {:via, Registry, {AggregateRegistry, {model, stream_id}}}
  end

  def init({model, stream_id}) do
	  IO.puts "init is returnig as well"
      GenServer.cast(self(), :finish_init)
    {:ok, {model, nil, stream_id, 0}}
  end

  def handle_cast(:finish_init, {model, state, stream_id, event_nr}) do
    events = if stream_id, do: OtpEs.get_all_events_from_stream(stream_id), else: []
    {:noreply, {model, state_from_events(model, events) || nil, stream_id, length(events)}}
  end

  def handle_call(function, _from, {model, state, stream_id, event_nr}) do
    case function.(state) do
      {:error, reason} ->
        {:reply, {:error, reason}, {model, state, stream_id, event_nr}}
      {new_state, event} ->
	      :ok = OtpEs.put_event(stream_id, event, event_nr + 1)
        {:reply, :ok, {model, new_state, stream_id, event_nr + 1}}
    end
  end

  defp state_from_events(model, events) do
    events
    |> Enum.reduce(nil, fn(event, state) -> model.apply_event(state, event) end)
  end
end

defprotocol OtpEs.CommandService do
  def execute(command)
end

