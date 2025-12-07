
defmodule ScoutDashboardWeb.ErrorHTML do
  use ScoutDashboardWeb, :html
  embed_templates "error_html/*"
  def render(_template, assigns), do: ~H"<p>error</p>"
end
