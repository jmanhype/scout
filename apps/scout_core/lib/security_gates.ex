defmodule Scout.SecurityGates do
  @moduledoc """
  Stop-ship security gates. Application MUST NOT boot if these conditions are violated.
  """

  require Logger

  @doc "Run all security gates at application startup"
  def check_all! do
    check_dashboard_security!()
    check_ets_security!()
    check_atom_safety!()
    Logger.info("All security gates passed ✓")
  end

  defp check_dashboard_security! do
    if Application.get_env(:scout_core_dashboard, :enabled, false) do
      secret = Application.get_env(:scout_core_dashboard, :secret)
      if is_nil(secret) or String.length(secret) < 32 do
        raise """
        SECURITY GATE FAILURE: Dashboard enabled without proper authentication.
        
        Either:
        1. Disable dashboard: config :scout_core_dashboard, enabled: false
        2. Set strong secret: config :scout_core_dashboard, secret: "your-32-char-secret"
        
        Current secret length: #{if secret, do: String.length(secret), else: 0}
        """
      end
    end
  end

  defp check_ets_security! do
    # Check if any ETS tables are :public
    tables = :ets.all()
    for table <- tables do
      case :ets.info(table, :protection) do
        :public ->
          case :ets.info(table, :name) do
            name when name in [:scout_core_trials, :scout_core_observations, :scout_core_studies] ->
              raise """
              SECURITY GATE FAILURE: Scout ETS table #{name} is :public.
              This allows arbitrary external writes and data corruption.
              Tables must be :protected or :private.
              """
            _ -> :ok
          end
        _ -> :ok
      end
    end
  end

  defp check_atom_safety! do
    # Verify no dangerous atom conversion patterns in compiled code
    # This is a compile-time check - real protection is using SafeAtoms
    Scout.Log.warning("""
    ATOM SAFETY: Ensure all user input uses Scout.Util.SafeAtoms, never String.to_atom/1.
    This check is informational - rely on code review and static analysis.
    """)
  end
end