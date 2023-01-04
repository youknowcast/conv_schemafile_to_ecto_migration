defmodule ConvSchemafileToEctoMigration do
  @moduledoc """
  Documentation for `ConvSchemafileToEctoMigration`.
  """

  @target_migration_file "Schemafile"

  @doc """
  Generate Ecto migration file to create whole tables defined in Schemafile.

  ## Examples

      iex> ConvSchemafileToEctoMigration.gen_migration()
      :ok

  """
  def gen_migration do
    text = File.read!(@target_migration_file)
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

    indexes =
      Enum.filter(map, fn x ->
        {_k, v} = x
        v[:type] && v[:type] == "index"
      end)
      |> Enum.map(fn x ->
        {name, %{type: _type, columns: columns, options: options}} = x
        "#{_base_indent()}create index \"#{name}\", [#{columns |> Enum.map_join(",", fn x -> ":#{x}" end)}]" |> _create_index(options)

     end)

    [create_table] ++ columns ++ timestamps ++ [period] ++ indexes
  end

  defp _create_index(str, options) do
    options |> Map.keys() |> Enum.reduce(str, fn x, acc ->
      case x do
        :unique -> "#{acc}, unique: true"
        _ -> acc
      end
    end)
  end

  defp _read_line(:eof, context), do: context

  defp _read_line(line, context) do
    cond do
      table_name =
          Regex.named_captures(~r/create_table +(\'|\")(?<table_name>\w+)(\'|\").*/, line) ->
        context ++ [%{table_name: table_name}]

      matched =
          Regex.named_captures(
            ~r/ *t\.index +\[(?<index_columns>[\w\,\"\' ]+)\],?(?<index_options>.*)/,
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
    columns = _index_columns(matched["index_columns"])
    options = _index_options(matched["index_options"])
    index_name = if Map.has_key?(options, :name) do
      options.name |> String.to_atom
    else
      "index_#{last[:table_name]["table_name"]}_on_#{Enum.join(columns, "_")}" |> String.to_atom
    end

    last =
      Map.put(last, index_name, %{
        type: "index",
        columns: columns,
        options: options,
      })

    c ++ [last]
  end

  defp _conv_column(matched, context) do
    {c, last} = _split_context(context)

    last =
      Map.put(last, String.to_atom(matched["column_name"]), %{
        type: matched["type"] |> String.trim(),
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

  defp _index_columns(columns_raw) do
    columns_raw |> String.split(",") |> Enum.map(&(String.trim(&1))) |> Enum.map(&(String.replace(&1, ~r/('|")/, "")))
  end

  defp _index_options(options_raw) do
    conv_opt = fn str ->
      opt = str |> String.split(":") |> Enum.map(&(String.trim(&1))) |> Enum.map(&(String.replace(&1, ~r/('|")/, "")))
      %{"#{Enum.at(opt, 0)}": Enum.at(opt, 1)}
    end

    fragments = options_raw |> String.split(",") |> Enum.map(&(String.trim(&1))) |> Enum.map(&(conv_opt.(&1)))

    fragments |> Enum.reduce(%{}, fn x, acc ->
      case x do
        %{name: name} -> put_in(acc[:name], name)
        %{unique: "true"} -> put_in(acc[:unique], true)
        _ -> acc
      end
    end)
  end
end
