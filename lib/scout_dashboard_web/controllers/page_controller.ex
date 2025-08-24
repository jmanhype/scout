
defmodule ScoutDashboardWeb.PageController do
  use ScoutDashboardWeb, :controller
  def home(conn, _params), do: render(conn, :home)
end
