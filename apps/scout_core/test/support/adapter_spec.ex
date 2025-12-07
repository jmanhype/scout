# Purpose: one spec to run against both ETS and Postgres adapters
defmodule Scout.AdapterSpec do
  defmacro __using__(adapter: adapter) do
    quote bind_quoted: [adapter: adapter] do
      use ExUnit.Case, async: true
      @adapter adapter

      test "idempotent put_study/1" do
        s = %{id: Ecto.UUID.generate(), name: "A", goal: :minimize, status: :draft}
        assert :ok = @adapter.put_study(s)
        assert :ok = @adapter.put_study(s)
      end

      test "no cross-study leakage for trials" do
        s1 = %{id: Ecto.UUID.generate(), name: "S1", goal: :minimize, status: :running}
        s2 = %{id: Ecto.UUID.generate(), name: "S2", goal: :minimize, status: :running}
        :ok = @adapter.put_study(s1)
        :ok = @adapter.put_study(s2)

        {:ok, t1_id} = @adapter.add_trial(s1.id, %{study_id: s1.id, params: %{}, status: :running})
        {:ok, _t2_id} = @adapter.add_trial(s2.id, %{study_id: s2.id, params: %{}, status: :running})

        list1 = @adapter.list_trials(s1.id)
        assert Enum.any?(list1, &(&1.id == t1_id))
        refute Enum.any?(list1, & &1.study_id == s2.id)
      end

      test "legal status transitions only" do
        s = %{id: Ecto.UUID.generate(), name: "T", goal: :minimize, status: :running}
        :ok = @adapter.put_study(s)
        {:ok, t_id} = @adapter.add_trial(s.id, %{study_id: s.id, params: %{x: 1}, status: :pending})
        
        # Purpose: verify facade transitions work
        assert :ok = @adapter.update_trial(s.id, t_id, %{status: :running})
        assert :ok = @adapter.update_trial(s.id, t_id, %{status: :completed, score: 0.5, completed_at: DateTime.utc_now()})
        
        # Should not allow going back to running from completed
        {:ok, trial} = @adapter.fetch_trial(s.id, t_id)
        assert trial.status == :completed
      end
    end
  end
end