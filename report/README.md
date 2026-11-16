# LaTeX source

The main document is `Empirical.tex`. Keep the `tables/` and `figures/` folders beside it.

Upload the complete source archive to Overleaf and select `Empirical.tex` as the main document. The source uses standard LaTeX packages and supports pdfLaTeX or XeLaTeX.

To compile locally with pdfLaTeX, run twice from this folder:

```sh
pdflatex Empirical.tex
pdflatex Empirical.tex
```

It can also be compiled with Tectonic:

```sh
tectonic Empirical.tex
```

The tables are native LaTeX generated in R from the replication package's result files. The figure is the R-generated annual failure-rate plot. No original race-level data are included in the source archive.
