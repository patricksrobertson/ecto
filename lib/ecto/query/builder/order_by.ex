defmodule Ecto.Query.Builder.OrderBy do
  @moduledoc false

  alias Ecto.Query.Builder

  @doc """
  Escapes an order by query.

  The query is escaped to a list of `{direction, expression}`
  pairs at runtime. Escaping also validates direction is one of
  `:asc` or `:desc`.

  ## Examples

      iex> escape(quote do [x.x, desc: 13] end, [x: 0])
      {[asc: {:{}, [], [{:{}, [], [:., [], [{:{}, [], [:&, [], [0]]}, :x]]}, [], []]},
        desc: 13],
       %{}}

  """
  @spec escape(Macro.t, Keyword.t) :: Macro.t
  def escape(expr, vars) do
    List.wrap(expr)
    |> Enum.map_reduce(%{}, &do_escape(&1, &2, vars))
  end

  defp do_escape({dir, expr}, params, vars) do
    {ast, params} = Builder.escape(expr, :any, params, vars)
    {{quoted_dir!(dir), ast}, params}
  end

  defp do_escape(expr, params, vars) do
    {ast, params} = Builder.escape(expr, :any, params, vars)
    {{:asc, ast}, params}
  end

  @doc """
  Checks the variable is a quoted direction at compilation time or
  delegate the check to runtime for interpolation.
  """
  def quoted_dir!({:^, _, [expr]}),
    do: quote(do: :"Elixir.Ecto.Query.Builder.OrderBy".dir!(unquote(expr)))
  def quoted_dir!(dir) when dir in [:asc, :desc],
    do: dir
  def quoted_dir!(other),
    do: Builder.error!("expected :asc, :desc or interpolated value in order by, got: `#{inspect other}`")

  @doc """
  Called by at runtime to verify the direction.
  """
  def dir!(dir) when dir in [:asc, :desc],
    do: dir
  def dir!(other),
    do: Builder.error!("expected :asc or :desc in order by, got: `#{inspect other}`")

  @doc """
  Builds a quoted expression.

  The quoted expression should evaluate to a query at runtime.
  If possible, it does all calculations at compile time to avoid
  runtime work.
  """
  @spec build(Macro.t, [Macro.t], Macro.t, Macro.Env.t) :: Macro.t
  def build(query, binding, expr, env) do
    binding        = Builder.escape_binding(binding)
    {expr, params} = escape(expr, binding)
    params         = Builder.escape_params(params)

    order_by = quote do: %Ecto.Query.QueryExpr{
                           expr: unquote(expr),
                           params: unquote(params),
                           file: unquote(env.file),
                           line: unquote(env.line)}
    Builder.apply_query(query, __MODULE__, [order_by], env)
  end

  @doc """
  The callback applied by `build/4` to build the query.
  """
  @spec apply(Ecto.Queryable.t, term) :: Ecto.Query.t
  def apply(query, expr) do
    query = Ecto.Queryable.to_query(query)
    %{query | order_bys: query.order_bys ++ [expr]}
  end
end
