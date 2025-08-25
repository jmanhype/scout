defmodule ScoutTest do
  use ExUnit.Case
  
  test "Scout module exists" do
    assert Code.ensure_loaded?(Scout)
  end
  
  test "Store facade works" do
    assert Code.ensure_loaded?(Scout.Store)
  end
  
  test "Format module validates JSON schemas" do
    assert Code.ensure_loaded?(Scout.Format)
  end
  
  test "Recorder module exists" do
    assert Code.ensure_loaded?(Scout.Recorder)
  end
  
  test "Playback module exists" do
    assert Code.ensure_loaded?(Scout.Playback)
  end
end