defmodule ScoutCoreTest do
  use ExUnit.Case
  doctest ScoutCore

  test "greets the world" do
    assert ScoutCore.hello() == :world
  end
end
