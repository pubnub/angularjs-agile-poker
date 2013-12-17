#!/bin/env ruby

`grunt clean build`
`rm -rf dist`
`mkdir dist`
`cp -r app/styles app/index.html app/images .tmp/scripts .tmp/views dist/`

