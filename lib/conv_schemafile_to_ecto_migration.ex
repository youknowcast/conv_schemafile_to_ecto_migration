defmodule ConvSchemafileToEctoMigration do
  @moduledoc """
  Documentation for `ConvSchemafileToEctoMigration`.
  """

  @doc """
  Generate Ecto migration file to create whole tables defined in Schemafile.

  ## Examples

      iex> ConvSchemafileToEctoMigration.gen_migration()
      :ok

  """
  def gen_migration do
    text = File.read!("Schemafile")

    output =
      text
      |> String.split("\n")
      |> Enum.reduce([], fn line, context -> _read_line(line, context) end)
      |> Enum.map(fn table -> _transform_ecto_create_table(table) end)
      |> Enum.map_join("\n", &Enum.join(&1, "\n"))

    datetime = DateTime.now!("Etc/UTC") |> _migration_format_datetime
    File.write!("#{datetime}_create_tables.exs", _ecto_template(output))
  end

  defp _migration_format_datetime(d),
    do:
      "#{d.year}#{_zero_padding(d.month)}#{_zero_padding(d.day)}#{_zero_padding(d.hour)}#{_zero_padding(d.minute)}#{d.second}"

  defp _zero_padding(i), do: i |> Integer.to_string() |> String.pad_leading(2, "0")

  defp _base_indent, do: "    "

  defp _ecto_template(definition) do
    """
    defmodule MyApi.Repo.Migrations.CreateTables do
      use Ecto.Migration

      def change do
    #{definition}
      end
    end
    """
  end

  # ref.: https://devhints.io/phoenix-migrations
  defp _transform_ecto_create_table(map) do
    {:ok, header} = Map.fetch(map, :table_name)
    create_table = "#{_base_indent()}create table(:#{header["table_name"]}) do"

    columns =
      Enum.filter(map, fn x ->
        {k, v} = x
        v[:type] && v[:type] != "index" && k not in [:created_at, :updated_at]
      end)
      |> Enum.sort()
      |> Enum.map(fn x ->
        {name, %{type: type, options: _options}} = x
        "#{_base_indent()}  add :#{name}, :#{type}"
      end)

    # Ecto default timestamps create `inserted_at`
    timestamps =
      [:inserted_at, :updated_at]
      |> Enum.map(fn name ->
        "#{_base_indent()}  add :#{name}, :utc_datetime"
      end)

    period = "#{_base_indent()}end"

    [create_table] ++ columns ++ timestamps ++ [period]
  end

  defp _read_line(:eof, context), do: context

  defp _read_line(line, context) do
    cond do
      table_name =
          Regex.named_captures(~r/create_table +(\'|\")(?<table_name>\w+)(\'|\").*/, line) ->
        context ++ [%{table_name: table_name}]

      matched =
          Regex.named_captures(
            ~r/ *t\.index +(?<index_columns>.*), +name: +(\'|\")(?<index_name>.*)(\'|\")/,
            line
          ) ->
        _conv_index(matched, context)

      matched =
          Regex.named_captures(
            ~r/ *t\.(?<type>.*) +(\'|\")(?<column_name>.*)(\'|\"),*(?<options>.*)/,
            line
          ) ->
        _conv_column(matched, context)

      true ->
        context
    end
  end

  defp _conv_index(matched, context) do
    {c, last} = _split_context(context)

    last =
      Map.put(last, String.to_atom(matched["index_name"]), %{
        type: "index",
        columns: matched["index_columns"]
      })

    c ++ [last]
  end

  defp _conv_column(matched, context) do
    {c, last} = _split_context(context)

    last =
      Map.put(last, String.to_atom(matched["column_name"]), %{
        type: matched["type"],
        options: matched["options"]
      })

    c ++ [last]
  end

  defp _split_context(context) do
    if length(context) == 1 do
      {[], List.first(context)}
    else
      {List.delete_at(context, -1), List.last(context)}
    end
  end
end
