defmodule ScoutDashboardWeb.DebugController do
  use ScoutDashboardWeb, :controller

  def test(conn, %{"study_id" => study_id}) do
    status = ScoutDashboard.ScoutClient.status(study_id)
    best = ScoutDashboard.ScoutClient.best(study_id)
    
    response = %{
      study_id: study_id,
      status: status,
      best: best,
      raw_store_study: Scout.Store.get_study(study_id),
      raw_store_trials_count: length(Scout.Store.list_trials(study_id)),
      raw_status_best: Scout.Status.best(study_id)
    }

    json(conn, response)
  end
end