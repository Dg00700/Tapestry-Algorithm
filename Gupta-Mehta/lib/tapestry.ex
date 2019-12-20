defmodule Tapestry do
    use GenServer

    def start_link() do
        GenServer.start_link( __MODULE__, [], [name: :tapestry] )
    end
    def init(state) do
        {:ok,state}
    end

    def handle_call({:tapestry_network,num_of_nodes}, _from, _state) do

        list_for_nodes=Enum.reduce(1..num_of_nodes,[], fn i,acc ->

            hash_nodes = calc_hash(i,num_of_nodes,acc)

            [hash_nodes] ++ acc end)


        Enum.each(list_for_nodes, fn n_h->
           TapestryNode.start(n_h)

           GenServer.call(getPid(n_h),{:routing_init,list_for_nodes,n_h})
        end)
        {:reply,:ok,list_for_nodes}
end
    def getPid(n_id) do
        case Registry.lookup(:registry,n_id) do
            [{pid, _}]-> pid
            [] -> nil
            end
    end
    def calc_hash(i,num_of_nodes,acc) do
        hash_nodes= :crypto.hash(:sha256,Integer.to_string(i)) |> Base.encode16 |> String.slice(0..7)
        if(hash_nodes not in acc) do
            hash_nodes
        else
            calc_hash((num_of_nodes*2)+i,num_of_nodes,acc)
        end
    end

    def handle_call({:join_network,num_of_nodes,_num_of_nodes1},_from, list_for_nodes) do
        n_h = calc_hash(num_of_nodes*3,num_of_nodes,list_for_nodes)

        {:ok,_n_h_pid} =  TapestryNode.start(n_h)
        list_for_nodes=list_for_nodes++[n_h]
        GenServer.call(getPid(n_h),{:routing_init,list_for_nodes,n_h})
        GenServer.cast(getPid(n_h),{:communication_start,list_for_nodes,n_h})

        {:reply,:ok,list_for_nodes++[n_h]}
    end

    def handle_call( {:initialize_con,num_request},_from,list_for_nodes) do
        Enum.each(list_for_nodes, fn(x) ->
            GenServer.cast(getPid(x),{:find, list_for_nodes--[x], x, num_request, 0})
            Process.sleep(100)
        end)
        {:reply, :ok, list_for_nodes}
    end


    def register_name(room_name, pid) do
        GenServer.call(:registry, {:register_name, room_name, pid})
    end

    def handle_call({:get_list_for_nodes},_from, list_for_nodes)do

        {:reply,list_for_nodes,list_for_nodes}
    end



end
