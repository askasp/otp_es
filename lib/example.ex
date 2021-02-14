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

  def get(stream_id) do
      [{_id, value } ] = :ets.lookup(:rm_counter, stream_id)
      value
  end

  def handle({stream_id, _event_nr, %Model.Counter.Created{} = _event}) do
    case :ets.whereis(:rm_counter) do
      :undefined -> :ets.new(:rm_counter, [:named_table])
      _ -> :ignore
    end

    :ets.insert(:rm_counter, {stream_id, %State{id: stream_id, count: 0}})
  end

  def handle({stream_id, _event_nr, %Model.Counter.Incremented{}}) do
    state = get(stream_id)

    :ets.insert(:rm_counter, {stream_id, %State{state | count: state.count + 1 }})

  end

  def handle(_), do: :ok
end
