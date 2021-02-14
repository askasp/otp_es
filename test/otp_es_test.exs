


defmodule SomeEvent do
	
  defstruct [:id]
end

defmodule OtpEsTest do
    #  use GoogleApi.Storage.TestHelper

  use ExUnit.Case

  test "Read write" do

    nodes = LocalCluster.start_nodes("my-cluster", 3)
    stream_id = :crypto.strong_rand_bytes(64) |> Base.url_encode64()
    assert   GoogleApi.nr_of_events_in_stream(stream_id) == 0
    assert OtpEs.put_event(stream_id, "sahsa", -1) == :ok
    assert   GoogleApi.nr_of_events_in_stream(stream_id) == 1
    assert OtpEs.put_event(stream_id, "sahsa", 1) == {:error, :wrong_expected_version}
    assert OtpEs.put_event(stream_id, "sahsa", 2) == :ok
    assert OtpEs.put_event(stream_id, %SomeEvent{id: "as"}, 3) == :ok
    assert OtpEs.get_event_nr(stream_id) == 3
    assert OtpEs.get_all_events_from_stream(stream_id) == ["sahsa", "sahsa", %SomeEvent{id: "as"}]
    
    assert OtpEs.get_all_events_from_stream("idontexist") == []

    OtpEs.delete_event(stream_id, 1)
    OtpEs.delete_event(stream_id, 2)
    OtpEs.delete_event(stream_id, 3)
 end

    


 test "Catchup subsriber" do
    nodes = LocalCluster.start_nodes("my-cluster", 3)
    stream_id = :crypto.strong_rand_bytes(64) |> Base.url_encode64()
    stream_id2 = :crypto.strong_rand_bytes(64) |> Base.url_encode64()
    assert GoogleApi.get_streams() == []
    assert OtpEs.put_event(stream_id, "sahsa", 1) == :ok
    assert OtpEs.put_event(stream_id, "sahsa", 2) == :ok
    assert OtpEs.put_event(stream_id2, "sahsa", 1) == :ok
    assert OtpEs.put_event(stream_id2, "sahsa", 2) == :ok
    assert OtpEs.read_and_subscribe_all_events() == :ok
    assert_receive {stream_id, 1, "sahsa"}, 20000
    assert_receive {stream_id, 2, "sahsa"}, 20000
    assert_receive {stream_id2, 1, "sahsa"}, 20000
    assert_receive {stream_id2, 2, "sahsa"}, 20000

    assert OtpEs.put_event(stream_id2, "sahsa", 3) == :ok
    assert_receive {stream_id2, 3, "sahsa"}, 20000

    OtpEs.delete_event(stream_id, 1)
    OtpEs.delete_event(stream_id, 2)
    OtpEs.delete_event(stream_id2, 1)
    OtpEs.delete_event(stream_id2, 2)
    OtpEs.delete_event(stream_id2, 3)
  end

  test "Aggregate" do
       nodes = LocalCluster.start_nodes("my-cluster", 3)

       assert %Model.Counter.Create{stream_id: "agg_id"}
      |> OtpEs.CommandService.execute() == :ok
       assert %Model.Counter.Create{stream_id: "agg_id2"}
      |> OtpEs.CommandService.execute() == :ok
       assert %Model.Counter.Create{stream_id: "agg_id3"}
      |> OtpEs.CommandService.execute() == :ok

       assert %Model.Counter.Create{stream_id: "agg_id"}
      |> OtpEs.CommandService.execute() == {:error, "Already created"}

       assert %Model.Counter.Increment{stream_id: "agg_id"}
      |> OtpEs.CommandService.execute() == :ok

       state =  OtpEs.ReadModel.Counter.get("agg_id")
       assert state = %OtpEs.ReadModel.Counter.State{id: "agg_id", count: 1}

       OtpEs.delete_event("agg_id", 1)
       OtpEs.delete_event("agg_id", 2)
       OtpEs.delete_event("agg_id2", 1)
       OtpEs.delete_event("agg_id3", 1)


  end
      



end
