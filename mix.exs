defmodule CommonCrawl.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github "https://github.com/preciz/common_crawl"

  def project do
    [
      app: :common_crawl,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: "Work with Common Crawl data",

      # Docs
      name: "CommonCrawl",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Barna Kovacs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @github}
    ]
  end

  defp docs do
    [
      main: "CommonCrawl",
      source_ref: "v#{@version}",
      source_url: @github
    ]
  end
end
