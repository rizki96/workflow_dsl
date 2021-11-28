defmodule WorkflowDsl.Utils.Queue do
  use Agent

  def start_link(_args) do
    Agent.start_link(fn -> PriorityQueue.new() end, name: __MODULE__)
  end

  def push(priority_order, value) do
    Agent.update(__MODULE__, fn p -> PriorityQueue.put(p, {priority_order, value}) end)
  end

  def pop() do
    {item, pq} = Agent.get(__MODULE__, fn p -> PriorityQueue.pop(p) end)
    Agent.update(__MODULE__, fn _p -> pq end)
    item
  end

  def min() do
    Agent.get(__MODULE__, fn p -> p |> PriorityQueue.min end)
  end

  def to_list() do
    Agent.get(__MODULE__, fn p -> p |> PriorityQueue.to_list end)
  end
end
