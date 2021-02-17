defmodule Model.Counter do
  defmodule State, do: defstruct([:stream_id, :count])

  defmodule Create, do: defstruct([:stream_id])
  defmodule Increment, do: defstruct([:stream_id])

  defmodule Created, do: defstruct([:stream_id])
  defmodule Incremented, do: defstruct([:stream_id])

  def create(state, stream_id) do
    if(state) do
      {:error, "Already created"}
    else
      event = %Created{stream_id: stream_id}
      {apply_event(state, event), event}
    end
  end

  def increment(state) do
    if !state do
      {:error, "Does not exist"}
    else
      event = %Incremented{stream_id: state.stream_id}
      {apply_event(state, event), event}
    end
  end

  def apply_event(_state, %Created{stream_id: stream_id}),
    do: %State{stream_id: stream_id, count: 0}

  def apply_event(state, %Incremented{stream_id: _stream_id}),
    do: %State{state | count: state.count + 1}
end

defimpl OtpEs.CommandService, for: Model.Counter.Create do
  alias Model.Counter

  def execute(command) do
    OtpEs.AggregateAgent.with_aggregate(Counter, command.stream_id, fn state ->
      state |> Counter.create(command.stream_id)
    end)
  end
end

defimpl OtpEs.CommandService, for: Model.Counter.Increment do
  alias Model.Counter

  def execute(command) do
    OtpEs.AggregateAgent.with_aggregate(Counter, command.stream_id, fn state ->
      state |> Counter.increment()
    end)
  end
end


defmodule OtpEs.ReadModel.Counter do
  defmodule State, do: defstruct([:id, :count])
  use GenServer

  def start_link(), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def init(_) do
          OtpEs.read_and_subscribe_all_events()
      {:ok, %{}}
  end

  def get(id), do: GenServer.call(__MODULE__,{:get ,id})

  def handle_call({:get, id}, _from, state) do
      return_value = Map.get(state, id)
      {:reply, return_value, state}
  end

  def handle_info({stream_id, _event_nr, %Model.Counter.Created{} = _event}, all_states) do
      new_state = Map.put(all_states, stream_id, %State{id: stream_id, count: 0})
      {:noreply, new_state}
  end

  def handle_info({stream_id, _event_nr, %Model.Counter.Incremented{}}, all_states) do
      old_state = Map.get(all_states, stream_id)
      new_state = %State{old_state | count: old_state.count + 1 }
      {:noreply, Map.put(all_states, stream_id, new_state)}
  end

  def handle_info(_,state), do: {:noreply, state}

end
