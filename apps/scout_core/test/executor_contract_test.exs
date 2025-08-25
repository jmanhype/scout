# Purpose: regression test that executors never craft structs
defmodule Scout.ExecutorContractTest do
  use ExUnit.Case, async: true
  
  test "executors call Store transitions only" do
    files =
      Path.wildcard("apps/scout_core/lib/executor/**/*.ex")
      |> Enum.map(&File.read!/1)

    refute Enum.any?(files, &String.contains?(&1, "%Scout.Store.Schemas.Trial{")), """
    Executors must not construct Trial structs; use Store.start/finish/prune/fail only.
    """
    
    refute Enum.any?(files, &String.contains?(&1, "%Trial{")), """
    Executors must not construct Trial structs; use Store.start/finish/prune/fail only.
    """
  end
end