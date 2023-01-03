defmodule ConvSchemafileToEctoMigrationCli do
  @moduledoc false

  def main(_args) do
    ConvSchemafileToEctoMigration.gen_migration()
  end
end
