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
    "LSX",
    "lubridate",
    "rmakrdown"
)
install.packages(pkgs, repos = "https://ftp.yz.yamagata-u.ac.jp/pub/cran/")
remotes::install_github("quanteda/quanteda.sentiment")