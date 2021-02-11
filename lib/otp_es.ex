defmodule OtpEs do
  use GenServer
  require Logger

  @repo GoogleApi

  def put_event(stream_id, event, expected_nr) do
    me = Node.self()
    node = get_node(stream_id)
    
    node
    |> case do
        node when node == me  ->
            IO.inspect "im me"
            put_event_local(stream_id, event, expected_nr)
        node ->
            IO.puts " im not me"
            :rpc.call(node, OtpEs, :put_event_local, [stream_id, event, expected_nr])
       end
  end

  def get_event_nr(stream_id) do
    get_node(stream_id)
    |> :rpc.call(OtpEs, :get_event_nr_local, [stream_id])
  end

  def get_node(key) do
    node = FastGlobal.get(:ring) |> ExHashRing.HashRing.find_node(key)
    Logger.info("Node for stream #{key} is #{node}")
    node
  end

  def delete_event(stream_id, nr), do: @repo.delete_event(stream_id, nr)

  ##Only to be used by aggregate
  def get_all_events_from_stream(stream_id) do
       @repo.nr_of_events_in_stream(stream_id)
       |> case do
         0 -> []
         nr -> 1..nr
       		|> Enum.to_list
       		|> Enum.map(fn index -> @repo.get_event(stream_id, index) end)
       	end
  end

  defp get_and_send_events(stream_id, pid) do
       @repo.nr_of_events_in_stream(stream_id)
       |> case do
         0 -> :ok
         nr -> 1..nr
       		|> Enum.to_list
      		|> Task.async_stream(fn index -> event = @repo.get_event(stream_id, index)
       				send(pid, {stream_id, index, event})
       				end, timeout: :infinity)
       		|> Enum.map(fn _ -> :ok end )
       		:ok
       		end
  end
       			       
  def read_and_subscribe_all_events() do
    Phoenix.PubSub.subscribe(:es_pubsub, "all")
    pid = self()
    Task.start_link(fn -> @repo.get_streams
   			  |> Task.async_stream(fn stream ->
     			  		       get_and_send_events(stream, pid)
     			  		       end, timeout: :infinity )
     		  |> Enum.map(fn result -> {:ok, :ok}  = result end)
     		    end)
   :ok
  end

  def subscribe_all_events(), do: Phoenix.PubSub.subscribe(:es_pubsub, "all")

  def start_link(args) do
      
    [stream_id: stream_id, name: name] = args
    GenServer.start_link(__MODULE__, stream_id, name: name)
  end

  def put_event_local(stream_id, event, expected_nr) do
    {:ok, pid} = find_or_start_stream_agent(stream_id)
    GenServer.call(pid, {:put_event, stream_id, event, expected_nr})
  end
  
  def get_event_nr_local(stream_id) do
    {:ok, pid} = find_or_start_stream_agent(stream_id)
    GenServer.call(pid, :get_event_nr)
  end

  def init(stream_id) do
    nr = @repo.nr_of_events_in_stream(stream_id)
    Logger.info("Nr of events on #{stream_id}")
    {:ok, nr}
  end

  def handle_call(:get_event_nr, _, event_nr), do: {:reply, event_nr, event_nr}
  
  def handle_call({:put_event, stream_id, event, -1}, _from, event_nr) do
      :ok = GoogleApi.put_event(stream_id, event_nr + 1, event)
      Phoenix.PubSub.broadcast(:es_pubsub, stream_id, {stream_id, event_nr + 1, event})
      Phoenix.PubSub.broadcast(:es_pubsub, "all", {stream_id, event_nr + 1, event})
      {:reply, :ok, event_nr + 1}
  end
  
  def handle_call({:put_event, stream_id, event, expected_nr}, _from, event_nr) do
    with true <- expected_nr == event_nr + 1,
         :ok <- GoogleApi.put_event(stream_id, expected_nr, event) do
      Phoenix.PubSub.broadcast(:es_pubsub, stream_id, {stream_id, expected_nr, event})
      Phoenix.PubSub.broadcast(:es_pubsub, "all", {stream_id, expected_nr, event})
      {:reply, :ok, expected_nr}
    else
      false -> {:reply, {:error, :wrong_expected_version}, event_nr}
   	x-> {:reply, {:error, x}, event_nr}
    end
  end

  defp find_or_start_stream_agent(stream_id) do
    Registry.lookup(StreamRegistry, stream_id)
    |> case do
      [{pid, _}] ->
        {:ok, pid}
      [] ->
        DynamicSupervisor.start_child(
          StreamSupervisor,
          {__MODULE__, stream_id: stream_id, name: {:via, Registry, {StreamRegistry, stream_id}}}
        )
    end
  end
end

defmodule OtpEs.AggregateAgent do
  use GenServer

  def with_aggregate(model, aggregate_id, function) do
    find_or_start_aggregate_agent(model, aggregate_id)
    via_tuple(model, aggregate_id) |> GenServer.call(function)
  end

  defp find_or_start_aggregate_agent(model, aggregate_id) do
    Registry.lookup(AggregateRegistry, aggregate_id)
    |> case do
      [{_, _}] -> :ok
      [] ->
        DynamicSupervisor.start_child(
          AggregateSupervisor,
          {__MODULE__, aggregate_id: aggregate_id, model: model, name: {:via, Registry, {AggregateRegistry, aggregate_id}}}
        )
    end
  end

  def start_link(args) do
	  [aggregate_id: aggregate_id, model: model, name: _] = args
      name = via_tuple(model, aggregate_id)
      GenServer.start_link(__MODULE__, {model, aggregate_id}, name: name)
  end

  defp via_tuple(model, aggregate_id) do
    {:via, Registry, {AggregateRegistry, {model, aggregate_id}}}
  end

  def init({model, aggregate_id}) do
	  IO.puts "init is returnig as well"
      GenServer.cast(self(), :finish_init)
    {:ok, {model, nil, aggregate_id, 0}}
  end

  def handle_cast(:finish_init, {model, state, aggregate_id, event_nr}) do
    events = if aggregate_id, do: OtpEs.get_all_events_from_stream(aggregate_id), else: []
    {:noreply, {model, state_from_events(model, events) || nil, aggregate_id, length(events)}}
  end

  def handle_call(function, _from, {model, state, aggregate_id, event_nr}) do
    case function.(state) do
      {:error, reason} ->
        {:reply, {:error, reason}, {model, state, aggregate_id, event_nr}}
      {new_state, event} ->
	      :ok = OtpEs.put_event(aggregate_id, event, event_nr + 1)
        {:reply, :ok, {model, new_state, aggregate_id, event_nr + 1}}
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


defmodule OtpEs.SideEffects do
  def start_link([handlers: handlers]) do
      GenServer.start_link(__MODULE__, handlers, name: __MODULE__)
  end

  def init(handlers) do
      :ok = OtpEs.subscribe_all_events()
      {:ok, handlers}
  end

  def handle_info({stream_id, event_nr, event}) do
      ## have a node check here..

  end


end


defmodule OtpEs.EventHandler do
    use GenServer

  def start_link([handlers: handlers]) do
      GenServer.start_link(__MODULE__, handlers, name: __MODULE__)
  end

  def init(handlers) do
      OtpEs.read_and_subscribe_all_events()
      {:ok, handlers}
  end

  end







    
