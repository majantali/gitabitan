#!/usr/bin/env bash

Rscript -e "httpuv::runStaticServer(dir = '.', port = 8080)"

## OR
## Rscript -e "servr::httd(port = 8080)"
