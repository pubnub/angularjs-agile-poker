#!/bin/env ruby

`grunt clean build`
`cp -r app/styles app/index.html .tmp/scripts .tmp/views dist/`

