defmodule Project3 do
  def main do

    [num_nodes,num_request]=System.argv()
    num_nodes=String.to_integer(num_nodes)
    num_request=String.to_integer(num_request)
    Registry.start_link(keys: :unique,name: :registry)
    {:ok,generate_pid}=Tapestry.start_link()
    GenServer.call(generate_pid,{:tapestry_network,num_nodes-1},100000)

    num_nodes1=1
    Enum.each(1..num_nodes1, fn n ->
      node=num_nodes1+n
      GenServer.call(generate_pid,{:join_network,num_nodes,node})
    end)
    GetHopCount.start()
    GenServer.call(generate_pid, {:initialize_con,num_request},10000000)

    GenServer.call(Tapestry.getPid("hop_count"), {:print_max},10000000)
end
end
Project3.main()
