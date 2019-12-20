defmodule GetHopCount do
  def start()do
    GenServer.start_link(__MODULE__,-1, name: {:via, Registry, {:registry, "hop_count"}})
  end

  def init(state) do
    {:ok,state}
  end

  def handle_cast({:get_max_count, count}, max) do
    if(count>max) do
      {:noreply, count}
    else
      {:noreply,max}
    end
  end

  def handle_call({:print_max},_from, max) do
    IO.inspect max, label: "Max = "
    {:reply, :ok, max}
  end
end
