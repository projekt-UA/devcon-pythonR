# https://github.com/quanteda/quanteda/issues/2257#issuecomment-1514207680
update.packages(ask = FALSE)

pkgs <- c(
    "IRkernel",
    "languageserver",
    "systemfonts",
    "ragg",
    "ggplot2",
    "arrow",
    "stopwords",
    "quanteda",
    "LSX"
)
install.packages(pkgs)
remotes::install_github("quanteda/quanteda.sentiment")