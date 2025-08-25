defmodule ScoutDashboardWeb.PopulateController do
  use ScoutDashboardWeb, :controller

  def run(conn, %{"study_id" => study_id}) do
    # Populate ETS store directly with test data
    study = %{id: study_id, goal: :minimize}
    Scout.Store.put_study(study)
    
    # Create some sample trials
    for i <- 1..10 do
      trial = %{
        id: "trial_#{i}",
        study_id: study_id,
        params: %{x: :rand.uniform() * 10 - 5, y: :rand.uniform() * 10 - 5},
        bracket: 0,
        score: :rand.uniform() * 20,
        status: :succeeded,
        started_at: System.system_time(:millisecond),
        finished_at: System.system_time(:millisecond)
      }
      Scout.Store.add_trial(study_id, trial)
    end

    conn
    |> put_flash(:info, "Test data populated for study #{study_id}")
    |> redirect(to: "/studies/#{study_id}")
  end
end