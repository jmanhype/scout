# Purpose: run spec against Postgres
defmodule Scout.AdapterSpecPostgresTest do
  use Scout.AdapterSpec, adapter: Scout.Store.Postgres
end