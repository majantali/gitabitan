#!/usr/bin/env bash

Rscript -e "httpuv::runStaticServer(dir = '.', host = '0.0.0.0', port = 8080)"

## OR
## Rscript -e "servr::httd(port = 8080)"
