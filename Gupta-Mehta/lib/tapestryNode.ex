defmodule TapestryNode do

  def start(tap_node) do
      GenServer.start_link(__MODULE__,[], name: {:via, Registry, {:registry, tap_node}})
  end

  def init(state) do
      {:ok, state}
  end



  @spec update_r(any, any, any, non_neg_integer) :: any
  def update_r(routing_table,list_for_node,n_h,0), do: routing_table

  def update_r(routing_table,list_for_node,n_h,row_num) do
      rowline = Enum.filter(list_for_node,fn(nodes) -> String.slice(nodes,0,row_num-1)==String.slice(n_h,0,row_num-1) end)
      oned_table = %{}
      sub_table = generate_column(oned_table,rowline,n_h,row_num,15)
      list_for_node = list_for_node -- rowline
      routing_table = put_in(routing_table[row_num],sub_table)
      update_r(routing_table,list_for_node,n_h,row_num-1)
  end

  def generate_column(oned_table,rowline,n_h,row_num,-1), do: oned_table

  def generate_column(oned_table,rowline,n_h,row_num,col_num) do
      col_name = "0123456789ABCDEF"

      value = Enum.filter(rowline, fn(x) ->  String.at(x,row_num-1) == String.at(col_name,col_num) end)


      int_hashvalue = List.to_integer(n_h |> Kernel.to_charlist(),16)
       if(value != []) do
        update_hashvalue(oned_table,rowline,n_h,row_num,-1,value,int_hashvalue,col_name,col_num)
       else
        oned_table = put_in(oned_table[String.at(col_name,col_num)],value)
        generate_column(oned_table,rowline,n_h,row_num,col_num-1)
      end
  end
  def update_hashvalue(oned_table,rowline,n_h,row_num,-1,value,int_hashvalue,col_name,col_num)do
        {hash_value,_diff} = Enum.min_by(Enum.map(value, fn x -> {x, abs(List.to_integer(x |> to_charlist(),16) - int_hashvalue) } end),
        fn({x,y}) -> y end)
        oned_table = put_in(oned_table[String.at(col_name,col_num)],hash_value)
        generate_column(oned_table,rowline,n_h,row_num,col_num-1)
  end
  def initialize_con(pid,list_for_node,begin_n,num_request) do

    Enum.each(1..num_request, fn(request_number) ->
        IO.inspect pid, label: "source pid in task"
        IO.puts "#{begin_n} - #{request_number}"
        GenServer.cast(pid,{:pass_r,begin_n,begin_n,begin_n,0})
    end)
end
def handle_call({:initialize_con, list_for_node, num_requests},_from,state) do
    Enum.each(list_for_node, fn(node) ->

        GenServer.cast(TapestryNode.getPid(node), {:find,list_for_node--[node],node, num_requests})
    end)
    {:reply, :ok, state}
end

  def handle_cast({:communication_start,list_for_node,n_h},state) do
      temp_list = list_for_node -- [n_h]
      Enum.each(temp_list,fn(node) ->
          GenServer.cast(getPid(node),{:new_table,n_h,node})
      end)

      {:noreply,state}
  end

  def handle_cast({:new_table,new_node,node},routing_table) do
      index = Enum.find(1..8, fn x -> (String.at(node,x - 1) != String.at(new_node,x-1)) end)
      temp  = routing_table[index][String.at(new_node, index)]
      if(temp != [] && temp != nil) do
        calc_prefix(node,new_node,temp,index)
      else
          GenServer.cast(self(),{:closest,index,new_node})
      end
      {:noreply,routing_table}
  end
  def calc_prefix(node,new_node,temp,index) do
    int_node = List.to_integer(node |> Kernel.to_charlist(),16)
    int_new_node = List.to_integer(new_node |> Kernel.to_charlist(),16)
    int_temp = List.to_integer(temp |> Kernel.to_charlist(),16)
    if(abs(int_new_node - int_node) < abs(int_temp - int_node)) do
        GenServer.cast(self(),{:closest,index,new_node})
    end
  end

  def handle_cast({:closest,index,new_node},routing_table) do
      routing_table = put_in(routing_table[index][String.at(new_node, index)],new_node)
      {:noreply, routing_table}
  end

  # Counter code
  def handle_cast({:find, list_for_node, begin_n, num_request, count}, routing_table) do

    Enum.each(1..num_request, fn(_request_number) ->
        GenServer.cast(self(),{:pass_r, begin_n, begin_n, Enum.random(list_for_node), count+1, num_request})
    end)
    {:noreply,routing_table,routing_table}
  end

  def handle_cast({:pass_r,begin_n,temp,final_n,count,num_request},routing_table) do

    if(temp == final_n) do
        GenServer.cast(getPid(begin_n),{:comm_done, count,num_request})

    else
        index = Enum.find(1..8, fn x -> (String.at(temp,x - 1) != String.at(final_n,x-1)) end)
        present_nodes  = routing_table[index][String.at(final_n, index-1)]
        GenServer.cast(getPid(present_nodes),{:pass_r,begin_n,present_nodes,final_n,count+1,num_request})
    end
    {:noreply,routing_table}
  end

  def handle_cast({:comm_done, count,num_request}, routing_table) do

    GenServer.cast(getPid("hop_count"), {:get_max_count, count})
        {:noreply,routing_table}
  end

  def handle_call({:routing_init,list_for_node,n_h},_from, state)do

    routing_table = %{}
    rout_fill = update_r(routing_table,list_for_node,n_h,8 )
    {:reply, state,rout_fill}
  end
  def getPid(n_id) do
      case Registry.lookup(:registry, n_id) do
      [{pid, _}] -> pid
      [] -> nil
      end
  end

end
