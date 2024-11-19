defmodule CommonCrawl.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github "https://github.com/preciz/common_crawl"

  def project do
    [
      app: :common_crawl,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: "Common Crawl API and WARC file parser",

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
      {:jason, "~> 1.4"}
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
      main: "Tmp",
      source_ref: "v#{@version}",
      source_url: @github
    ]
  end
end
