
defmodule Model.Counter do
  defmodule State, do: defstruct [:aggregate_id, :count]

  defmodule Create, do: defstruct [:aggregate_id]
  defmodule Increment, do: defstruct [:aggregate_id]

  defmodule Created, do: defstruct [:aggregate_id]
  defmodule Incremented, do: defstruct [:aggregate_id]

  def create(state, aggregate_id) do
    if(state) do
      {:error, "Already created"}
    else
    event = %Created{aggregate_id: aggregate_id}
    {apply_event(state,event), event}
    end
  end

  def increment(state) do
	  if !(state) do
		  {:error, "Does not exist"}
      else
      event =%Incremented{aggregate_id: state.aggregate_id}
      {apply_event(state, event), event}
  end
  end

  def apply_event(_state,%Created{aggregate_id: aggregate_id}), do: %State{aggregate_id: aggregate_id, count: 0}
  def apply_event(state,%Incremented{aggregate_id: _aggregate_id}), do: %State{state | count: state.count + 1}
end

defimpl OtpEs.CommandService, for: Model.Counter.Create do
  alias Model.Counter
  def execute(command) do
    OtpEs.AggregateAgent.with_aggregate(Counter, command.aggregate_id, fn(state) ->
      state |> Counter.create(command.aggregate_id)
    end)
  end
end

defimpl OtpEs.CommandService, for: Model.Counter.Increment do
  alias Model.Counter
  def execute(command) do
    OtpEs.AggregateAgent.with_aggregate(Counter, command.aggregate_id, fn(state) ->
      state |> Counter.increment
    end)
  end
end

