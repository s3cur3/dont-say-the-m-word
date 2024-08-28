insert_result =
  attrs
  |> Post.changeset()
  |> Repo.insert()

case insert_result do
  {:ok, post} ->
    Analytics.track_event(:post_created, post)
    {:ok, post}

  {:error, changeset} ->
    {:error, changeset}
end


🤢












attrs
|> Post.changeset()
|> Repo.insert()
|> tap(fn
  {:ok, post} -> Analytics.track_event(:post_created, post)
  _ -> :ok
end)


😬













attrs
|> Post.changeset()
|> Repo.insert()
|> Result.tap_ok(fn %Post{} = post ->
  Analytics.track_event(:post_created, post)
end)


😌













attrs
|> Post.changeset()
|> Repo.insert()
|> Result.tap_ok(&Analytics.track_event(:post_created, &1))


😍



















Repo.transaction(fn ->
  insertion_results =
    Enum.map(posts_attrs, fn post_attrs ->
      post_attrs
      |> Post.changeset()
      |> Repo.insert()
    end)

  first_error =
    Enum.find(
      insertion_results,
      &match?({:error, _}, &1)
    )

  if first_error do
    first_error
  else
    {:ok, Enum.map(insertion_results, &elem(&1, 1))}
  end
end)


🤢 🤢 🤢























Repo.transaction(fn ->
  Result.Enum.map_while_ok(posts_attrs, fn post_attrs ->
    post_attrs
    |> Post.changeset()
    |> Repo.insert()
  end)
end)


🤩















case Stripe.fetch_products() do
  {:ok, products} ->
    internal_ids =
      products
      |> Enum.map(fn %Stripe.Product{} = product ->
        case internal_product_id(product) do
          {:ok, internal_id} -> {:ok, internal_id}
          {:error, _} = error -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, internal_ids}

  {:error, _} = error ->
    error
end


😷
















Stripe.fetch_products()
|> Result.map_ok(fn products ->
  products
  |> Enum.map(&internal_product_id/1)
  |> Result.Enum.reject_error()
end)


😎














customers =
  with {:ok, product} <- Stripe.fetch_product(pencil_holder_id),
       {:ok, customers} <- Customers.owning(product) do
    customers
  else
         _ -> []
  end

😕















customers =
  Stripe.fetch_product(pencil_holder_id)
  |> Result.map_ok(&Customers.owning/1)
  |> Result.unwrap([])

🙂‍↕️
