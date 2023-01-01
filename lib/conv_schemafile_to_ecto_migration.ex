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
    text = File.read! "Schemafile"

    text
    |> String.split("\n")
    |> Enum.reduce([], fn line, context ->
      _read_line(line, context)
    end)
  end

  def _read_line(:eof, context), do: context
  def _read_line(line, context) do
    cond do
      table_name = Regex.named_captures(~r/create_table +'(?<table_name>.*)'.*/, line) -> context ++ [%{table_name: table_name}]
      matched = Regex.named_captures(~r/ *t\.index +(?<index_columns>.*), +name: +(\"|\')(?<index_name>.*)(\"|\')/, line)
                -> _conv_index(matched, context)
      matched = Regex.named_captures(~r/ *t\.(?<type>.*) +\'(?<column_name>.*)\',*(?<options>.*)/, line)
                -> _conv_column(matched, context)
     true -> context
    end
  end

  defp _conv_index(matched, context) do
    [c | last] = context
    last = Map.put(last, matched[:index_name], matched[:index_raw])
    [c | last]
  end

  defp _conv_column(matched, context) do
    [c, last] = cond do
      length(context) == 1 -> [[], List.first(context)]
      true -> [List.delete_at(context, -1), List.last(context)]
    end
    last = Map.put(last, matched["column_name"], %{ type: matched["type"], options: matched["options"] })
    c ++ [last]
  end
end
