defmodule Scout.EasySimpleTest do
  use ExUnit.Case, async: false

  alias Scout.Easy

  setup do
    # Ensure ETS adapter
    Application.put_env(:scout_core, :store_adapter, Scout.Store.ETS)

    # Start ETS store
    # Start or use existing Scout.Store.ETS process
    {pid, started_by_test?} = case Scout.Store.ETS.start_link([]) do
      {:ok, pid} -> {pid, true}
      {:error, {:already_started, pid}} -> {pid, false}
    end

    on_exit(fn ->
      # Only stop if we started it
      if started_by_test? and Process.alive?(pid) do
        GenServer.stop(pid, :normal, 1000)
      end
    end)

    {:ok, store_pid: pid}
  end

  test "store is running", %{store_pid: pid} do
    assert Process.alive?(pid)
    assert Process.whereis(Scout.Store.ETS) == pid
  end

  test "simple optimization works" do
    objective = fn params -> params.x end
    search_space = %{x: {:uniform, 0.0, 1.0}}

    result = Easy.optimize(objective, search_space, n_trials: 5, seed: 42)

    assert is_map(result)
  end
end
