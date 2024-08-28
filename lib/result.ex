defmodule Result do
  @moduledoc """
  Utilities for working with :ok/:error results.
  """

  @type success() :: {:ok, any()}
  @type success(value) :: {:ok, value}

  @type error(reason) :: :error | {:error, reason}
  @type error() :: :error | {:error, any()}

  @typedoc """
  A Result a status tuple, or (more rarely) just a .

  In many cases, the return value of a function needs to be typed as:

      {:ok, SomeStruct.t()} | {:error, Ecto.Changeset.t()}

  This type can be used in place of it the above:

      Result.t(SomeStruct.t(), Ecto.Changeset.t())

  Here's an example usage in a `@spec`:

      @spec fetch(Ecto.UUID.t()) :: Result.t(MapAction.t(), :not_found)
  """
  @type t(success_value, error_reason) :: success(success_value) | error(error_reason)
  @type t() :: success() | error()

  defguard is_ok(result) when result == :ok or elem(result, 0) == :ok
  defguard is_error(result) when result == :error or elem(result, 0) == :error

  @doc """
  Transforms a list of ok/error tuples to a single ok/error result

  If all the results are `:ok` then it returns `{:ok, results}`
  If any of the results are `:error` then it returns `{:error, results}`

      iex> Result.collect_errors([
      ...>  {:ok, 42},
      ...>  {:ok, "abc"}
      ...> ])
      {:ok, [42, "abc"]}

      iex> Result.collect_errors([
      ...>  :ok,
      ...>  {:ok, "abc"}
      ...> ])
      {:ok, [:ok, "abc"]}

      iex> Result.collect_errors([
      ...>  {:error, :invalid},
      ...>  {:ok, "abc"}
      ...> ])
      {:error, [:invalid]}

      iex> Result.collect_errors([])
      {:ok, []}

      # Other keys are considered an error
      iex> Result.collect_errors([
      ...>  {:ok, 42},
      ...>  {:layer, :not_ok},
      ...>  {:error, 24},
      ...> ])
      {:error, [%{layer: [:not_ok]}, 24]}
  """
  def collect_errors(results) do
    group_results(results)
    |> Map.split([:ok, :error])
    |> case do
      {%{error: errors}, others} when others != %{} -> {:error, [others | errors]}
      {%{ok: results, error: []}, _others} -> {:ok, results}
      {%{ok: _results, error: errors}, _others} -> {:error, errors}
    end
  end

  @doc """
  Drops the values from an `:ok` result tuple.

  This is useful when the results are meaningless to the caller, and you want to just
  return `:ok` or an error tuple.

  Examples:

      iex> Result.summarize({:ok, 42})
      :ok

      iex> Result.summarize({:error, :not_found})
      {:error, :not_found}
  """
  @spec summarize(t()) :: :ok | error()
  def summarize(result) when is_ok(result), do: :ok
  def summarize(result) when is_error(result), do: result

  @doc """
  Similar to `Kernel.tap/2` but only calls the function if it receives an `:ok` result

      iex> Result.tap_if_ok({:ok, 42}, fn val -> val + 1 end)
      {:ok, 42}

      iex> Result.tap_if_ok(:ok, fn -> :side_effects_go_here end)
      :ok
  """
  @spec tap_if_ok(t(), (any -> any) | (-> any)) :: t()
  def tap_if_ok({:ok, value}, fun) when is_function(fun, 1) do
    fun.(value)
    {:ok, value}
  end

  def tap_if_ok(:ok, fun) when is_function(fun, 0) do
    fun.()
    :ok
  end

  def tap_if_ok(result, _), do: result

  @doc """
  Call a function if the result is `{:ok, _}`, returning the result as a result tuple.

  Otherwise, returns the error result as is.

  This is a nice alternative to piping into a `case` statement where you only want to
  keep "doing stuff" if the previous (fallible) operation was successful. It's kind of
  the opposite of `tap_if_ok/2`, which discards the result of the function within
  your pipeline.

  Examples:

      iex> Result.map_ok({:ok, 42}, fn val -> val + 1 end)
      {:ok, 43}

      iex> Result.map_ok({:ok, 42}, fn val -> {:ok, val + 1} end)
      {:ok, 43}

      iex> Result.map_ok({:ok, 42}, fn _ -> {:error, "Next operation failed"} end)
      {:error, "Next operation failed"}

      iex> Result.map_ok({:error, :check_notice}, fn val -> val + 1 end)
      {:error, :check_notice}
  """
  def map_ok({:ok, val}, fun) do
    case fun.(val) do
      {status, _} = result when status in [:ok, :error] -> result
      status when status in [:ok, :error] -> status
      unwrapped_value -> {:ok, unwrapped_value}
    end
  end

  def map_ok(result, _fun), do: result

  @doc """
  Transforms error values in the same way `map_ok/2` does for success values.

  Examples:

      iex> Result.map_error({:error, :check_notice}, fn _ -> :my_custom_error end)
      {:error, :my_custom_error}

      iex> Result.map_error({:ok, 42}, fn _ -> "not called" end)
      {:ok, 42}
  """
  def map_error({:error, val}, fun) do
    case fun.(val) do
      {status, _} = result when status in [:ok, :error] -> result
      status when status in [:ok, :error] -> status
      unwrapped_value -> {:error, unwrapped_value}
    end
  end

  def map_error(result, _fun), do: result

  @doc """
  Takes a list of result tuples and groups them by their status atom.

  Optionally takes an enumerable of atoms we'll guarantee end up in the resulting map
  (even if they're mapped to the empty list).

  Example:

      iex> Result.group_results([{:ok, 1}, {:error, 2}, {:ok, 3}, {:error, 4}, {:other, 5}])
      %{ok: [1, 3], error: [2, 4], other: [5]}

      iex> Result.group_results([:ok, {:ok, 2}, {:error, 3}])
      %{ok: [:ok, 2], error: [3]}

      iex> Result.group_results([{:ok, 1}, {:ok, 2}])
      %{ok: [1, 2], error: []}

      iex> Result.group_results([{:ok, :a, :b, :c}, {:ok, 2}])
      %{ok: [{:a, :b, :c}, 2], error: []}

      iex> Result.group_results([{:foo, 1}, {:bar, 2}], [:baz, :bang])
      %{foo: [1], bar: [2], baz: [], bang: []}
  """
  def group_results(result_tuples, required_keys \\ [:ok, :error]) do
    base_map = Map.new(required_keys, fn key -> {key, []} end)

    result_tuples
    # Group by atom, but extract the values
    |> Enum.group_by(&grouping_key/1, &grouping_val/1)
    |> Enum.into(base_map)
  end

  @doc """
  Unwraps the successful value, or a fallback value if the result is an error.

  Modeled after `Result.Operators.with_default/2` in the Result package:
  https://hexdocs.pm/result/Result.Operators.html#with_default/2

  ## Examples

      iex> Result.unwrap({:ok, 42}, 0)
      42

      iex> Result.unwrap({:error, :not_found}, nil)
      nil

      iex> Result.unwrap({:error, :not_found}, "default")
      "default"
  """
  @spec unwrap(t(), any) :: any
  def unwrap(result_tuple, default)
  def unwrap({:ok, value}, _default), do: value
  def unwrap({:error, _}, default), do: default

  defp grouping_key(:ok), do: :ok
  defp grouping_key(:error), do: :error
  defp grouping_key(tuple) when is_tuple(tuple), do: elem(tuple, 0)

  defp grouping_val(:ok), do: :ok
  defp grouping_val(:error), do: :error
  defp grouping_val({_, val}), do: val
  defp grouping_val(tuple) when is_tuple(tuple), do: Tuple.delete_at(tuple, 0)
end
