defmodule Result.Enum do
  import Result, only: [is_error: 1]

  @doc """
  Maps over an enumerable and aborts if an error is encountered.

  Examples:

      iex> Result.Enum.map_while_ok([1, 2, 3], fn x -> if x == 2, do: {:error, "two"}, else: {:ok, x} end)
      {:error, "two"}

      iex> Result.Enum.map_while_ok([1, 2, 3], & {:ok, &1 * 2})
      {:ok, [2, 4, 6]}
  """
  def map_while_ok(enum, fun) do
    Enum.reduce_while(enum, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, new_value} -> {:cont, {:ok, [new_value | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes error results from an enumerable.

  Examples:

      iex> Result.Enum.reject_error([{:ok, 1}, {:error, 2}, {:ok, 3}, {:error, 4}])
      [{:ok, 1}, {:ok, 3}]
  """
  def reject_error(enum) do
    Enum.reject(enum, &is_error/1)
  end
end
