#!/bin/sh

rm -v esp32_prog_generic_pos.zip \
    esp32_prog_generic_bom.zip esp32_prog_generic_gerbs.zip

zip esp32_prog_generic_pos.zip -r pos/
zip esp32_prog_generic_bom.zip -r bom/
zip esp32_prog_generic_gerbs.zip -r gerbs/
