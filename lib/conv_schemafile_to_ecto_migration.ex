defmodule ConvSchemafileToEctoMigration do
  @moduledoc """
  Documentation for `ConvSchemafileToEctoMigration`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ConvSchemafileToEctoMigration.hello()
      :world

  """
  def hello do
    :world
  end

  def gen_migration do
    text = File.read! "Schemafile2"

    text
    |> String.split("\n")
    |> Enum.reduce([], fn line, context -> _read_line(line, context) end)
    |> Enum.map(fn table -> _transform_ecto_create_table(table) end)
  end

  defp _transform_ecto_create_table(map) do
    {:ok, header} = Map.fetch(map, :table_name)
    columns = Enum.filter(map, fn x -> 
      {k, v} = x
      v[:type] && v[:type] != "index"
    end)
  end

  defp _read_line(:eof, context), do: context
  defp _read_line(line, context) do
    cond do
      table_name = Regex.named_captures(~r/create_table +(\'|\")(?<table_name>\w+)(\'|\").*/, line) 
                   -> context ++ [%{table_name: table_name}]
      matched = Regex.named_captures(~r/ *t\.index +(?<index_columns>.*), +name: +(\'|\")(?<index_name>.*)(\'|\")/, line)
                -> _conv_index(matched, context)
      matched = Regex.named_captures(~r/ *t\.(?<type>.*) +(\'|\")(?<column_name>.*)(\'|\"),*(?<options>.*)/, line)
                -> _conv_column(matched, context)
     true -> context
    end
  end

  defp _conv_index(matched, context) do
    {c, last} = _split_context(context)
    last = Map.put(last, String.to_atom(matched["index_name"]), %{ type: "index", columns: matched["index_columns"] })
    c ++ [last]
  end

  defp _conv_column(matched, context) do
    {c, last} = _split_context(context)
    last = Map.put(last, String.to_atom(matched["column_name"]), %{ type: matched["type"], options: matched["options"] })
    c ++ [last]
  end

  defp _split_context(context) do
    cond do
      length(context) == 1 -> {[], List.first(context)}
      true -> {List.delete_at(context, -1), List.last(context)}
    end
  end
end
