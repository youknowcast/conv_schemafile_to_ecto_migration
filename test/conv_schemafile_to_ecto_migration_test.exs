defmodule ConvSchemafileToEctoMigrationTest do
  use ExUnit.Case

  @test_dir "tmp/for_test"
  @test_schemafile_path "#{@test_dir}/Schemafile"

  describe "gen_migration" do
    setup do
      current = File.cwd!
      File.mkdir_p(@test_dir)
      File.copy!("test/fixtures/Schemafile", @test_schemafile_path)
      File.cd!(@test_dir)

      on_exit fn ->
        File.rm_rf(@test_dir)
        File.cd!(current)
      end

      {:ok, dummy: :dummy}
    end

    doctest ConvSchemafileToEctoMigration

    test "create migration file" do
      assert ConvSchemafileToEctoMigration.gen_migration() == :ok

      {:ok, files} = File.ls()
      file = files |> Enum.filter(&(&1 =~ ~r/\d+_create_tables.exs/)) |> List.first
      assert file != nil

      content = File.read!(file)
      assert String.contains?(content, "create table(:staffs) do")
      assert String.contains?(content, "add :code, :string")
      assert String.contains?(content, "add :name, :string")
      assert String.contains?(content, "add :inserted_at, :utc_datetime")
      assert String.contains?(content, "add :updated_at, :utc_datetime")
    end
  end
end
