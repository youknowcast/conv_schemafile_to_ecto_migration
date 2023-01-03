defmodule ConvSchemafileToEctoMigrationTest do
  use ExUnit.Case
  doctest ConvSchemafileToEctoMigration

  setup_all do
    {:ok, dummy: :dummy}
  end

  test "gen_migration" do
    assert ConvSchemafileToEctoMigration.gen_migration() == :ok
  end
end
